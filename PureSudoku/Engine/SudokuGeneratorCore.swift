import Foundation

// MARK: - Core board type

typealias GeneratorBoard = [Int?] // 81 entries, values 0...8 represent digits 1...9

// MARK: - Public API surface (vendored from sudoku-swift with RNG support)

func makePuzzle(using rng: inout some RandomNumberGenerator) -> GeneratorBoard {
    let solved = solvePuzzle(Array(repeating: nil, count: 81), using: &rng) ?? []
    return makePuzzle(from: solved, using: &rng)
}

func makePuzzle() -> GeneratorBoard {
    var rng = SystemRandomNumberGenerator()
    return makePuzzle(using: &rng)
}

func solvePuzzle(_ board: GeneratorBoard, using rng: inout some RandomNumberGenerator) -> GeneratorBoard? {
    solveBoard(board, using: &rng).answer
}

func solvePuzzle(_ board: GeneratorBoard) -> GeneratorBoard? {
    var rng = SystemRandomNumberGenerator()
    return solvePuzzle(board, using: &rng)
}

func ratePuzzle(_ puzzle: GeneratorBoard, samples: Int, using rng: inout some RandomNumberGenerator) -> Double {
    guard samples > 0 else { return -1 }
    var total = 0
    for _ in 0..<samples {
        let tuple = solveBoard(puzzle, using: &rng)
        guard let _ = tuple.answer else { return -1 }
        total += tuple.state.count
    }
    return Double(total) / Double(samples)
}

func ratePuzzle(_ puzzle: GeneratorBoard, samples: Int) -> Double {
    var rng = SystemRandomNumberGenerator()
    return ratePuzzle(puzzle, samples: samples, using: &rng)
}

func posFor(x: Int, y: Int, axis: Int = 0) -> Int {
    switch axis {
    case 0:
        return x * 9 + y
    case 1:
        return y * 9 + x
    default:
        return [0, 3, 6, 27, 30, 33, 54, 57, 60][x] + [0, 1, 2, 9, 10, 11, 18, 19, 20][y]
    }
}

// MARK: - Puzzle generation

private func makePuzzle(from solutionBoard: GeneratorBoard, using rng: inout some RandomNumberGenerator) -> GeneratorBoard {
    var puzzle: [Guess] = []
    var deduced = Array(repeating: Int?.none, count: 81)
    var order = Array(0..<81)
    order.shuffle(using: &rng)

    for pos in order where deduced[pos] == nil {
        puzzle.append(Guess(pos: pos, num: solutionBoard[pos]!))
        deduced[pos] = solutionBoard[pos]
        _ = deduce(board: &deduced, using: &rng)
    }

    puzzle.shuffle(using: &rng)

    for idx in stride(from: puzzle.count - 1, through: 0, by: -1) where !puzzle.isEmpty {
        let entry = puzzle[idx]
        puzzle.remove(at: idx)
        let rating = checkPuzzle(board: board(for: puzzle), solution: solutionBoard, using: &rng)
        if rating == -1 {
            puzzle.append(entry)
        }
    }

    return board(for: puzzle)
}

// MARK: - Solver

private func solveBoard(_ original: GeneratorBoard, using rng: inout some RandomNumberGenerator) -> (state: [Frame], answer: GeneratorBoard?) {
    var board = original
    switch deduce(board: &board, using: &rng) {
    case .solved:
        return ([], board)
    case .contradiction:
        return ([], nil)
    case .guesses(let g):
        var track = [Frame(guesses: g, count: 0, board: board)]
        return solveNext(remembered: &track, using: &rng)
    }
}

private func solveNext(remembered: inout [Frame], using rng: inout some RandomNumberGenerator) -> (state: [Frame], answer: GeneratorBoard?) {
    while let tuple1 = remembered.popLast() {
        if tuple1.count >= tuple1.guesses.count {
            continue
        }

        remembered.append(Frame(guesses: tuple1.guesses, count: tuple1.count + 1, board: tuple1.board))

        var workspace = tuple1.board
        let tuple2 = tuple1.guesses[tuple1.count]
        workspace[tuple2.pos] = tuple2.num

        switch deduce(board: &workspace, using: &rng) {
        case .solved:
            return (remembered, workspace)
        case .contradiction:
            continue
        case .guesses(let g):
            remembered.append(Frame(guesses: g, count: 0, board: workspace))
        }
    }

    return ([], nil)
}

// MARK: - Deduction / constraint propagation

private enum DeduceResult {
    case solved
    case contradiction
    case guesses([Guess])
}

