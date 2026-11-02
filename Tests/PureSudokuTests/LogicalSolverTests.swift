import XCTest
@testable import PureSudoku

final class LogicalSolverTests: XCTestCase {
    private let solver = LogicalSolver()

    /// Seeded corpus of generated puzzles with their solutions (values 1...9, 0 = empty).
    private static let corpus: [(puzzle: [Int], solution: [Int])] = {
        var rng = SeededRandomNumberGenerator(seed: 20261101)
        return (0..<400).map { _ in
            let board = makePuzzle(using: &rng)
            let solution = solvePuzzle(board, using: &rng)!
            return (board.map { ($0 ?? -1) + 1 }, solution.map { $0! + 1 })
        }
    }()

    // MARK: - Correctness oracle (CODESPEC 9, 13.6)

    func testEveryStepAgreesWithTheSolutionAndItsPattern() {
        var used: [Technique: Int] = [:]
        var solvedCount = 0
        for (puzzle, solution) in Self.corpus {
            var board = SolverBoard(values: puzzle)
            while let step = solver.nextStep(board) {
                for placement in step.placements {
                    XCTAssertEqual(solution[placement.cell], placement.digit, "\(step.technique) placed a wrong digit")
                }
                for elimination in step.eliminations {
                    XCTAssertNotEqual(solution[elimination.cell], elimination.digit, "\(step.technique) removed a correct candidate")
                }
                XCTAssertNil(Self.patternProblem(step, on: board), "\(step.technique): \(Self.patternProblem(step, on: board) ?? "")")
                XCTAssertFalse(step.explanation.isEmpty)
                used[step.technique, default: 0] += 1
                board.apply(step)
            }
            if board.isSolved {
                XCTAssertEqual(board.values, solution)
                solvedCount += 1
            }
        }
        print("LogicalSolver corpus: solved \(solvedCount)/\(Self.corpus.count); steps per technique:", Technique.allCases.map { "\($0.rawValue)=\(used[$0, default: 0])" }.joined(separator: " "))
        // Every technique except the rare quads is exercised by the corpus.
        let rare: Set<Technique> = [.nakedQuad, .hiddenQuad, .uniqueRectangle2, .uniqueRectangle4, .bugPlusOne]
        for technique in Technique.allCases where !rare.contains(technique) {
            XCTAssertGreaterThan(used[technique, default: 0], 0, "\(technique) never fired in the corpus")
        }
        XCTAssertGreaterThan(solvedCount, Self.corpus.count / 2, "the solver should finish most generated puzzles")
    }

