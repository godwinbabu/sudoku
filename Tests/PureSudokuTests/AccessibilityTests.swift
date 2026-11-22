import XCTest
import SwiftUI
@testable import PureSudoku

/// QA pass fixes for VoiceOver and Night readability (#29, #31).
@MainActor
final class AccessibilityTests: XCTestCase {
    func testCellStateTextNamesGivenAndMistake() {
        var cell = TestData.newGameState().cells.first { $0.given }!
        XCTAssertEqual(SudokuGridView.stateText(cell, ringed: nil), "given")
        cell.given = false
        cell.isError = true
        XCTAssertEqual(SudokuGridView.stateText(cell, ringed: nil), "mistake")
        XCTAssertEqual(SudokuGridView.stateText(cell, ringed: "Unsure"), "mistake, Unsure")
        cell.isError = false
        XCTAssertEqual(SudokuGridView.stateText(cell, ringed: nil), "", "a plain entry adds nothing")
    }
}
