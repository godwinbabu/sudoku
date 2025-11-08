import XCTest
@testable import PureSudoku

final class SudokuPuzzleRepositoryTests: XCTestCase {
    func testLoadsPuzzlesForAllDifficulties() throws {
        let bundle = Bundle(for: type(of: self))
        let repository = SudokuPuzzleRepository(bundle: bundle)
        for difficulty in Difficulty.allCases {
            let puzzles = try repository.loadPuzzles(for: difficulty)
            XCTAssertFalse(puzzles.isEmpty)
            XCTAssertEqual(puzzles.first?.initialGrid.count, 81)
            XCTAssertEqual(puzzles.first?.solutionGrid.count, 81)
        }
    }
}
