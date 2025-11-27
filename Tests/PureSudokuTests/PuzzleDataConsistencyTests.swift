import XCTest
@testable import PureSudoku

final class PuzzleDataConsistencyTests: XCTestCase {
    func testInitialGridDigitsMatchSolutionDigits() throws {
        let repo = SudokuPuzzleRepository(generator: SudokuGeneratorService())
        for difficulty in Difficulty.allCases {
            let puzzle = repo.generate(for: difficulty, mode: .random).puzzle
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
