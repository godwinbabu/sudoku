import XCTest
@testable import PureSudoku

final class GameViewModelTests: XCTestCase {
    private func makeViewModel(settings: Settings = Settings()) -> GameViewModel {
        GameViewModel(state: TestData.newGameState(), settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
    }

    func testNormalModeSetsValueAndClearsCandidates() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else {
            return XCTFail("No editable cell")
        }
        viewModel.select(cell: cell)
        viewModel.setDigit(5)
        XCTAssertEqual(viewModel.state.cells.first(where: { $0.id == cell.id })?.value, 5)
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.isEmpty ?? false)
    }

    func testCandidateModeToggles() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.toggleMode()
        viewModel.setDigit(4)
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.contains(4) ?? false)
        viewModel.setDigit(4)
        XCTAssertFalse(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.contains(4) ?? true)
    }

    func testAutoRemoveCandidates() {
        var settings = Settings()
        settings.autoRemoveCandidates = true
        let viewModel = makeViewModel(settings: settings)
        guard let editable = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: editable)
        viewModel.toggleMode()
        viewModel.setDigit(3)
        // ensure peer candidate exists
        guard let peer = viewModel.state.cells.first(where: { $0.row == editable.row && !$0.given && $0.id != editable.id }) else { return XCTFail("Missing peer") }
        viewModel.select(cell: peer)
        viewModel.toggleMode()
        viewModel.setDigit(3)
        viewModel.toggleMode() // back to normal
        viewModel.select(cell: editable)
        viewModel.setDigit(3)
        let updatedPeer = viewModel.state.cells.first(where: { $0.id == peer.id })
        XCTAssertFalse(updatedPeer?.candidates.contains(3) ?? true)
    }

    func testCheckCellSetsErrorFlag() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.setDigit(1) // wrong on purpose
        viewModel.checkCell()
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.isError ?? false)
    }

    func testRevealCellFillsCorrectValue() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.revealCell()
        let updated = viewModel.state.cells.first(where: { $0.id == cell.id })
        XCTAssertNotNil(updated?.value)
        XCTAssertTrue(updated?.isRevealed ?? false)
        XCTAssertTrue(viewModel.state.usedReveal)
    }

    func testResetClearsInputs() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.setDigit(5)
        viewModel.resetPuzzle()
        XCTAssertNil(viewModel.state.cells.first(where: { $0.id == cell.id })?.value)
        XCTAssertFalse(viewModel.state.usedReveal)
        XCTAssertEqual(viewModel.state.elapsedSeconds, 0)
    }
}
