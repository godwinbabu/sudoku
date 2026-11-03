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
        XCTAssertTrue(app.staticTexts["Medium, then X-Wing, Skyscraper, wings, coloring"].exists)
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
        app.buttons["tool_notes"].tap()
        app.buttons["number_2"].tap()
        XCTAssertTrue(waitForLabel(of: cell, endingWith: "candidates 2", in: app), cell.label)
        app.buttons["moreButton"].tap()
        app.buttons["menu_restart"].tap()
        app.buttons["confirm_action"].tap()
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

    /// A two-finger tap anywhere in a game hushes the screen; a tap brings it back (CODESPEC 12.7).
    func testTwoFingerTapShowsHush() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        let game = element("gameView", in: app)
        XCTAssertTrue(game.waitForExistence(timeout: 2))
        game.twoFingerTap()
        let hush = element("hushView", in: app)
        XCTAssertTrue(hush.waitForExistence(timeout: 2))
        hush.tap()
        XCTAssertTrue(app.buttons["tool_notes"].waitForExistence(timeout: 2))
        XCTAssertFalse(hush.exists)
    }

    func testNotesBadgeToggles() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        let notes = app.buttons["tool_notes"]
        XCTAssertTrue(notes.waitForExistence(timeout: 2))
        XCTAssertEqual(notes.value as? String, "Off")
        notes.tap()
        XCTAssertEqual(notes.value as? String, "On")
        XCTAssertTrue(app.staticTexts["Notes on — digits go in as pencil marks"].exists)
        notes.tap()
        XCTAssertEqual(notes.value as? String, "Off")
    }

    /// Hint card end to end: where to look → technique → why → Place · assisted → Undo (CODESPEC 6.3.1).
    /// The tools and keypad stay in place while the card is open.
    func testHintLadderAppliesAndUndoes() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        let filled = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell_' AND label CONTAINS ' value '"))
        let filledBefore = filled.count
        let keyFrame = app.buttons["number_1"].frame

        app.buttons["tool_hint"].tap()
        XCTAssertTrue(element("hintPanel", in: app).waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["number_1"].frame, keyFrame, "the keypad does not move")
        XCTAssertTrue(app.buttons["tool_hint"].label.contains("Next step"), app.buttons["tool_hint"].label)
        let stepLabel = element("hintStep", in: app)
        let labels = ["Step 1 of 3", "Step 2 of 3", "Step 3 of 3"]
        for (index, label) in labels.enumerated() {
            XCTAssertTrue(stepLabel.label.hasPrefix(label), stepLabel.label)
            if index == 1 { XCTAssertTrue(app.buttons["hint_lesson"].exists, "the lesson link shows from step 2") }
            if index < 2 {
                XCTAssertFalse(app.buttons["hint_apply"].exists)
                app.buttons["hint_next"].tap()
            }
        }
        XCTAssertFalse(app.buttons["hint_next"].exists, "three steps only")
        let apply = app.buttons["hint_apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 2))
        XCTAssertTrue(apply.label.hasSuffix("· assisted"), apply.label)
        XCTAssertEqual(filled.count, filledBefore, "nothing changes before Place")
        apply.tap()

        XCTAssertFalse(element("hintPanel", in: app).exists)
        XCTAssertGreaterThan(filled.count, filledBefore, "Place put in the hinted digit")
        app.buttons["tool_undo"].tap()
        XCTAssertEqual(filled.count, filledBefore, "one Undo reverts the hint")
    }

    /// A digit that repeats in the row is always wrong; the hint must point at it first and clear it.
    func testMistakeHintClearsTheWrongDigit() {
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

        app.buttons["tool_hint"].tap()
        XCTAssertTrue(app.buttons["hint_next"].waitForExistence(timeout: 2))
        app.buttons["hint_next"].tap()
        XCTAssertTrue(element("hintStep", in: app).label.hasSuffix("Mistake"), element("hintStep", in: app).label)
        app.buttons["hint_next"].tap()
        let clear = app.buttons["hint_apply"]
        XCTAssertTrue(clear.waitForExistence(timeout: 2))
        XCTAssertEqual(clear.label, "Clear it")
        clear.tap()
        XCTAssertFalse(element("hintPanel", in: app).exists)
        XCTAssertTrue(waitForLabel(of: cell, endingWith: " empty", in: app), cell.label)
    }

    /// Settings → Night preset, then a game in Night (CODESPEC 12).
    func testNightToggleOpensANightGame() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 2))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(element("settings_preset", in: app).waitForExistence(timeout: 2))
        app.buttons["settings_done"].tap()
        let easy = app.buttons["difficulty_easy"]
        XCTAssertTrue(waitUntilHittable(easy), "Settings closed")

        let toggle = app.buttons["bedtimeToggle"]
        let startedOn = toggle.label.hasSuffix("On")
        if !startedOn { toggle.tap() }
        XCTAssertTrue(waitForLabel(of: toggle, endingWith: "On", in: app), toggle.label)
        easy.tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        snapshot(app, "night-game")
        app.buttons["backButton"].tap()
        if !startedOn, waitUntilHittable(toggle) { toggle.tap() } // leave the app as found
    }

    /// Learn → a technique → its worked example and practice (CODESPEC 13.5).
    func testLearnShowsALessonWithPractice() {
        let app = XCUIApplication()
        app.launch()
        openPointingLesson(in: app)
        XCTAssertTrue(element("lessonBoard", in: app).waitForExistence(timeout: 5))
        snapshot(app, "lesson")
        app.buttons["lesson_showResult"].tap()
        XCTAssertTrue(app.buttons["lesson_practice1"].waitForExistence(timeout: 2))
    }

    /// Goodnight after a practice solve goes back to the main menu, not the lesson (CODESPEC 3.2).
    func testGoodnightFromPracticeReturnsToMenu() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestNearlySolved"]
        app.launch()
        openPointingLesson(in: app)
        let practice = app.buttons["lesson_practice1"]
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        for _ in 0..<4 where !practice.isHittable { app.swipeUp() }
        practice.tap()
        firstEmptyCell(in: app).tap()
        // One cell is left, so only its digit's key is still enabled.
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'number_' AND isEnabled == true")).firstMatch.tap()
        XCTAssertTrue(app.buttons["solved_goodnight"].waitForExistence(timeout: 3))
        app.buttons["solved_goodnight"].tap()
        let goodnight = element("goodnightView", in: app)
        XCTAssertTrue(goodnight.waitForExistence(timeout: 2))
        goodnight.tap()
        XCTAssertTrue(app.buttons["difficulty_easy"].waitForExistence(timeout: 3), "back on the main menu")
        XCTAssertFalse(app.buttons["lesson_practice1"].exists, "not the lesson")
    }

    /// Main menu → Learn → the Pointing lesson.
    private func openPointingLesson(in app: XCUIApplication) {
        let learn = app.buttons["learnButton"]
        for _ in 0..<3 where !learn.isHittable { app.swipeUp() }
        learn.tap()
        XCTAssertTrue(element("learnView", in: app).waitForExistence(timeout: 2))
        let lesson = app.buttons["learn_pointing"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 2))
        for _ in 0..<4 where !lesson.isHittable { app.swipeUp() }
        lesson.tap()
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
