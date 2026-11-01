import XCTest
@testable import PureSudoku

@MainActor
final class AppControllerTests: XCTestCase {
    func testBedtimeModeForcesMaximumDimming() {
        let (controller, _) = makeTestController()
        controller.updateSettings { settings in
            settings.sleepBrightness = .normal
            settings.toggleBedtimeMode(true)
        }
        XCTAssertEqual(controller.sleepOverlayOpacity, SleepBrightness.extraDim.overlayOpacity)
    }

    func testUpdateSettingsAppliesImmediately() {
        let (controller, _) = makeTestController()
        controller.updateSettings { $0.showTimer = false }
        XCTAssertFalse(controller.settings.showTimer)
    }

    func testCompletionThenResetKeepsTheResetGame() async {
        let (controller, _) = makeTestController()
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        let viewModel = controller.makeGameViewModel(for: .easy)
        viewModel.revealPuzzle()
        viewModel.resetPuzzle()
        XCTAssertEqual(controller.activeGames[.easy]?.isCompleted, false)
        XCTAssertEqual(controller.stats, Stats(), "revealed games do not count")
    }
}
