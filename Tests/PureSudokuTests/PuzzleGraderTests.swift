import XCTest
@testable import PureSudoku

/// Logical grading (CODESPEC 2.2), solution counting (2.1) and the bundled puzzles.
final class PuzzleGraderTests: XCTestCase {
    private func values(_ grid: String) -> [Int] { grid.map { Int(String($0)) ?? 0 } }

    func testSinglesOnlyPuzzleGradesEasy() throws {
        let graded = try XCTUnwrap(PuzzleGrader.grade(values(TestData.puzzle.initialGrid)))
        XCTAssertEqual(graded.grade.hardestTier, .basic)
        XCTAssertEqual(graded.grade.difficulty, .easy)
        XCTAssertEqual(graded.solution.map(String.init).joined(), TestData.puzzle.solutionGrid)
    }

    func testGradeIsDeterministic() {
        let grid = values(BundledPuzzles.puzzles(for: .hard)[0].initialGrid)
        XCTAssertEqual(PuzzleGrader.grade(grid)?.grade, PuzzleGrader.grade(grid)?.grade)
    }

    /// Every level request returns a puzzle whose own grade maps to that level: no silent fallback.
    func testGeneratedPuzzlesMatchTheirLevel() {
        let service = SudokuGeneratorService()
        for difficulty in Difficulty.allCases {
            for seed in UInt64(1)...UInt64(4) {
                let result = service.generatePuzzle(for: difficulty, seed: seed)
                XCTAssertEqual(result.puzzle.difficulty, difficulty)
                let regraded = PuzzleGrader.grade(values(result.puzzle.initialGrid))
                XCTAssertEqual(regraded?.grade.difficulty, difficulty, "seed \(seed) bundled \(result.isBundled)")
                XCTAssertEqual(regraded?.solution.map(String.init).joined(), result.puzzle.solutionGrid)
                XCTAssertEqual(result.puzzle.isUnique, true)
                let givens = result.puzzle.initialGrid.filter { $0 != "0" }.count
                XCTAssertTrue(difficulty.targets.isMet(by: result.grade, givens: givens), "seed \(seed): \(givens) givens, \(result.grade)")
                XCTAssertEqual(regraded?.grade, result.grade, "the stored grade is the final board's, complete")
            }
        }
    }

    func testFallsBackToABundledPuzzleOfTheSameLevel() {
        let service = SudokuGeneratorService(config: SudokuGeneratorConfiguration(maxAttempts: 0))
        for difficulty in Difficulty.allCases {
            let result = service.generatePuzzle(for: difficulty, seed: 3)
            XCTAssertTrue(result.isBundled)
            XCTAssertEqual(result.grade.difficulty, difficulty)
            XCTAssertEqual(PuzzleGrader.grade(values(result.puzzle.initialGrid))?.grade, result.grade,
                           "the fallback carries the full grade")
            XCTAssertTrue(difficulty.targets.isMet(by: result.grade, givens: result.puzzle.initialGrid.filter { $0 != "0" }.count))
        }
    }

    func testBundledPuzzlesAreValidUniqueAndCorrectlyGraded() {
        XCTAssertEqual(BundledPuzzles.all.filter { !$0.isDrillOnly }.count, 600)
        for difficulty in Difficulty.allCases {
            XCTAssertEqual(BundledPuzzles.puzzles(for: difficulty).count, 120)
        }
        for entry in BundledPuzzles.all {
            let grid = values(entry.initialGrid)
            XCTAssertEqual(SolutionCounter.count(grid), 1, entry.initialGrid)
            let regraded = PuzzleGrader.grade(grid)
            XCTAssertEqual(regraded?.grade.difficulty, entry.difficulty)
            XCTAssertEqual(regraded?.grade, entry.grade, "score, techniques, steps per tier and opening singles")
            XCTAssertEqual(regraded?.solution.map(String.init).joined(), entry.solutionGrid)
        }
    }