    /// Checks that a step's pattern really justifies it, on the board before the step.
    private static func patternProblem(_ step: TechniqueStep, on board: SolverBoard) -> String? {
        let cells = step.cells.map(\.cell)
        let digitMask = SolverBoard.mask(of: step.digits)
        let base = step.houses.filter { $0.role == .base }.map(\.house)
        let cover = step.houses.filter { $0.role == .cover }.map(\.house)
        switch step.technique {
        case .fullHouse:
            return base[0].cells.filter { board.values[$0] == 0 } == cells ? nil : "house has more than one empty cell"
        case .hiddenSingleBox, .hiddenSingleLine:
            return board.cells(for: step.digits[0], in: base[0]) == cells ? nil : "digit fits elsewhere in the house"
        case .nakedSingle:
            return board.candidates[cells[0]] == digitMask ? nil : "cell has more than one candidate"
        case .pointing, .claiming, .xWing, .swordfish:
            let digit = step.digits[0]
            let spots = base.flatMap { board.cells(for: digit, in: $0) }
            guard Set(spots) == Set(cells) else { return "pattern cells are not the digit's spots" }
            guard spots.allSatisfy({ spot in cover.contains { $0.cells.contains(spot) } }) else { return "a spot lies outside the cover" }
            return step.eliminations.allSatisfy({ e in cover.contains { $0.cells.contains(e.cell) } && !cells.contains(e.cell) }) ? nil : "elimination outside the cover"
        case .nakedPair, .nakedTriple, .nakedQuad, .lockedPair, .lockedTriple:
            let union = cells.reduce(UInt16(0)) { $0 | board.candidates[$1] }
            guard union == digitMask, cells.count == step.digits.count else { return "cells hold other digits" }
            return step.eliminations.allSatisfy({ e in base.contains { $0.cells.contains(e.cell) } && !cells.contains(e.cell) }) ? nil : "elimination outside the house"
        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            let spots = Set(step.digits.flatMap { board.cells(for: $0, in: base[0]) })
            return spots == Set(cells) && cells.count == step.digits.count ? nil : "digits fit outside the pattern"
        case .xyWing:
            let pivot = step.cells.first { $0.role == .pivot }!.cell
            let pincers = step.cells.filter { $0.role == .pincer }.map(\.cell)
            let (x, y, z) = (step.digits[0], step.digits[1], step.digits[2])
            guard board.candidates[pivot] == SolverBoard.mask(of: [x, y]) else { return "pivot is not {x, y}" }
            guard Set(pincers.map { board.candidates[$0] }) == [SolverBoard.mask(of: [x, z]), SolverBoard.mask(of: [y, z])] else { return "pincers are not {x, z} and {y, z}" }
            guard pincers.allSatisfy({ SolverBoard.sees(pivot, $0) }) else { return "a pincer does not see the pivot" }
            return step.eliminations.allSatisfy({ e in e.digit == z && pincers.allSatisfy { SolverBoard.sees(e.cell, $0) } }) ? nil : "elimination does not see both pincers"
        case .skyscraper, .twoStringKite, .emptyRectangle, .simpleColoring:
            // Single-digit patterns: every pattern cell holds the digit; eliminations are that digit.
            let digit = step.digits[0]
            guard cells.allSatisfy({ board.has(digit, at: $0) }) else { return "a pattern cell lacks the digit" }
            return step.eliminations.allSatisfy { $0.digit == digit && !cells.contains($0.cell) } ? nil : "elimination of another digit"
        case .xyzWing:
            let pivot = step.cells.first { $0.role == .pivot }!.cell
            let pincers = step.cells.filter { $0.role == .pincer }.map(\.cell)
            let z = step.digits.last!
            guard board.candidates[pivot].nonzeroBitCount == 3 else { return "pivot is not trivalue" }
            return step.eliminations.allSatisfy({ e in e.digit == z && SolverBoard.sees(e.cell, pivot) && pincers.allSatisfy { SolverBoard.sees(e.cell, $0) } })
                ? nil : "elimination does not see pivot and pincers"
        case .wWing:
            let ends = step.cells.filter { $0.role == .pincer }.map(\.cell)
            guard board.candidates[ends[0]] == board.candidates[ends[1]], board.candidates[ends[0]].nonzeroBitCount == 2 else { return "ends differ" }
            return step.eliminations.allSatisfy { e in ends.allSatisfy { SolverBoard.sees(e.cell, $0) } } ? nil : "elimination does not see both ends"
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4, .bugPlusOne:
            return cells.allSatisfy({ board.values[$0] == 0 }) ? nil : "pattern cell is filled"
        }
    }

    // MARK: - Behavior

    func testSameBoardGivesTheSameSteps() {
        for (puzzle, _) in Self.corpus.prefix(30) {
            let board = SolverBoard(values: puzzle)
            XCTAssertEqual(solver.solve(board).steps, solver.solve(board).steps)
        }
    }

    /// The old engine restarted every technique from the original candidates, so eliminations never
    /// built on each other. Here they must: some puzzle needs an elimination before it can finish.
    func testEliminationsStackToFinishAPuzzle() {
        let stacked = Self.corpus.contains { puzzle, _ in
            let result = solver.solve(SolverBoard(values: puzzle))
            return result.isSolved && result.steps.contains { $0.placements.isEmpty }
        }
        XCTAssertTrue(stacked)
    }

