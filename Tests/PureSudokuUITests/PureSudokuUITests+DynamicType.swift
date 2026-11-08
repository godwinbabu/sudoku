import XCTest

/// Dynamic Type at accessibility size AX-XL (CODESPEC 9). Screenshots are kept for review.
extension PureSudokuUITests {
    private static let largeText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]

    /// At accessibility text size AX-XL the chrome scales, and the board, tools and keypad still fit
    /// one screen (CODESPEC 9).
    func testAccessibilityTextSizeKeepsTheGameOnOneScreen() {
        let app = launchApp(Self.largeText)
        XCTAssertTrue(element("homeView", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["difficulty_easy"].isHittable)
        XCTAssertTrue(app.buttons["tab_journal"].isHittable)
        attachScreenshot(app, "home")

        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        let controls = (1...9).map { "number_\($0)" } + ["tool_undo", "tool_erase", "tool_notes", "tool_hint", "backButton", "nightButton"]
        for id in controls { XCTAssertTrue(app.buttons[id].isHittable, id) }
        XCTAssertTrue(app.buttons["cell_0_0"].isHittable)
        XCTAssertTrue(app.buttons["cell_8_8"].isHittable)
        attachScreenshot(app, "game")
        app.buttons["tool_hint"].tap()
        XCTAssertTrue(element("hintPanel", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["hint_close"].isHittable)
        attachScreenshot(app, "game-hint")
        app.buttons["hint_close"].tap()

        app.buttons["nightButton"].tap()
        let sheet = element("nightSheet", in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["night_close"].isHittable)
        attachScreenshot(app, "night-sheet")
        app.buttons["night_close"].tap()
        XCTAssertTrue(waitForAbsence(sheet))
        app.buttons["moreButton"].tap()
        XCTAssertTrue(waitUntilHittable(app.buttons["menu_restart"]))
        attachScreenshot(app, "game-menu")
        app.buttons["menu_restart"].tap()
        XCTAssertTrue(waitUntilHittable(app.buttons["confirm_cancel"]))
        attachScreenshot(app, "game-confirm")
        app.buttons["confirm_cancel"].tap()
        app.buttons["backButton"].tap()

        app.buttons["tab_journal"].tap()
        XCTAssertTrue(element("journalView", in: app).waitForExistence(timeout: 2))
        let row = element("journal_row_easy", in: app)
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.isHittable)
        attachScreenshot(app, "journal")
        let display = element("settings_display", in: app)
        for _ in 0..<8 where !display.isHittable { app.swipeUp() }
        display.tap()
        XCTAssertTrue(element("displaySettings", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["display_back"].isHittable)
        attachScreenshot(app, "display-night")
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(app, "display-night-lower")
        app.swipeDown()
        app.swipeDown()
        app.swipeDown()
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "dynamic-type-ax-xl-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// At AX-XL: Import, Learn, a lesson, the Solved panel after a practice solve, and the first-night flow (CODESPEC 9).
    func testAccessibilityTextSizeLessonSolvedAndFirstNight() {
        var app = launchApp(Self.largeText + ["-uiTestNearlySolved"])
        let importButton = app.buttons["importPuzzleButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 2))
        for _ in 0..<6 where !importButton.isHittable { app.swipeUp() }
        importButton.tap()
        XCTAssertTrue(element("importSource", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["importTypeItIn"].isHittable)
        attachScreenshot(app, "import")
        app.buttons["importDiscard"].tap()

        app.buttons["tab_learn"].tap()
        XCTAssertTrue(element("learnView", in: app).waitForExistence(timeout: 2))
        attachScreenshot(app, "learn")
        openPointingLesson(in: app)
        XCTAssertTrue(app.buttons["lesson_next"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["lesson_next"].isHittable)
        attachScreenshot(app, "lesson")
        stepToPractise(in: app)
        app.buttons["lesson_practise"].tap()
        firstEmptyCell(in: app).tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'number_' AND isEnabled == true")).firstMatch.tap()
        XCTAssertTrue(app.buttons["solved_goodnight"].waitForExistence(timeout: 3))
        attachScreenshot(app, "solved")
        app.buttons["solved_goodnight"].tap()
        XCTAssertTrue(element("goodnightView", in: app).waitForExistence(timeout: 2), "Goodnight can be tapped")
        app.terminate()

        app = launchApp(Self.largeText + ["-uiTestFirstNight"], skipFirstNight: false)
        app.buttons["tab_journal"].tap()
        let display = element("settings_display", in: app)
        for _ in 0..<8 where !display.isHittable { app.swipeUp() }
        display.tap()
        let night = app.buttons["display_appearance_night"]
        XCTAssertTrue(night.waitForExistence(timeout: 2))
        night.tap()
        XCTAssertTrue(element("firstNight", in: app).waitForExistence(timeout: 3))
        attachScreenshot(app, "first-night")
        let calibrate = app.buttons["firstNight_calibrate"]
        for _ in 0..<4 where !calibrate.isHittable { app.swipeUp() }
        calibrate.tap()
        XCTAssertTrue(app.buttons["calibrate_14"].waitForExistence(timeout: 2))
        attachScreenshot(app, "first-night-calibrate")
        app.buttons["calibrate_14"].tap()
        let use = app.buttons["calibrate_use"]
        for _ in 0..<4 where !use.isHittable { app.swipeUp() }
        use.tap()
        let start = app.buttons["firstNight_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 2))
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(waitForAbsence(element("firstNight", in: app)))
        let day = app.buttons["display_appearance_day"]
        for _ in 0..<6 where !day.isHittable { app.swipeDown() }
        day.tap() // leave the app in Day
    }
}