private func deduce(board: inout GeneratorBoard, using rng: inout some RandomNumberGenerator) -> DeduceResult {
    while true {
        var stuck = true
        var guess: [Guess]?
        var count = 0

        var tuple = figureBits(board)
        var allowed = tuple.allowed
        var needed = tuple.needed

        for pos in 0..<81 where board[pos] == nil {
            let numbers = listBits(allowed[pos])
            if numbers.isEmpty {
                return .contradiction
            } else if numbers.count == 1 {
                board[pos] = numbers[0]
                stuck = false
            } else if stuck {
                let guesses = numbers.map { Guess(pos: pos, num: $0) }
                (guess, count) = pickBetter(current: guess, count: count, candidate: guesses, using: &rng)
            }
        }

        if !stuck {
            tuple = figureBits(board)
            allowed = tuple.allowed
            needed = tuple.needed
        }

        for axis in 0..<3 {
            for x in 0..<9 {
                let numbers = listBits(needed[axis * 9 + x])
                for n in numbers {
                    let bit = 1 << n
                    var spots: [Int] = []
                    for y in 0..<9 {
                        let pos = posFor(x: x, y: y, axis: axis)
                        if allowed[pos] & bit != 0 {
                            spots.append(pos)
                        }
                    }

                    if spots.isEmpty {
                        return .contradiction
                    } else if spots.count == 1 {
                        board[spots[0]] = n
                        stuck = false
                    } else if stuck {
                        let guesses = spots.map { Guess(pos: $0, num: n) }
                        (guess, count) = pickBetter(current: guess, count: count, candidate: guesses, using: &rng)
                    }
                }
            }
        }

        if stuck {
            if var g = guess {
                g.shuffle(using: &rng)
                return .guesses(g)
            }
            return .solved
        }
    }
}

// MARK: - Difficulty and uniqueness

private func checkPuzzle(board: GeneratorBoard, solution: GeneratorBoard?, using rng: inout some RandomNumberGenerator) -> Int {
    let tuple1 = solveBoard(board, using: &rng)
    guard let answer = tuple1.answer else { return -1 }

    if let solution, !boardMatches(solution, answer) {
        return -1
    }

    let difficulty = tuple1.state.count
    var stateCopy = tuple1.state
    let tuple2 = solveNext(remembered: &stateCopy, using: &rng)
    if tuple2.answer != nil {
        return -1
    }
    return difficulty
}

// MARK: - Helpers

private struct Guess {
    let pos: Int
    let num: Int
}

private struct Frame {
    var guesses: [Guess]
    var count: Int
    var board: GeneratorBoard
}

private func axisFor(pos: Int, axis: Int) -> Int {
    switch axis {
    case 0:
        return pos / 9
    case 1:
        return pos % 9
    default:
        return (pos / 27) * 3 + (pos / 3) % 3
    }
}

private func axisMissing(_ board: GeneratorBoard, x: Int, axis: Int) -> Int {
    var bits = 0
    for y in 0..<9 {
        let e = board[posFor(x: x, y: y, axis: axis)]
        if let e {
            bits |= 1 << e
        }
    }
    return 0x1FF ^ bits
}

func figureBits(_ board: GeneratorBoard) -> (allowed: [Int], needed: [Int]) {
    var needed: [Int] = []
    var allowed = board.map { $0 == nil ? 0x1FF : 0 }

    for axis in 0..<3 {
        for x in 0..<9 {
            let bits = axisMissing(board, x: x, axis: axis)
            needed.append(bits)
            for y in 0..<9 {
                let pos = posFor(x: x, y: y, axis: axis)
                allowed[pos] &= bits
            }
        }
    }

    return (allowed, needed)
}

func listBits(_ bits: Int) -> [Int] {
    var list: [Int] = []
    for y in 0..<9 where (bits & (1 << y)) != 0 {
        list.append(y)
    }
    return list
}

private func pickBetter(current: [Guess]?, count: Int, candidate: [Guess], using rng: inout some RandomNumberGenerator) -> ([Guess]?, Int) {
    if current == nil || candidate.count < current!.count {
        return (candidate, 1)
    } else if candidate.count > current!.count {
        return (current, count)
    } else if randomInt(count, using: &rng) == 0 {
        return (candidate, count + 1)
    }
    return (current, count + 1)
}

private func board(for entries: [Guess]) -> GeneratorBoard {
    var board = Array(repeating: Int?.none, count: 81)
    for item in entries {
        board[item.pos] = item.num
    }
    return board
}

private func boardMatches(_ a: GeneratorBoard, _ b: GeneratorBoard) -> Bool {
    for i in 0..<81 {
        if a[i] != b[i] { return false }
    }
    return true
}

@discardableResult
private func randomInt(_ maxInclusive: Int, using rng: inout some RandomNumberGenerator) -> Int {
    guard maxInclusive > 0 else { return 0 }
    return Int.random(in: 0...maxInclusive, using: &rng)
}

// MARK: - Seeding utility

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
