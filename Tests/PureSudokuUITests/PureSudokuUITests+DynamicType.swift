import XCTest

/// Dynamic Type at accessibility sizes AX-XL and AX5 (CODESPEC 9). Screenshots are kept for review.
extension PureSudokuUITests {
    private static let largeText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    /// At the largest text size (AX5) the segmented options, preset chips and confirmation buttons
    /// stack or scroll, so each one can still be reached (CODESPEC 9).
    func testLargestTextSizeKeepsOptionsAndConfirmationsReachable() {
        let app = launchApp(Self.largestText)
        startLevel("easy", in: app)
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        firstEmptyCell(in: app).tap()
        app.buttons["number_1"].tap()

        app.buttons["nightButton"].tap()
        let sheet = element("nightSheet", in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        attachScreenshot(app, "night-sheet", size: "ax5")
        let sheetOptions = ["day", "night", "afterDark"].map { "night_appearance_\($0)" }
            + ["standard", "large", "bold"].map { "night_clarity_\($0)" }
        for id in sheetOptions { assertReachable(app.buttons[id], id, in: app) }
        app.buttons["night_close"].tap()
        XCTAssertTrue(waitForAbsence(sheet, timeout: 6))
        app.buttons["backButton"].tap()

        app.buttons["difficulty_easy"].tap()
        XCTAssertTrue(element("confirmDialog", in: app).waitForExistence(timeout: 2), "asks before replacing")
        attachScreenshot(app, "replace-confirm", size: "ax5")
        // XCUITest never reports Home's dialog buttons as hittable, at any text size, so check that
        // each sits fully on screen above the tab bar, then tap one.
        let dialog = element("confirmDialog", in: app)
        let tabTop = app.buttons["tab_play"].frame.minY
        for id in ["confirm_action", "confirm_continue"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.exists, id)
            // On a small phone the panel scrolls; drag inside it, slowly, until the button is on screen.
            for _ in 0..<6 where !(button.frame.minY >= 0 && button.frame.maxY <= tabTop) {
                let up = button.frame.maxY > tabTop
                let from = dialog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.75 : 0.25))
                from.press(forDuration: 0.05, thenDragTo: dialog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.25 : 0.75)))
            }
            XCTAssertTrue(button.frame.minY >= 0 && button.frame.maxY <= tabTop, "\(id) at \(button.frame)")
        }
        app.buttons["confirm_continue"].tap()
        XCTAssertTrue(element("gameView", in: app).waitForExistence(timeout: 5))
        app.buttons["backButton"].tap()

        app.buttons["tab_journal"].tap()
        let display = element("settings_display", in: app)
        for _ in 0..<10 where !display.isHittable { app.swipeUp() }
        display.tap()
        XCTAssertTrue(element("displaySettings", in: app).waitForExistence(timeout: 2))
        attachScreenshot(app, "display-night", size: "ax5")
        let displayOptions = ["day", "night", "afterDark"].map { "display_appearance_\($0)" }
            + ["readingLamp", "lightsOut", "redLight"].map { "display_preset_\($0)" }
            + ["standard", "large", "bold"].map { "display_clarity_\($0)" }
        for id in displayOptions {
            assertReachable(app.buttons[id], id, in: app)
            if id == "display_preset_redLight" || id == "display_clarity_bold" {
                attachScreenshot(app, "display-night-" + id, size: "ax5")
            }
        }
    }

    /// Scrolls toward `button` until it can be tapped, then asserts it. The drag runs down the right
    /// edge, outside the sliders, which would take it, and without a fling that could pass the button.
    private func assertReachable(_ button: XCUIElement, _ id: String, in app: XCUIApplication) {
        XCTAssertTrue(button.waitForExistence(timeout: 2), id)
        for attempt in 0..<10 where !waitUntilHittable(button, timeout: 1) {
            let up = button.frame.midY > app.frame.midY
            // A drag that starts on a slider row can move nothing, so every other one starts higher.
            let shift = attempt.isMultiple(of: 2) ? 0 : 0.1
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: (up ? 0.7 : 0.35) - shift))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: (up ? 0.35 : 0.7) - shift))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(button.isHittable, id)
    }

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
        assertCoachAndCheckMessage(in: app)

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
        app.buttons["display_appearance_day"].tap() // Day shows the second, Night preview strip
        attachScreenshot(app, "display-day")
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(app, "display-night-lower")
        app.swipeDown()
        app.swipeDown()
        app.swipeDown()
    }

    /// From an open hint: the coach card, then the Check result in the hint slot.
    private func assertCoachAndCheckMessage(in app: XCUIApplication) {
        app.buttons["hint_coach"].tap()
        XCTAssertTrue(element("coachPanel", in: app).waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["coach_close"].isHittable)
        XCTAssertTrue(app.buttons["coach_reveal"].isHittable)
        attachScreenshot(app, "game-coach")
        app.buttons["coach_close"].tap()

        app.buttons["moreButton"].tap()
        XCTAssertTrue(waitUntilHittable(app.buttons["menu_check"]))
        app.buttons["menu_check"].tap()
        XCTAssertTrue(element("checkMessage", in: app).waitForExistence(timeout: 2))
        attachScreenshot(app, "game-check")
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String, size: String = "ax-xl") {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "dynamic-type-\(size)-" + name
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