    /// Expert needs wings or fish (the Advanced tier) and Master needs a chain, both in the bundled
    /// sets and from the generator (CODESPEC 2.2).
    func testExpertAndTopLevelNeedTheirHardestTechnique() {
        func check(_ techniques: [Technique], _ level: Difficulty, _ label: String) {
            XCTAssertEqual(techniques.map(\.level).max(), level, label)
            switch level {
            case .expert:
                XCTAssertTrue(techniques.contains { $0.tier == .advanced }, "\(label): needs wings or fish")
                XCTAssertFalse(techniques.contains(.xyChain), label)
            case .master:
                XCTAssertTrue(techniques.contains(.xyChain), "\(label): needs a chain")
            default:
                XCTFail("not an Expert or Master check")
            }
        }
        for level in [Difficulty.expert, .master] {
            for entry in BundledPuzzles.puzzles(for: level) { check(entry.techniques, level, entry.initialGrid) }
            let service = SudokuGeneratorService()
            for seed in UInt64(11)...UInt64(16) {
                let result = service.generatePuzzle(for: level, seed: seed)
                let grade = PuzzleGrader.grade(values(result.puzzle.initialGrid))?.grade
                check(grade?.techniques ?? [], level, "seed \(seed) bundled \(result.isBundled)")
            }
        }
        XCTAssertEqual(Technique.xyChain.level, .master)
        XCTAssertEqual(Technique.xWing.level, .expert)
        XCTAssertEqual(Technique.nakedPair.level, .hard)
        XCTAssertEqual(Technique.pointing.level, .medium)
    }

    /// Every level offering meets its level's targets (issue #92). Practice-only lines may not.
    func testBundledPuzzlesMeetTheirLevelsTargets() {
        for entry in BundledPuzzles.all where !entry.isDrillOnly {
            let givens = entry.initialGrid.filter { $0 != "0" }.count
            XCTAssertTrue(entry.difficulty.targets.isMet(by: entry.grade, givens: givens), "\(entry.difficulty): \(entry.initialGrid)")
        }
    }

    /// Targets and the metrics they read (CODESPEC 2.2).
    func testLevelTargetsAndMetrics() throws {
        XCTAssertEqual(Difficulty.easy.targets.givens, 38...44)
        XCTAssertEqual(Difficulty.master.targets.givens, 22...26)
        // TestData's puzzle: singles only, so no walls.
        let grade = try XCTUnwrap(PuzzleGrader.grade(values(TestData.puzzle.initialGrid))?.grade)
        XCTAssertEqual(grade.steps(atLeast: .intermediate), 0)
        XCTAssertEqual(grade.stepsPerTier?.first, values(TestData.puzzle.initialGrid).filter { $0 == 0 }.count, "one single per empty cell")
        // Opening singles: the union of placement cells from every Basic detector on the start board.
        let board = SolverBoard(values: values(TestData.puzzle.initialGrid))
        let cells = Set(Technique.allCases.filter { $0.tier == .basic }
            .flatMap { LogicalSolver.steps(for: $0, on: board) }.flatMap { $0.placements.map(\.cell) })
        XCTAssertEqual(grade.openingSingles, cells.count)
        // Walls count steps, cumulative by tier.
        let walled = PuzzleGrade(hardestTier: .advanced, score: 0, techniques: [], stepsPerTier: [30, 3, 2, 0], openingSingles: 4)
        XCTAssertEqual(walled.steps(atLeast: .intermediate), 5)
        XCTAssertEqual(walled.steps(atLeast: .advanced), 2)
        XCTAssertTrue(Difficulty.expert.targets.isMet(by: walled, givens: 25))
        XCTAssertFalse(Difficulty.expert.targets.isMet(by: walled, givens: 28), "givens out of range")
        XCTAssertFalse(Difficulty.master.targets.isMet(by: walled, givens: 24), "Master needs 6 walls")
        let unknown = PuzzleGrade(hardestTier: .advanced, score: 0, techniques: [])
        XCTAssertNil(unknown.steps(atLeast: .intermediate))
        XCTAssertFalse(Difficulty.expert.targets.isMet(by: unknown, givens: 25), "unknown metrics never pass")
    }

    /// Grades saved before issue #92 decode with the new metrics unknown (nil), never zero.
    func testOldGradeDecodesWithUnknownMetrics() throws {
        let old = #"{"hardestTier":2,"score":610,"techniques":["fullHouse","pointing"]}"#
        let grade = try JSONDecoder().decode(PuzzleGrade.self, from: Data(old.utf8))
        XCTAssertNil(grade.stepsPerTier)
        XCTAssertNil(grade.openingSingles)
        XCTAssertEqual(grade.difficulty, .medium)
        let full = PuzzleGrade(hardestTier: .intermediate, score: 610, techniques: [.fullHouse, .pointing],
                               stepsPerTier: [40, 2, 0, 0], openingSingles: 9)
        XCTAssertEqual(try JSONDecoder().decode(PuzzleGrade.self, from: JSONEncoder().encode(full)), full)
    }