    func testSolvedOrContradictoryBoardHasNoStep() {
        let (_, solution) = Self.corpus[0]
        XCTAssertNil(solver.nextStep(SolverBoard(values: solution)))
        var broken = solution
        broken[0] = 0
        broken[9] = solution[0] // r2c1 repeats a digit already in row 2
        XCTAssertNil(solver.nextStep(SolverBoard(values: broken)))
    }

    func testPlayerNotesAreUsedAndStaleNotesIgnored() {
        let (puzzle, solution) = Self.corpus[0]
        let cell = puzzle.firstIndex(of: 0)!
        let computed = SolverBoard(values: puzzle)
        var notes = Array(repeating: Set<Int>(), count: 81)
        // A stale note: a digit already placed in the cell's row is ignored.
        let placedInRow = SolverBoard.houseCells[SolverBoard.row(of: cell)].map { puzzle[$0] }.first { $0 != 0 }!
        notes[cell] = [solution[cell], placedInRow]
        let board = SolverBoard(values: puzzle, notes: notes)
        XCTAssertEqual(board.candidates[cell], SolverBoard.bit(solution[cell]))
        // Cells without notes keep computed candidates.
        let other = puzzle.indices.last { $0 != cell && puzzle[$0] == 0 }!
        XCTAssertEqual(board.candidates[other], computed.candidates[other])
    }

    func testBoardFromGameCellsMatchesGrid() {
        let state = TestData.newGameState()
        XCTAssertEqual(SolverBoard(cells: state.cells), SolverBoard(grid: TestData.puzzle.initialGrid))
    }

    // MARK: - Hand-made boards: exact eliminations per technique (CODESPEC 13.6)

    /// Empty board: every cell allows 1...9 except the listed cells, which allow only their digits.
    private func board(_ masks: [Int: [Int]]) -> SolverBoard {
        var candidates = Array(repeating: SolverBoard.allDigits, count: 81)
        for (cell, digits) in masks { candidates[cell] = SolverBoard.mask(of: digits) }
        return SolverBoard(values: Array(repeating: 0, count: 81), candidates: candidates)
    }

    private func allBut(_ digit: Int) -> [Int] { (1...9).filter { $0 != digit } }

    private func expected(_ cells: [Int], _ digits: [Int]) -> [CellDigit] {
        cells.flatMap { cell in digits.map { CellDigit(cell: cell, digit: $0) } }.sorted()
    }

    func testPointingRemovesFromTheRestOfTheLine() {
        // In box 1, 5 sits only in r1c1 and r1c2: it leaves the rest of row 1.
        let masks = Dictionary(uniqueKeysWithValues: [2, 9, 10, 11, 18, 19, 20].map { ($0, allBut(5)) })
        let step = IntersectionDetector.pointing(board(masks)).first { $0.houses.first?.house == House(kind: .box, index: 0) }
        XCTAssertEqual(step?.eliminations, expected(Array(3...8), [5]))
    }

    func testClaimingRemovesFromTheRestOfTheBox() {
        // In row 1, 5 sits only in r1c1 and r1c2 (box 1): it leaves the rest of box 1.
        let masks = Dictionary(uniqueKeysWithValues: (2...8).map { ($0, allBut(5)) })
        let step = IntersectionDetector.claiming(board(masks)).first { $0.houses.first?.house == House(kind: .row, index: 0) }
        XCTAssertEqual(step?.eliminations, expected([9, 10, 11, 18, 19, 20], [5]))
    }

    func testLockedPairRemovesFromBoxAndLine() {
        let step = SubsetDetector.locked(board([0: [1, 2], 1: [1, 2]]), size: 2).first
        XCTAssertEqual(step?.technique, .lockedPair)
        XCTAssertEqual(step?.eliminations, expected([2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 18, 19, 20], [1, 2]))
    }

    func testLockedTripleRemovesFromBoxAndLine() {
        let step = SubsetDetector.locked(board([0: [1, 2, 3], 1: [1, 2, 3], 2: [1, 2, 3]]), size: 3).first
        XCTAssertEqual(step?.technique, .lockedTriple)
        XCTAssertEqual(step?.eliminations, expected([3, 4, 5, 6, 7, 8, 9, 10, 11, 18, 19, 20], [1, 2, 3]))
    }

