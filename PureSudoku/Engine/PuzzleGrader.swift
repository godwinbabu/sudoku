import Foundation

/// How hard a puzzle is for a person (CODESPEC 2.2): the techniques the logical solver needs.
struct PuzzleGrade: Codable, Equatable {
    let hardestTier: TechniqueTier
    /// Sum of step scores (HINT_STRATEGIES.md); orders puzzles within a level.
    let score: Int
    /// Techniques used, in curriculum order.
    let techniques: [Technique]

    /// The level of the hardest technique needed (CODESPEC 2.2).
    var difficulty: Difficulty { techniques.map(\.level).max() ?? .easy }
}

extension Technique {
    /// The lowest level that may need this technique: singles → Easy, pointing and claiming →
    /// Medium, subsets → Hard, wings, fish and the rest of the Advanced tier → Expert, chains → Master.
    var level: Difficulty {
        switch tier {
        case .basic: return .easy
        case .intermediate: return [.pointing, .claiming].contains(self) ? .medium : .hard
        case .advanced: return .expert
        case .expert: return .master
        }
    }
}

enum PuzzleGrader {
    /// Solves step by step, always taking the simplest step. Nil if the solver gets stuck (the
    /// puzzle needs a technique the app does not know yet) — such a puzzle fits no level.
    static func grade(_ values: [Int], allowsUniqueness: Bool = true) -> (grade: PuzzleGrade, solution: [Int])? {
        let result = LogicalSolver(allowsUniqueness: allowsUniqueness).solve(SolverBoard(values: values))
        guard result.isSolved else { return nil }
        let used = Set(result.steps.map(\.technique))
        let grade = PuzzleGrade(
            hardestTier: used.map(\.tier).max() ?? .basic,
            score: result.steps.reduce(0) { $0 + $1.technique.score },
            techniques: Technique.allCases.filter(used.contains)
        )
        return (grade, result.board.values)
    }
}

extension PuzzleGrader {
    /// Adds digits from the solution until the board reaches its level's target givens
    /// (CODESPEC 2.2). Solution digits keep the puzzle unique. Easy adds at random; other levels
    /// keep an added digit only if the level stays the same. Nil if the final board misses the
    /// level or the target range.
    static func addingGivens(to values: [Int], solution: [Int], level: Difficulty,
                             using rng: inout some RandomNumberGenerator) -> (values: [Int], grade: PuzzleGrade)? {
        var board = values
        if let target = level.targetGivens {
            var count = board.filter { $0 != 0 }.count
            for cell in board.indices.filter({ board[$0] == 0 }).shuffled(using: &rng) where count < target.lowerBound {
                board[cell] = solution[cell]
                if level == .easy || grade(board)?.grade.difficulty == level {
                    count += 1
                } else {
                    board[cell] = 0
                }
            }
        }
        guard let final = grade(board), final.grade.difficulty == level, final.solution == solution,
              level.targetGivens?.contains(board.filter { $0 != 0 }.count) ?? true else { return nil }
        return (board, final.grade)
    }
}

/// Counts solutions by backtracking, stopping at `limit` (CODESPEC 2.1: imports count to 2).
enum SolutionCounter {
    static func count(_ values: [Int], limit: Int = 2) -> Int {
        let board = SolverBoard(values: values)
        guard !board.hasContradiction else { return 0 }
        var count = 0
        search(board, limit: limit, count: &count)
        return count
    }

    private static func search(_ board: SolverBoard, limit: Int, count: inout Int) {
        // Branch on the empty cell with the fewest candidates.
        var best: Int?
        var fewest = 10
        for cell in 0..<81 where board.values[cell] == 0 {
            let options = board.candidates[cell].nonzeroBitCount
            if options == 0 { return }
            if options < fewest { fewest = options; best = cell }
        }
        guard let cell = best else {
            count += 1
            return
        }
        for digit in SolverBoard.digits(in: board.candidates[cell]) {
            var next = board
            next.place(digit, at: cell)
            search(next, limit: limit, count: &count)
            if count >= limit { return }
        }
    }
}
