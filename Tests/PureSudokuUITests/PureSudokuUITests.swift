import XCTest

final class PureSudokuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Finds a screen or overlay by identifier regardless of its element type.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Returns a stable query for the first empty cell (puzzles are random).
    private func firstEmptyCell(in app: XCUIApplication) -> XCUIElement {
        let empty = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell_' AND label ENDSWITH ' empty'")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 2))
        return app.buttons[empty.identifier]
    }

    /// Waits for `cell`'s label to end with `suffix`. Actions like Reset update the grid asynchronously.
    private func waitForLabel(of cell: XCUIElement, endingWith suffix: String, in app: XCUIApplication) -> Bool {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label ENDSWITH %@", cell.identifier, suffix))
            .firstMatch.waitForExistence(timeout: 2)
    }

    func testLaunchShowsDifficultyButtons() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["difficulty_easy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["difficulty_medium"].exists)
        XCTAssertTrue(app.buttons["difficulty_hard"].exists)
        // Each level names the techniques it needs (CODESPEC 1, 2.2).
        XCTAssertTrue(app.staticTexts["Medium, then X-Wing, Swordfish, XY-Wing"].exists)
    }

    func testImportButtonOpensImportScreen() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["importPuzzleButton"].tap()
        XCTAssertTrue(element("importPuzzleView", in: app).waitForExistence(timeout: 2))
    }

    func testStartingGameShowsGridAndAllowsEntry() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        let cell = firstEmptyCell(in: app)
        cell.tap()
        app.buttons["number_1"].tap()
        XCTAssertTrue(cell.label.hasSuffix("value 1"), cell.label)
    }

    func testCandidateModeAndReset() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        let cell = firstEmptyCell(in: app)
        cell.tap()
        app.buttons["mode_candidate"].tap()
        app.buttons["number_2"].tap()
        XCTAssertTrue(waitForLabel(of: cell, endingWith: "candidates 2", in: app), cell.label)
        app.buttons["gameMenuButton"].tap()
        app.buttons["Reset Puzzle"].tap()
        app.buttons["Confirm"].tap()
        XCTAssertTrue(waitForLabel(of: cell, endingWith: " empty", in: app), cell.label)
    }

    func testPauseAndResumeShowsOverlay() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        app.buttons["timerToggle"].tap()
        XCTAssertTrue(element("pauseOverlay", in: app).waitForExistence(timeout: 2))
        app.buttons["Resume"].tap()
        XCTAssertFalse(element("pauseOverlay", in: app).exists)
        app.buttons["timerToggle"].tap()
        XCTAssertTrue(element("pauseOverlay", in: app).waitForExistence(timeout: 2))
    }

    /// Hint ladder end to end: name → where → why → ask → result → Apply → Undo (CODESPEC 6.3.1).
    func testHintLadderAppliesAndUndoes() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        let filled = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell_' AND label CONTAINS ' value '"))
        let filledBefore = filled.count

        app.buttons["action_Hint"].tap()
        XCTAssertTrue(element("hintPanel", in: app).waitForExistence(timeout: 2))
        snapshot(app, "1-name")
        app.buttons["hint_next"].tap()
        snapshot(app, "2-where")
        app.buttons["hint_next"].tap()
        snapshot(app, "3-why")
        app.buttons["hint_next"].tap()
        XCTAssertTrue(app.buttons["hint_showResult"].waitForExistence(timeout: 2))
        app.buttons["hint_showResult"].tap()
        XCTAssertTrue(app.buttons["hint_apply"].waitForExistence(timeout: 2))
        snapshot(app, "4-result")
        XCTAssertEqual(filled.count, filledBefore, "nothing changes before Apply")
        app.buttons["hint_apply"].tap()

        XCTAssertFalse(element("hintPanel", in: app).exists)
        XCTAssertGreaterThan(filled.count, filledBefore, "Apply placed the hinted digit")
        app.buttons["mode_undo"].tap()
        XCTAssertEqual(filled.count, filledBefore, "one Undo reverts the hint")
    }

    /// A digit that repeats in the row is always wrong; the hint must report it and offer Undo.
    func testMistakePanelOffersUndo() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        let cell = firstEmptyCell(in: app)
        let row = cell.identifier.split(separator: "_")[1]
        let rowValue = (0..<9).lazy.compactMap { col -> String? in
            let label = app.buttons["cell_\(row)_\(col)"].label
            guard let range = label.range(of: " value ") else { return nil }
            return String(label[range.upperBound...])
        }.first
        guard let digit = rowValue else { return XCTFail("row has no filled cell") }
        cell.tap()
        app.buttons["number_\(digit)"].tap()
        XCTAssertTrue(waitForLabel(of: cell, endingWith: "value \(digit)", in: app))

        app.buttons["action_Hint"].tap()
        XCTAssertTrue(app.buttons["hint_undo"].waitForExistence(timeout: 2))
        app.buttons["hint_undo"].tap()
        XCTAssertFalse(element("hintPanel", in: app).exists)
        XCTAssertTrue(waitForLabel(of: cell, endingWith: " empty", in: app), cell.label)
    }

    /// Display calibration from Settings, then a game in Bedtime Mode (CODESPEC 12.3).
    func testCalibrateDisplayAndPlayInBedtime() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 2))
        app.buttons["settingsButton"].tap()
        let adjust = app.buttons["settings_adjustDisplay"]
        for _ in 0..<5 where !adjust.isHittable { app.swipeUp() }
        adjust.tap()
        let dimness = app.sliders["calibration_dimness"]
        XCTAssertTrue(dimness.waitForExistence(timeout: 2))
        dimness.adjust(toNormalizedSliderPosition: 0.9)
        snapshot(app, "calibration")
        app.buttons["calibration_save"].tap()
        XCTAssertFalse(dimness.waitForExistence(timeout: 1))
        app.buttons["settings_done"].tap()
        let easy = app.buttons["difficulty_easy"]
        XCTAssertTrue(waitUntilHittable(easy), "Settings closed")

        let toggle = app.buttons["bedtimeToggle"]
        if toggle.label.hasSuffix("Off") { toggle.tap() }
        if app.buttons["calibration_save"].waitForExistence(timeout: 1) {
            app.buttons["Cancel"].tap()
            XCTAssertTrue(waitUntilHittable(easy))
        }
        XCTAssertTrue(toggle.label.hasSuffix("On"), toggle.label)
        easy.tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        snapshot(app, "bedtime-game")
        app.buttons["backButton"].tap()
        if waitUntilHittable(toggle), toggle.label.hasSuffix("On") { toggle.tap() } // leave the app as found
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "hint-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
