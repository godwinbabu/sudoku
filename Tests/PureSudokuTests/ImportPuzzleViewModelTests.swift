import XCTest
import UIKit
@testable import PureSudoku

@MainActor
final class ImportPuzzleViewModelTests: XCTestCase {
    func testConflictsDetectedInRow() {
        let viewModel = makeViewModel()
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        viewModel.selectedIndex = 1
        viewModel.setDigit(5)

        XCTAssertTrue(viewModel.conflictIndices.contains(0))
        XCTAssertTrue(viewModel.conflictIndices.contains(1))
        XCTAssertFalse(viewModel.canStart)
    }

    func testSolvableStateUpdates() async throws {
        let viewModel = makeViewModel()
        let values = TestData.puzzle.initialGrid.map { char -> Int? in
            guard let value = Int(String(char)), value > 0 else { return nil }
            return value
        }
        viewModel.loadGrid(values)

        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(viewModel.solvableState, .solvable)
    }

    func testRequiresMinimumClues() {
        let viewModel = makeViewModel()
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        viewModel.selectedIndex = 1
        viewModel.setDigit(3)

        XCTAssertFalse(viewModel.canStart)
    }

    /// Source until a photo or "Type it in"; then Check the grid (CODESPEC 3.4).
    func testStepsFromSourceToCheckTheGrid() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.step, .source)
        viewModel.enterByHand()
        XCTAssertEqual(viewModel.step, .review)
        let loaded = makeViewModel()
        loaded.loadGrid(Array(repeating: nil, count: 80) + [5])
        XCTAssertEqual(loaded.step, .review, "a read grid goes straight to the check")
    }

    func testConflictSummaryNamesTheFirstRepeatedDigit() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.conflictSummary(names: .plain))
        var values = [Int?](repeating: nil, count: 81)
        values[27] = 4 // row 4
        values[31] = 4
        viewModel.loadGrid(values)
        XCTAssertEqual(viewModel.conflictSummary(names: .plain), "Two 4s in row 4.")
        XCTAssertEqual(viewModel.conflictSummary(names: .grid), "Two 4s in R4.")
    }

    /// Ringed cells clear when tapped (confirmed) or fixed.
    func testUnsureCellsClearWhenTappedOrFixed() {
        let viewModel = makeViewModel()
        var values = [Int?](repeating: nil, count: 81)
        values[5] = 3
        values[47] = 8
        viewModel.loadGrid(values, unsure: [5, 47])
        viewModel.selectCell(id: viewModel.cellIDs[5])
        XCTAssertEqual(viewModel.unsureIndices, [47])
        viewModel.selectedIndex = 47
        viewModel.setDigit(6)
        XCTAssertTrue(viewModel.unsureIndices.isEmpty)
    }

    /// Start over drops the photo, the digits and Type it in, and goes back to Source.
    func testStartOverReturnsToSourceAndDeletesThePhoto() {
        var deleted: [String] = []
        let viewModel = ImportPuzzleViewModel(createGame: { _, _ in nil }, saveImage: { _ in "photo-1" },
                                              deleteImage: { deleted.append($0) })
        viewModel.updateImage(UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in })
        XCTAssertEqual(viewModel.step, .reading, "Reading shows at once, never Check the grid first")
        var values = [Int?](repeating: nil, count: 81)
        values[0] = 5
        viewModel.loadGrid(values, unsure: [0])
        viewModel.startOver()
        XCTAssertEqual(viewModel.step, .source)
        XCTAssertNil(viewModel.image)
        XCTAssertEqual(viewModel.filledCount, 0)
        XCTAssertTrue(viewModel.unsureIndices.isEmpty)
        XCTAssertEqual(deleted, ["photo-1"])

        let typed = makeViewModel()
        typed.enterByHand()
        typed.startOver()
        XCTAssertEqual(typed.step, .source)
    }

    /// Unsure comes from the candidate's own confidence; 0.6 itself is sure.
    func testDetectorReadingUsesTheCandidateConfidence() {
        // A box Vision is sure of (observation 1.0) can still hold a doubtful read (candidate 0.3).
        let observationConfidence: Float = 1.0, candidateConfidence: Float = 0.3
        XCTAssertNotEqual(observationConfidence, candidateConfidence)
        XCTAssertEqual(SudokuImageDetector.reading(text: "7", confidence: candidateConfidence)?.unsure, true)
        XCTAssertEqual(SudokuImageDetector.reading(text: " 4 ", confidence: 0.6)?.digit, 4)
        XCTAssertEqual(SudokuImageDetector.reading(text: "4", confidence: 0.6)?.unsure, false)
        XCTAssertEqual(SudokuImageDetector.reading(text: "4", confidence: 0.59)?.unsure, true)
        XCTAssertNil(SudokuImageDetector.reading(text: "0", confidence: 1))
        XCTAssertNil(SudokuImageDetector.reading(text: "12", confidence: 1))
    }

    private func makeViewModel() -> ImportPuzzleViewModel {
        ImportPuzzleViewModel(
            createGame: { _, _ in nil },
            saveImage: { _ in nil },
            deleteImage: { _ in }
        )
    }

    /// The empty grid says what to do; the line goes once a digit is in (issue 51).
    func testEmptyGridHint() {
        let viewModel = makeViewModel()
        viewModel.enterByHand()
        XCTAssertEqual(viewModel.emptyGridHint, "Type the digits printed in the puzzle: tap a cell, then a number.")
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        XCTAssertNil(viewModel.emptyGridHint)
    }
}