    func testNakedPairRemovesFromTheRestOfTheHouse() {
        // r1c1 and r1c5 (different boxes) hold only {1, 2}.
        let step = SubsetDetector.naked(board([0: [1, 2], 4: [1, 2]]), size: 2).first { $0.houses.first?.house == House(kind: .row, index: 0) }
        XCTAssertEqual(step?.technique, .nakedPair)
        XCTAssertEqual(step?.eliminations, expected([1, 2, 3, 5, 6, 7, 8], [1, 2]))
    }

    func testNakedQuadRemovesFromTheRestOfTheHouse() {
        let masks = Dictionary(uniqueKeysWithValues: [0, 2, 4, 6].map { ($0, [1, 2, 3, 4]) })
        let step = SubsetDetector.naked(board(masks), size: 4).first { $0.houses.first?.house == House(kind: .row, index: 0) }
        XCTAssertEqual(step?.technique, .nakedQuad)
        XCTAssertEqual(step?.eliminations, expected([1, 3, 5, 7, 8], [1, 2, 3, 4]))
    }

    func testListJoinsWithCommasAndFinalAnd() {
        XCTAssertEqual(TechniqueStep.list([]), "")
        XCTAssertEqual(TechniqueStep.list(["a"]), "a")
        XCTAssertEqual(TechniqueStep.list(["a", "b"]), "a and b")
        XCTAssertEqual(TechniqueStep.list(["a", "b", "c"]), "a, b and c")
    }

    func testXWingRemovesFromBothCoverColumns() {
        // 5 sits only in columns 1 and 5 of rows 1 and 4.
        var masks: [Int: [Int]] = [:]
        for row in [0, 3] { for col in 0..<9 where ![0, 4].contains(col) { masks[row * 9 + col] = allBut(5) } }
        let steps = FishDetector.fish(board(masks), size: 2).filter { $0.digits == [5] }
        XCTAssertEqual(steps.count, 1)
        let removed = [1, 2, 4, 5, 6, 7, 8].flatMap { [$0 * 9, $0 * 9 + 4] }
        XCTAssertEqual(steps.first?.eliminations, expected(removed, [5]))
    }

    func testSwordfishRemovesFromAllThreeCoverColumns() {
        // 7 sits in rows 1, 5, 9 only within columns 1, 4, 7.
        let spots: [Int: [Int]] = [0: [0, 3], 4: [3, 6], 8: [0, 6]]
        var masks: [Int: [Int]] = [:]
        for (row, cols) in spots { for col in 0..<9 where !cols.contains(col) { masks[row * 9 + col] = allBut(7) } }
        let steps = FishDetector.fish(board(masks), size: 3).filter { $0.digits == [7] }
        XCTAssertEqual(steps.count, 1)
        let removed = [1, 2, 3, 5, 6, 7].flatMap { row in [0, 3, 6].map { row * 9 + $0 } }
        XCTAssertEqual(steps.first?.eliminations, expected(removed, [7]))
    }

    func testHiddenQuadClearsOtherCandidates() {
        // In row 1, digits 1-4 fit only in r1c1-r1c4.
        let masks = Dictionary(uniqueKeysWithValues: (4...8).map { ($0, Array(5...9)) })
        let step = SubsetDetector.hidden(board(masks), size: 4).first { $0.houses.first?.house == House(kind: .row, index: 0) }
        XCTAssertEqual(step?.technique, .hiddenQuad)
        XCTAssertEqual(step?.digits, [1, 2, 3, 4])
        XCTAssertEqual(step?.eliminations, expected([0, 1, 2, 3], Array(5...9)))
    }

    // MARK: - Phase 5 boards

    /// Masks where `digit` is removed from every cell of `cells`.
    private func without(_ digit: Int, _ cells: [Int], plus masks: [Int: [Int]] = [:]) -> [Int: [Int]] {
        var result = masks
        for cell in cells where result[cell] == nil { result[cell] = allBut(digit) }
        return result
    }

