import XCTest
@testable import PureSudoku

final class SudokuValidatorTests: XCTestCase {
    func testValidSolutionGridPasses() {
        let validator = SudokuValidator()
        XCTAssertTrue(validator.isValid(solution: TestData.puzzle.solutionGrid))
    }

    func testInvalidRowFails() {
        let validator = SudokuValidator()
        var chars = Array(TestData.puzzle.solutionGrid)
        chars[1] = chars[0] // duplicate in row
        let invalid = String(chars)
        XCTAssertFalse(validator.isValid(solution: invalid))
    }

    func testCompletionDetection() {
        var state = TestData.newGameState()
        let validator = SudokuValidator()
        for index in state.cells.indices where !state.cells[index].given {
            let row = state.cells[index].row
            let col = state.cells[index].col
            state.cells[index].value = validator.solutionValue(row: row, col: col, solution: state.puzzle.solutionGrid)
        }
        XCTAssertTrue(validator.isSolved(cells: state.cells, solution: state.puzzle.solutionGrid))
    }
}
