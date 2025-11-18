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

    func testConflictsAgainstGivenAreFlagged() {
        // Build a minimal row scenario where a given '3' exists and we place another '3' in same row
        var state = TestData.newGameState()
        let validator = SudokuValidator()
        // Find a row with a given value and an editable cell in same row
        guard let givenCell = state.cells.first(where: { $0.given && $0.value == 3 }) ?? state.cells.first(where: { $0.given }) else {
            return XCTFail("Expected at least one given")
        }
        guard let editable = state.cells.first(where: { !$0.given && $0.row == givenCell.row }) else {
            return XCTFail("Expected an editable cell in the same row as a given")
        }
        // Place same value as the given into editable cell
        if let idx = state.cells.firstIndex(where: { $0.id == editable.id }) {
            state.cells[idx].value = givenCell.value
        }
        let conflicts = validator.conflictingIndices(in: state.cells, autoCheckMistakes: true)
        XCTAssertTrue(conflicts.contains(editable.id))
        XCTAssertFalse(conflicts.contains(givenCell.id), "Given should not be flagged as conflicting")
    }
}