    /// Add-back from minimal boards: the result meets every target, keeps the level and the
    /// solution, and grades the same when regraded.
    func testAddingGivensMeetsTheTargets() throws {
        for level in Difficulty.allCases {
            let minimals = BundledPuzzles.all.filter { $0.isDrillOnly && $0.difficulty == level }
            var result: (values: [Int], grade: PuzzleGrade)?
            var minimal: [Int] = [], solution: [Int] = []
            for entry in minimals where result == nil {
                var rng = SeededRandomNumberGenerator(seed: 7)
                minimal = values(entry.initialGrid)
                solution = values(entry.solutionGrid)
                result = PuzzleGrader.addingGivens(to: minimal, solution: solution, level: level, using: &rng)
            }
            let found = try XCTUnwrap(result, "\(level)")
            let givens = found.values.filter { $0 != 0 }.count
            XCTAssertTrue(level.targets.isMet(by: found.grade, givens: givens), "\(level)")
            XCTAssertEqual(found.grade.difficulty, level)
            XCTAssertTrue(zip(minimal, found.values).allSatisfy { $0 == 0 || $0 == $1 }, "only adds givens")
            XCTAssertEqual(SolutionCounter.count(found.values), 1)
            XCTAssertEqual(PuzzleGrader.grade(found.values)?.grade, found.grade)
            // Adding givens never makes a puzzle harder, so asking for a harder level must fail.
            if level != .master {
                var rng = SeededRandomNumberGenerator(seed: 7)
                XCTAssertNil(PuzzleGrader.addingGivens(to: found.values, solution: solution, level: .master, using: &rng),
                             "a board of another level is rejected")
            }
        }
    }

    /// Every technique keeps at least the drills it had before issue #92 (the set from issue #60).
    func testDrillCoverageIsNoLowerThanBefore() {
        let before: [Technique: Int] = [
            .fullHouse: 806, .hiddenSingleBox: 806, .hiddenSingleLine: 677, .nakedSingle: 506, .pointing: 526,
            .claiming: 243, .lockedPair: 107, .lockedTriple: 30, .nakedPair: 193, .hiddenPair: 146, .nakedTriple: 46,
            .hiddenTriple: 9, .nakedQuad: 4, .xWing: 49, .skyscraper: 95, .twoStringKite: 83, .emptyRectangle: 32,
            .swordfish: 4, .xyWing: 102, .xyzWing: 34, .wWing: 68, .simpleColoring: 8, .uniqueRectangle1: 10,
            .uniqueRectangle2: 3, .uniqueRectangle4: 19, .bugPlusOne: 6, .xyChain: 120
        ]
        for (technique, count) in before {
            XCTAssertGreaterThanOrEqual(BundledPuzzles.drills(for: technique).count, count, "\(technique)")
        }
    }

    /// Generation to the targets stays inside the 0.4 s mean budget per level (CODESPEC 2.2),
    /// failed tries and the fallback included (fixed seeds; 10 per level, as single runs vary a lot).
    func testGenerationTimePerLevelStaysInBudget() {
        let service = SudokuGeneratorService()
        for difficulty in Difficulty.allCases {
            let start = Date()
            for seed in UInt64(21)...UInt64(30) { _ = service.generatePuzzle(for: difficulty, seed: seed) }
            let average = Date().timeIntervalSince(start) / 10
            print("generation \(difficulty): \(Int(average * 1000)) ms average")
            XCTAssertLessThan(average, 0.4, "\(difficulty)")
        }
    }

    func testDrillsFindPuzzlesForEachPhaseTwoTechnique() {
        for technique in [Technique.pointing, .claiming, .nakedPair, .hiddenPair, .xWing, .xyWing, .xyChain] {
            let drills = BundledPuzzles.drills(for: technique)
            XCTAssertFalse(drills.isEmpty, "\(technique)")
            XCTAssertEqual(drills.map(\.score), drills.map(\.score).sorted(), "easiest first")
        }
    }

    func testSolutionCounter() {
        XCTAssertEqual(SolutionCounter.count(values(TestData.puzzle.initialGrid)), 1)
        let firstRowOnly = values(String(TestData.puzzle.solutionGrid.prefix(9)) + String(repeating: "0", count: 72))
        XCTAssertEqual(SolutionCounter.count(firstRowOnly), 2, "stops at the limit")
        var broken = values(TestData.puzzle.initialGrid)
        broken[1] = broken[0] // duplicate in row 1
        XCTAssertEqual(SolutionCounter.count(broken), 0)
    }

    func testOldSavedPuzzleDecodesWithoutGradeOrFlag() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TestData.puzzle)) as? [String: Any])
        json["rating"] = 1.5 // written by older builds
        json["generatorBucket"] = "medium"
        let puzzle = try JSONDecoder().decode(SudokuPuzzle.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(puzzle.grade)
        XCTAssertNil(puzzle.hasUniqueSolution)
        XCTAssertTrue(puzzle.isUnique, "generated puzzles are unique")
    }
}
