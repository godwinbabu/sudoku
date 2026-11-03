import XCTest

final class PureSudokuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches past the first-night flow, which would otherwise cover the app whenever the
    /// simulator clock is after dark (CODESPEC 12.3).
    private func launchApp(_ arguments: [String] = [], skipFirstNight: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (skipFirstNight ? ["-uiTestSkipFirstNight"] : []) + arguments
        app.launch()
        return app
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
        let app = launchApp()
        XCTAssertTrue(app.buttons["difficulty_easy"].waitForExistence(timeout: 2))
        for level in ["medium", "hard", "expert", "master"] {
            XCTAssertTrue(app.buttons["difficulty_\(level)"].exists, level)
        }
        // Each level names the hardest technique it needs (CODESPEC 1, 2.2).
        XCTAssertTrue(app.buttons["difficulty_expert"].label.contains("Wings & fish"), app.buttons["difficulty_expert"].label)
        XCTAssertTrue(app.buttons["difficulty_master"].label.contains("Chains & beyond"), app.buttons["difficulty_master"].label)
        XCTAssertFalse(app.buttons["bedtimeToggle"].exists, "the Night bar is gone; the moon replaces it")
    }

    /// Play, Learn and Journal each show their screen and the moon (CODESPEC 3.1).
    func testTabsSwitch() {
        let app = launchApp()
        XCTAssertTrue(element("homeView", in: app).waitForExistence(timeout: 2))
        app.buttons["tab_learn"].tap()
        XCTAssertTrue(element("learnView", in: app).waitForExistence(timeout: 2))
        XCTAssertFalse(element("homeView", in: app).exists)
        XCTAssertTrue(app.buttons["nightButton"].exists, "Learn has the moon")
        app.buttons["tab_journal"].tap()
        XCTAssertTrue(element("journalView", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(element("journal_row_master", in: app).exists, "the solved table has all five levels")
        XCTAssertTrue(app.buttons["nightButton"].exists, "Journal has the moon")
        XCTAssertTrue(app.buttons["tab_journal"].isSelected)
        app.buttons["tab_play"].tap()
        XCTAssertTrue(element("homeView", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["tab_play"].isSelected)
    }

    /// Home starts an Expert game; back on Home, the Continue card resumes it.
    func testHomeStartsAnExpertGameAndContinues() {
        let app = launchApp()
        let expert = app.buttons["difficulty_expert"]
        XCTAssertTrue(expert.waitForExistence(timeout: 2))
        startLevel("expert", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["EXPERT"].exists, "the header names the level")
        XCTAssertFalse(app.buttons["tab_play"].exists, "the game covers the tab bar")
        let cell = firstEmptyCell(in: app)
        let id = cell.identifier
        cell.tap()
        app.buttons["number_1"].tap()
        app.buttons["backButton"].tap()
        let card = element("continueCard", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 2))
        XCTAssertTrue(card.label.contains("Expert"), card.label)
        card.tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[id].label.hasSuffix("value 1"), "the same game, with its entry")
    }

    func testImportButtonOpensImportScreen() {
        let app = launchApp()
        app.buttons["importPuzzleButton"].tap()
        XCTAssertTrue(element("importPuzzleView", in: app).waitForExistence(timeout: 2))
    }

    func testStartingGameShowsGridAndAllowsEntry() {
        let app = launchApp()
        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        let cell = firstEmptyCell(in: app)
        cell.tap()
        app.buttons["number_1"].tap()
        XCTAssertTrue(cell.label.hasSuffix("value 1"), cell.label)
    }

    func testCandidateModeAndReset() {
        let app = launchApp()
        startLevel("easy", in: app)
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
        let app = launchApp()
        startLevel("easy", in: app)
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
        let app = launchApp()
        startLevel("easy", in: app)
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
        let app = launchApp()
        startLevel("easy", in: app)
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
        let app = launchApp()
        startLevel("easy", in: app)
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
        let app = launchApp()
        startLevel("easy", in: app)
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

    /// Taps a level on Home. A game left unfinished by an earlier test asks first; take New.
    private func startLevel(_ level: String, in app: XCUIApplication) {
        app.buttons["difficulty_\(level)"].tap()
        let replace = app.buttons["confirm_action"]
        if replace.waitForExistence(timeout: 1), element("confirmDialog", in: app).exists { replace.tap() }
    }

    /// Sets Journal → Show timer from Home and returns to Home; returns whether it was on before.
    private func setShowTimer(_ on: Bool, in app: XCUIApplication) -> Bool {
        if !app.buttons["tab_journal"].exists { app.buttons["backButton"].tap() }
        app.buttons["tab_journal"].tap()
        let toggle = app.buttons["journal_showTimer"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        let wasOn = toggle.value as? String == "On"
        if wasOn != on { toggle.tap() }
        app.buttons["tab_play"].tap()
        return wasOn
    }

    /// Every cell's label, in reading order.
    private func boardLabels(in app: XCUIApplication) -> [String] {
        (0..<9).flatMap { row in (0..<9).map { app.buttons["cell_\(row)_\($0)"].label } }
    }

    /// Journal → Display & Night, then Night from the moon and a game in Night (CODESPEC 12).
    func testJournalDisplayAndANightGame() {
        let app = launchApp()
        app.buttons["tab_journal"].tap()
        let display = element("settings_display", in: app)
        XCTAssertTrue(display.waitForExistence(timeout: 2))
        display.tap()
        XCTAssertTrue(element("displaySettings", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["display_preset_lightsOut"].exists)
        XCTAssertTrue(app.buttons["display_appearance_afterDark"].exists)
        XCTAssertFalse(app.buttons["tab_play"].exists, "Display & Night covers the tab bar")
        app.buttons["display_back"].tap()
        XCTAssertTrue(waitUntilHittable(app.buttons["tab_play"]))
        app.buttons["tab_play"].tap()

        let original = setAppearance("night", in: app)
        XCTAssertTrue(waitUntilHittable(app.buttons["difficulty_easy"]))
        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        snapshot(app, "night-game")
        app.buttons["backButton"].tap()
        if let original { _ = setAppearance(original, in: app) } // leave the app as found
    }

    /// Opens an Easy game from Home, checks for the timer, and goes back.
    private func gameShowsTimer(in app: XCUIApplication) -> Bool {
        app.buttons["tab_play"].tap()
        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        let shows = element("timerLabel", in: app).waitForExistence(timeout: 1)
        app.buttons["backButton"].tap()
        return shows
    }

    /// Picks Day, Night or After dark in the Night sheet; returns the one selected before.
    private func setAppearance(_ appearance: String, in app: XCUIApplication) -> String? {
        app.buttons["nightButton"].tap()
        let sheet = element("nightSheet", in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        let original = ["day", "night", "afterDark"].first { app.buttons["night_appearance_\($0)"].isSelected }
        app.buttons["night_appearance_\(appearance)"].tap()
        app.buttons["night_close"].tap()
        XCTAssertTrue(waitForAbsence(sheet))
        return original
    }

    /// The moon opens the Night sheet on the main menu and in a game; the backdrop and × close it (CODESPEC 12.2).
    func testMoonOpensTheNightSheet() {
        let app = launchApp()
        let moon = app.buttons["nightButton"]
        XCTAssertTrue(moon.waitForExistence(timeout: 2))
        moon.tap()
        let sheet = element("nightSheet", in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["night_appearance_afterDark"].exists)
        XCTAssertTrue(app.buttons["night_clarity_bold"].exists)
        app.buttons["night_close"].tap()
        XCTAssertTrue(waitForAbsence(sheet), "× closes the sheet")

        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 2))
        let gameMoon = app.buttons["nightButton"]
        XCTAssertTrue(waitUntilHittable(gameMoon))
        gameMoon.tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        // Tap the backdrop halfway between the top of the screen and the panel.
        let panelTop = sheet.frame.minY
        XCTAssertGreaterThanOrEqual(panelTop, 56, "some backdrop always shows")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: panelTop / 2)).tap()
        XCTAssertTrue(waitForAbsence(sheet), "the backdrop closes the sheet")
        XCTAssertTrue(element("gameView", in: app).exists, "still in the game")
    }

    /// Every Night sheet control can be reached, scrolling if the screen is small (iPhone SE).
    func testNightSheetControlsAreReachable() {
        let app = launchApp()
        let moon = app.buttons["nightButton"]
        XCTAssertTrue(moon.waitForExistence(timeout: 2))
        moon.tap()
        let sheet = element("nightSheet", in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        let ids = ["day", "night", "afterDark"].map { "night_appearance_\($0)" }
        let original = ids.first { app.buttons[$0].isSelected }
        app.buttons["night_appearance_night"].tap() // the Night-only controls appear
        let controls = ids + ["readingLamp", "lightsOut", "redLight"].map { "night_preset_\($0)" }
            + ["night_glow", "night_warmth"] + ["standard", "large", "bold"].map { "night_clarity_\($0)" }
            + ["night_drift", "night_calibrate"]
        for id in controls {
            let control = element(id, in: app)
            XCTAssertTrue(control.waitForExistence(timeout: 2), id)
            for _ in 0..<4 where !control.isHittable { sheet.swipeUp() }
            XCTAssertTrue(control.isHittable, "\(id) can be reached")
        }
        let close = app.buttons["night_close"]
        for _ in 0..<4 where !close.isHittable { sheet.swipeDown() }
        if let original { app.buttons[original].tap() } // leave the app as found
        close.tap()
        XCTAssertTrue(waitForAbsence(sheet))
    }

    /// First night, without the skip argument: picking Night on Display & Night shows the flow on
    /// top; it runs to the end and returns to the page (CODESPEC 12.3).
    func testFirstNightShowsAboveSettingsAndCompletes() {
        let app = launchApp(["-uiTestFirstNight"], skipFirstNight: false)
        XCTAssertFalse(element("firstNight", in: app).exists, "Day: no first night yet")
        app.buttons["tab_journal"].tap()
        let display = element("settings_display", in: app)
        XCTAssertTrue(display.waitForExistence(timeout: 2))
        display.tap()
        XCTAssertTrue(app.buttons["display_appearance_night"].waitForExistence(timeout: 2))
        app.buttons["display_appearance_night"].tap()

        XCTAssertTrue(element("firstNight", in: app).waitForExistence(timeout: 3))
        let calibrate = app.buttons["firstNight_calibrate"]
        XCTAssertTrue(waitUntilHittable(calibrate), "the flow is on top")
        calibrate.tap()
        let tile = app.buttons["calibrate_14"]
        XCTAssertTrue(tile.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["calibrate_cancel"].exists, "first run has no Cancel")
        tile.tap()
        app.buttons["calibrate_use"].tap()
        XCTAssertTrue(app.staticTexts["Glow set to 18%."].waitForExistence(timeout: 2))
        app.buttons["firstNight_start"].tap()
        XCTAssertTrue(waitForAbsence(element("firstNight", in: app)))
        let day = app.buttons["display_appearance_day"]
        XCTAssertTrue(waitUntilHittable(day), "back on Display & Night")
        day.tap() // leave the app in Day
    }

    /// Learn → a technique → its worked example and practice (CODESPEC 13.5).
    func testLearnShowsALessonWithPractice() {
        let app = launchApp()
        openPointingLesson(in: app)
        XCTAssertTrue(element("lessonBoard", in: app).waitForExistence(timeout: 5))
        snapshot(app, "lesson")
        app.buttons["lesson_showResult"].tap()
        XCTAssertTrue(app.buttons["lesson_practice1"].waitForExistence(timeout: 2))
    }

    /// Goodnight after a practice solve goes back to the main menu, not the lesson (CODESPEC 3.2).
    func testGoodnightFromPracticeReturnsToMenu() {
        let app = launchApp(["-uiTestNearlySolved"])
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
        XCTAssertTrue(app.buttons["difficulty_easy"].waitForExistence(timeout: 3), "back on Home")
        XCTAssertFalse(app.buttons["lesson_practice1"].exists, "not the lesson")
    }

    /// Learn tab → the Pointing lesson.
    private func openPointingLesson(in app: XCUIApplication) {
        app.buttons["tab_learn"].tap()
        XCTAssertTrue(element("learnView", in: app).waitForExistence(timeout: 2))
        let lesson = app.buttons["learn_pointing"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 2))
        for _ in 0..<4 where !lesson.isHittable { app.swipeUp() }
        lesson.tap()
    }

    private func waitForAbsence(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: element)], timeout: timeout) == .completed
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

