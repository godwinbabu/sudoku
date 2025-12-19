import XCTest

final class PureSudokuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunchShowsDifficultyButtons() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["difficulty_easy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["difficulty_medium"].exists)
        XCTAssertTrue(app.buttons["difficulty_hard"].exists)
    }

    func testStartingGameShowsGridAndAllowsEntry() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(app.otherElements["gameView"].waitForExistence(timeout: 2))
        let cell = app.buttons["cell_0_0"].firstMatch
        XCTAssertTrue(cell.exists)
        cell.tap()
        app.buttons["number_1"].tap()
        XCTAssertTrue(cell.label.contains("1"))
    }

    func testCandidateModeAndReset() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        let cell = app.buttons["cell_0_1"].firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 2))
        cell.tap()
        app.buttons["mode_candidate"].tap()
        app.buttons["number_2"].tap()
        app.buttons["gameMenuButton"].tap()
        app.buttons["Reset Puzzle"].tap()
        app.buttons["Confirm"].tap()
        XCTAssertFalse(cell.label.contains("2"))
    }

    func testPauseAndResumeShowsOverlay() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(app.otherElements["gameView"].waitForExistence(timeout: 2))
        app.buttons["timerToggle"].tap()
        XCTAssertTrue(app.otherElements["pauseOverlay"].waitForExistence(timeout: 2))
        app.buttons["Resume"].tap()
        XCTAssertFalse(app.otherElements["pauseOverlay"].exists)
        app.buttons["timerToggle"].tap()
        XCTAssertTrue(app.otherElements["pauseOverlay"].waitForExistence(timeout: 2))
    }
}