    func testSkyscraperRemovesFromCellsSeeingBothTops() {
        // 5 in row 1 only at c1, c5; in row 4 only at c1, c6. Bases line up in column 1.
        let masks = without(5, (0..<9).filter { ![0, 4].contains($0) } + (27..<36).filter { ![27, 32].contains($0) })
        let steps = SingleDigitDetector.skyscrapers(board(masks)).filter { $0.digits == [5] }
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.eliminations, expected([14, 23, 40, 49], [5]))
    }

    func testTwoStringKiteRemovesWhereTheFarEndsCross() {
        // 7: row 2 only at r2c2, r2c7; column 1 only at r3c1, r8c1 (r2c2 and r3c1 share box 1).
        let rowCells = (9..<18).filter { ![10, 15].contains($0) }
        let columnCells = stride(from: 0, to: 81, by: 9).filter { ![18, 63].contains($0) }
        let steps = SingleDigitDetector.twoStringKites(board(without(7, rowCells + columnCells)))
        XCTAssertEqual(steps.map(\.eliminations), [[CellDigit(cell: 69, digit: 7)]])
    }

    func testEmptyRectangleRemovesOneCell() {
        // Box 5: 5 only on row 5 and column 5 (a cross). Column 9: 5 only at r1c9 and r5c9.
        let column9 = stride(from: 8, to: 81, by: 9).filter { ![8, 44].contains($0) }
        let steps = SingleDigitDetector.emptyRectangles(board(without(5, [30, 32, 48, 50] + column9)))
        XCTAssertTrue(steps.contains { $0.eliminations == [CellDigit(cell: 4, digit: 5)] })
        XCTAssertTrue(steps.allSatisfy { $0.eliminations.allSatisfy { $0.digit == 5 } })
    }

    func testXYZWingRemovesFromCellsSeeingAllThree() {
        let steps = MoreWingsDetector.xyzWings(board([0: [1, 2, 3], 1: [1, 3], 9: [2, 3]]))
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.eliminations, expected([2, 10, 11, 18, 19, 20], [3]))
    }

    func testWWingRemovesFromCellsSeeingBothEnds() {
        // r1c1 and r9c9 hold {1,2}; column 5 has 1 only at r1c5 and r9c5.
        let column5 = stride(from: 4, to: 81, by: 9).filter { ![4, 76].contains($0) }
        let steps = MoreWingsDetector.wWings(board(without(1, column5, plus: [0: [1, 2], 80: [1, 2]])))
        XCTAssertTrue(steps.contains { $0.eliminations == [CellDigit(cell: 8, digit: 2), CellDigit(cell: 72, digit: 2)] })
    }

    func testUniqueRectangleType1AndItsGate() {
        let masks: [Int: [Int]] = [0: [4, 6], 3: [4, 6], 9: [4, 6], 12: [4, 6, 8]]
        let steps = UniquenessDetector.uniqueRectangles(board(masks), type: 1)
        XCTAssertEqual(steps.map(\.eliminations), [[CellDigit(cell: 12, digit: 4), CellDigit(cell: 12, digit: 6)]])
        XCTAssertTrue(Technique.uniqueRectangle1.needsUniqueSolution)
        // A puzzle that may have several solutions never gets a uniqueness step.
        let noUniqueness = LogicalSolver(allowsUniqueness: false)
        for (puzzle, _) in Self.corpus.prefix(120) {
            XCTAssertFalse(noUniqueness.solve(SolverBoard(values: puzzle)).steps.contains { $0.technique.needsUniqueSolution })
        }
    }

    func testUniqueRectangleType2RemovesTheSharedExtra() {
        // Floor r1c1, r1c4 = {4,6}; roof r2c1, r2c4 = {4,6,8}: 8 leaves the rest of row 2.
        let steps = UniquenessDetector.uniqueRectangles(board([0: [4, 6], 3: [4, 6], 9: [4, 6, 8], 12: [4, 6, 8]]), type: 2)
        XCTAssertTrue(steps.contains { $0.eliminations == expected([10, 11, 13, 14, 15, 16, 17], [8]) })
    }

    func testUniqueRectangleType4RemovesTheOtherDigitFromTheRoof() {
        // Floor {4,6}; roof r2c1 {4,6,7}, r2c4 {4,6,9}; in row 2, 4 fits only in the roof: 6 leaves it.
        let row2 = (9..<18).filter { ![9, 12].contains($0) }
        let masks = without(4, row2, plus: [0: [4, 6], 3: [4, 6], 9: [4, 6, 7], 12: [4, 6, 9]])
        let steps = UniquenessDetector.uniqueRectangles(board(masks), type: 4)
        XCTAssertTrue(steps.contains { $0.eliminations == [CellDigit(cell: 9, digit: 6), CellDigit(cell: 12, digit: 6)] })
    }

    func testSimpleColoringTrapRemovesFromCellsSeeingBothColors() {
        // 5's strong links: row 1 (c1, c5), column 5 (r1, r6), row 6 (c5, c1). r1c1 and r6c1 get
        // opposite colors, so the rest of column 1 can't be 5.
        let masks = without(5, (1..<9).filter { $0 != 4 } + stride(from: 13, to: 81, by: 9).filter { $0 != 49 } + (46..<54).filter { $0 != 49 })
        let steps = ColoringDetector.simpleColoring(board(masks)).filter { $0.digits == [5] }
        XCTAssertTrue(steps.contains { $0.eliminations == expected([9, 18, 27, 36, 54, 63, 72], [5]) })
    }

    func testBugPlusOneWaitsWhileAHiddenSingleExists() {
        // Every cell {1,2} except r1c1 {1,2,3}: 3 has one place in row 1, so BUG+1 must not fire.
        var masks = Dictionary(uniqueKeysWithValues: (0..<81).map { ($0, [1, 2]) })
        masks[0] = [1, 2, 3]
        XCTAssertTrue(UniquenessDetector.bugPlusOne(board(masks)).isEmpty)
    }

    func testXYWingNeedsThreeDistinctDigits() {
        // Pivot r1c1 {1,2}, pincers r1c5 {1,3} and r5c1 {2,3}: r5c5 sees both pincers and loses 3.
        let wing = WingDetector.xyWings(board([0: [1, 2], 4: [1, 3], 36: [2, 3]]))
        XCTAssertEqual(wing.count, 1)
        XCTAssertEqual(wing.first?.eliminations, [CellDigit(cell: 40, digit: 3)])
        // A pivot and pincer with the same pair is not a wing.
        XCTAssertTrue(WingDetector.xyWings(board([0: [4, 5], 2: [4, 5], 72: [3, 5]])).isEmpty)
    }

    func testEveryTechniqueHasADetector() {
        for technique in Technique.allCases {
            XCTAssertNotNil(LogicalSolver.detectors[technique], "\(technique) has no detector")
        }
    }

    func testCombinations() {
        XCTAssertEqual(combinations([1, 2, 3, 4], size: 2), [[1, 2], [1, 3], [1, 4], [2, 3], [2, 4], [3, 4]])
        XCTAssertEqual(combinations([1, 2], size: 3), [])
    }

    // MARK: - Latency (CODESPEC 9: 50 ms per hint)

    /// The slowest case is a board where no known technique applies, so every detector runs.
    /// The simulator is faster than the oldest supported iPhone; this catches large regressions.
    func testHintLatencyOnStuckBoards() {
        let stuck = Self.corpus.lazy.map { self.solver.solve(SolverBoard(values: $0.puzzle)).board }.filter { !$0.isSolved }.prefix(5)
        XCTAssertFalse(stuck.isEmpty)
        for board in stuck {
            let start = Date()
            _ = solver.nextStep(board)
            XCTAssertLessThan(Date().timeIntervalSince(start), 0.05, "one hint took over 50 ms on the simulator")
        }
        let board = stuck.first!
        measure { _ = solver.nextStep(board) }
    }
}
