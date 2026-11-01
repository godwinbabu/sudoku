import XCTest
@testable import PureSudoku

@MainActor
final class AppControllerTests: XCTestCase {
    func testBedtimeModeUsesTheBedtimeDisplayProfile() {
        let (controller, _) = makeTestController()
        let night = DisplayProfile(name: "Night wake-up", dimness: 1)
        controller.updateSettings { settings in
            let reading = settings.displayProfiles[0]
            settings.saveDisplayProfile(night)
            settings.activeDisplayProfileID = reading.id
            settings.bedtimeDisplayProfileID = night.id
        }
        XCTAssertNotEqual(controller.settings.currentDisplayProfile.id, night.id)
        controller.updateSettings { $0.toggleBedtimeMode(true) }
        XCTAssertEqual(controller.settings.currentDisplayProfile.id, night.id)
        XCTAssertEqual(controller.settings.themeEffective, .sleep)
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
