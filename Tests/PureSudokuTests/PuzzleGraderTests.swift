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
            }
        }
    }

    func testFallsBackToABundledPuzzleOfTheSameLevel() {
        let service = SudokuGeneratorService(config: SudokuGeneratorConfiguration(maxAttempts: 0))
        for difficulty in Difficulty.allCases {
            let result = service.generatePuzzle(for: difficulty, seed: 3)
            XCTAssertTrue(result.isBundled)
            XCTAssertEqual(result.grade.difficulty, difficulty)
        }
    }

    func testBundledPuzzlesAreValidUniqueAndCorrectlyGraded() {
        XCTAssertEqual(BundledPuzzles.all.count, 600)
        for difficulty in Difficulty.allCases {
            XCTAssertEqual(BundledPuzzles.puzzles(for: difficulty).count, 120)
        }
        for entry in BundledPuzzles.all {
            let grid = values(entry.initialGrid)
            XCTAssertEqual(SolutionCounter.count(grid), 1, entry.initialGrid)
            let regraded = PuzzleGrader.grade(grid)
            XCTAssertEqual(regraded?.grade.difficulty, entry.difficulty)
            XCTAssertEqual(regraded?.grade.score, entry.score)
            XCTAssertEqual(regraded?.grade.techniques, entry.techniques)
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
