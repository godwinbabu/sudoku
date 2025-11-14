import XCTest
@testable import PureSudoku

final class PuzzleDataConsistencyTests: XCTestCase {
    func testInitialGridDigitsMatchSolutionDigits() throws {
        let bundle = Bundle(for: type(of: self))
        let repo = SudokuPuzzleRepository(bundle: bundle)
        for difficulty in Difficulty.allCases {
            let puzzles = try repo.loadPuzzles(for: difficulty)
            XCTAssertFalse(puzzles.isEmpty, "No puzzles for \(difficulty)")
            for puzzle in puzzles {
                let initial = Array(puzzle.initialGrid)
                let solution = Array(puzzle.solutionGrid)
                XCTAssertEqual(initial.count, 81)
                XCTAssertEqual(solution.count, 81)
                for i in 0..<81 {
                    if initial[i] != "0" && initial[i] != "." {
                        XCTAssertEqual(initial[i], solution[i], "Puzzle \(puzzle.id) has mismatched given at index \(i) for \(difficulty)")
                    }
                }
            }
        }
    }
}

