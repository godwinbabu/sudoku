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

    private func makeViewModel() -> ImportPuzzleViewModel {
        ImportPuzzleViewModel(
            createGame: { _, _ in nil },
            saveImage: { _ in nil },
            deleteImage: { _ in }
        )
    }
}