// Phase 5 flows: replace, lesson round trip, Journal timer.
extension PureSudokuUITests {
    /// A level with an unfinished game asks before replacing it: Continue resumes it, New starts over.
    func testLevelAsksBeforeReplacingAnUnfinishedGame() {
        let app = launchApp()
        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        let cell = firstEmptyCell(in: app)
        let id = cell.identifier
        cell.tap()
        app.buttons["number_1"].tap()
        let board = boardLabels(in: app)
        app.buttons["backButton"].tap()

        app.buttons["difficulty_easy"].tap()
        let dialog = element("confirmDialog", in: app)
        XCTAssertTrue(dialog.waitForExistence(timeout: 2), "asks first")
        XCTAssertTrue(app.staticTexts["Replace your unfinished Easy game?"].exists)
        app.buttons["confirm_continue"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[id].label.hasSuffix("value 1"), "Continue resumes the same game")
        app.buttons["backButton"].tap()

        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(dialog.waitForExistence(timeout: 2))
        app.buttons["confirm_action"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        XCTAssertNotEqual(boardLabels(in: app), board, "New starts a different puzzle")
        app.buttons["backButton"].tap()

        app.buttons["difficulty_easy"].tap() // nothing entered yet: no question
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(dialog.exists)
    }

    /// Hint → Lesson → Back returns to the same game, and its timer runs again.
    func testHintLessonReturnsToTheSameGame() {
        let app = launchApp()
        let timerWasOn = setShowTimer(true, in: app) // an earlier test may have left it off
        defer { if !timerWasOn { _ = setShowTimer(false, in: app) } }
        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        let board = boardLabels(in: app) // no entry: a wrong one would make the hint a mistake card
        app.buttons["tool_hint"].tap()
        XCTAssertTrue(app.buttons["hint_next"].waitForExistence(timeout: 2))
        app.buttons["hint_next"].tap()
        let lesson = app.buttons["hint_lesson"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 2))
        lesson.tap()
        XCTAssertTrue(element("lessonBoard", in: app).waitForExistence(timeout: 5), "the lesson is pushed")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 3))
        app.buttons["hint_close"].tap()
        XCTAssertEqual(boardLabels(in: app), board, "the same game")
        let timer = element("timerLabel", in: app)
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        let before = timer.label
        let ticked = NSPredicate(format: "label != %@", before)
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: ticked, object: timer)], timeout: 4), .completed,
                       "the timer runs again")
    }

    /// The Assists settings live in Journal; Show timer off hides the game timer (CODESPEC 3.3).
    func testJournalShowTimerHidesTheTimer() {
        let app = launchApp()
        app.buttons["tab_journal"].tap()
        let timer = app.buttons["journal_showTimer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        for _ in 0..<4 where !timer.isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["journal_mistakes_never"].exists)
        XCTAssertTrue(app.buttons["journal_notation_grid"].exists)
        let wasOn = timer.value as? String == "On"
        if !wasOn { timer.tap() }
        XCTAssertTrue(gameShowsTimer(in: app), "Show timer on: the game shows it")
        app.buttons["tab_journal"].tap()
        for _ in 0..<4 where !timer.isHittable { app.swipeUp() }
        timer.tap()
        XCTAssertEqual(timer.value as? String, "Off")
        XCTAssertFalse(gameShowsTimer(in: app), "Show timer off: no timer")
        if wasOn {
            app.buttons["tab_journal"].tap()
            for _ in 0..<4 where !timer.isHittable { app.swipeUp() }
            timer.tap() // leave the app as found
        }
    }
}
