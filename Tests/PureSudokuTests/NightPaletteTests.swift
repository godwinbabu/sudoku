import XCTest
import SwiftUI
@testable import PureSudoku

/// PureSudoku 2 colour model and Display & Night settings (CODESPEC 7.2, 12).
@MainActor
final class NightPaletteTests: XCTestCase {
    // MARK: Palette

    /// Preset snapshots on glow scale 2 (CODESPEC 7.2, 12.3). They replace the styles.css snapshots,
    /// which were too dark to read.
    private let snapshots: [(NightPreset, [String: [Int]])] = [
        (.readingLamp, ["surface": [18, 10, 3], "surface2": [28, 16, 4], "ink": [255, 146, 39], "ink2": [199, 114, 31],
                        "ink3": [158, 91, 24], "accent": [245, 104, 0], "accentDim": [166, 70, 0], "line": [56, 32, 9],
                        "lineMajor": [153, 88, 23], "hair": [64, 37, 10], "sel": [51, 22, 0], "peer": [14, 8, 2],
                        "same": [31, 13, 0], "err": [242, 66, 61], "status": [112, 64, 17]]),
        (.lightsOut, ["surface": [18, 8, 0], "surface2": [28, 13, 0], "ink": [255, 121, 0], "ink2": [199, 94, 0],
                      "ink3": [158, 75, 0], "accent": [245, 94, 0], "accentDim": [166, 64, 0], "line": [56, 27, 0],
                      "lineMajor": [153, 72, 0], "hair": [64, 30, 0], "sel": [51, 20, 0], "peer": [14, 7, 0],
                      "same": [31, 12, 0], "err": [242, 66, 61], "status": [112, 53, 0]]),
        (.redLight, ["surface": [15, 5, 0], "surface2": [23, 8, 0], "ink": [208, 70, 0], "ink2": [163, 55, 0],
                     "ink3": [129, 44, 0], "accent": [200, 68, 0], "accentDim": [136, 46, 0], "line": [46, 15, 0],
                     "lineMajor": [125, 42, 0], "hair": [52, 18, 0], "sel": [42, 14, 0], "peer": [11, 4, 0],
                     "same": [25, 8, 0], "err": [198, 54, 50], "status": [92, 31, 0]])
    ]

    private func channels(_ color: Color) -> [Int] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b].map { Int(($0 * 255).rounded()) }
    }

    func testPresetPalettesMatchTheDesignSnapshots() {
        for (preset, expected) in snapshots {
            let palette = PSPalette.night(glow: preset.glow, warmth: preset.warmth, clarity: .standard)
            let drawn: [String: Color] = [
                "surface": palette.surface, "surface2": palette.surface2,
                "ink": palette.ink, "ink2": palette.ink2, "ink3": palette.ink3,
                "accent": palette.accent, "accentDim": palette.accentDim, "line": palette.line, "lineMajor": palette.lineMajor,
                "hair": palette.hair, "sel": palette.sel, "peer": palette.peer,
                "same": palette.same, "err": palette.err, "status": palette.status
            ]
            for (token, rgb) in expected {
                let actual = channels(drawn[token]!)
                for i in 0..<3 {
                    XCTAssertEqual(actual[i], rgb[i], accuracy: 1, "\(preset.title) \(token): \(actual) vs \(rgb)")
                }
            }
            XCTAssertEqual(channels(palette.bg), [0, 0, 0], "the night canvas is pure black")
        }
    }

    func testKelvinForWarmth() {
        XCTAssertEqual(Blackbody.kelvin(forWarmth: 0), 6500)
        XCTAssertEqual(Blackbody.kelvin(forWarmth: 45), 2200)
        XCTAssertEqual(Blackbody.kelvin(forWarmth: 75), 1500)
        XCTAssertEqual(Blackbody.kelvin(forWarmth: 100), 1200)
    }

    func testClarityRaisesTheNightFloor() {
        let standard = PSPalette.night(glow: 0, warmth: 75, clarity: .standard)
        let bold = PSPalette.night(glow: 0, warmth: 75, clarity: .bold)
        XCTAssertEqual(standard.luminance, 0.20, accuracy: 0.001)
        XCTAssertEqual(bold.luminance, 0.38, accuracy: 0.001)
        XCTAssertEqual(PSType(.bold).boxLine, 3)
        XCTAssertEqual(PSType(.standard).minorLine, 1)
    }

    // MARK: Settings

    func testSettingsRoundTrip() throws {
        var settings = Settings()
        settings.appearance = .matchSystem
        settings.glow = 33
        settings.warmth = 90
        settings.clarity = .bold
        settings.glowFloor = 6
        settings.calibrated = true
        settings.drift = false
        settings.afterDarkStart = ClockTime(hour: 22, minute: 15)
        settings.mistakes = .never
        settings.tidyNotes = false
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
    }

    private func decodeV1(_ json: [String: Any]) throws -> Settings {
        var base: [String: Any] = ["theme": "system", "showTimer": true, "autoRemoveCandidates": true, "autoCheckMistakes": true,
                                   "bedtimeMode": false, "soundsEnabled": false, "hapticsEnabled": false]
        base.merge(json) { $1 }
        return try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: base))
    }

    func testBedtimeMapsToNightWithLightsOut() throws {
        for v1 in [["bedtimeMode": true], ["theme": "sleep"]] as [[String: Any]] {
            let settings = try decodeV1(v1.merging(["sleepBrightness": "normal"]) { $1 })
            XCTAssertEqual(settings.appearance, .night)
            XCTAssertEqual(settings.glow, NightPreset.lightsOut.glow, "v1 brightness was glow scale 1, so glow restarts")
            XCTAssertEqual(settings.warmth, NightPreset.lightsOut.warmth)
        }
    }

    func testV1ThemeAndAssistsMigrate() throws {
        let light = try decodeV1(["theme": "light", "autoCheckMistakes": false, "autoRemoveCandidates": false,
                                  "hasCalibratedDisplay": true])
        XCTAssertEqual(light.appearance, .day)
        XCTAssertEqual(light.mistakes, .onCheck)
        XCTAssertFalse(light.tidyNotes)
        XCTAssertTrue(light.calibrated)
        XCTAssertEqual(try decodeV1(["theme": "dark"]).appearance, .night)
        XCTAssertEqual(try decodeV1(["theme": "system"]).appearance, .matchSystem)
        XCTAssertEqual(try decodeV1(["theme": "dark", "sleepBrightness": "dim"]).glow, NightPreset.lightsOut.glow)
    }

    func testV1DisplayProfileCarriesBrightnessAndWarmth() throws {
        let id = UUID()
        let profile: [String: Any] = ["id": id.uuidString, "name": "Mine", "dimness": 0.5, "contrast": 0.5, "warmth": 0.8,
                                      "textSize": 0.5, "lowersScreenBrightness": false]
        let other: [String: Any] = ["id": UUID().uuidString, "name": "Other", "dimness": 0.1, "contrast": 0.5, "warmth": 0.1,
                                    "textSize": 0.5, "lowersScreenBrightness": false]
        let settings = try decodeV1(["theme": "dark", "displayProfiles": [other, profile], "activeDisplayProfileID": id.uuidString])
        XCTAssertEqual(settings.glow, NightPreset.lightsOut.glow)
        XCTAssertEqual(settings.warmth, 80)
    }

    /// A Sleep player who calibrated keeps their own profile; one who never did gets Lights out.
    func testV1SleepKeepsACalibratedProfile() throws {
        let active = UUID(), bedtime = UUID()
        func profile(_ id: UUID, _ dimness: Double, _ warmth: Double) -> [String: Any] {
            ["id": id.uuidString, "name": "P", "dimness": dimness, "contrast": 0.5, "warmth": warmth,
             "textSize": 0.5, "lowersScreenBrightness": false]
        }
        var json: [String: Any] = ["theme": "sleep", "displayProfiles": [profile(active, 0.2, 0.3), profile(bedtime, 0.9, 1.0)],
                                   "activeDisplayProfileID": active.uuidString, "bedtimeDisplayProfileID": bedtime.uuidString]
        var settings = try decodeV1(json)
        XCTAssertEqual([settings.glow, settings.warmth], [NightPreset.lightsOut.glow, NightPreset.lightsOut.warmth])

        json["hasCalibratedDisplay"] = true
        settings = try decodeV1(json)
        XCTAssertEqual(settings.appearance, .night)
        XCTAssertEqual([settings.glow, settings.warmth], [NightPreset.lightsOut.glow, 30])

        json["bedtimeMode"] = true
        settings = try decodeV1(json)
        XCTAssertEqual([settings.glow, settings.warmth], [NightPreset.lightsOut.glow, 100])
    }

    func testAfterDarkFallbackHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: hour, minute: minute))!
        }
        var settings = Settings(appearance: .afterDark)
        settings.useLocationForAfterDark = false
        XCTAssertTrue(settings.isNight(now: at(21, 0), systemIsDark: false, calendar: calendar))
        XCTAssertTrue(settings.isNight(now: at(6, 29), systemIsDark: false, calendar: calendar))
        XCTAssertFalse(settings.isNight(now: at(6, 30), systemIsDark: false, calendar: calendar))
        XCTAssertFalse(settings.isNight(now: at(12, 0), systemIsDark: true, calendar: calendar))
        settings.appearance = .matchSystem
        XCTAssertTrue(settings.isNight(now: at(12, 0), systemIsDark: true, calendar: calendar))
    }

    func testPresetNeverGoesBelowTheFloor() {
        var settings = Settings()
        settings.glowFloor = 32
        settings.apply(.redLight)
        XCTAssertEqual(settings.glow, 32)
        XCTAssertEqual(settings.warmth, 100)
    }

    // MARK: Brightness

    func testGlowDrivesThePaletteThenTheBacklight() {
        XCTAssertEqual(PSPalette.night(glow: 0, warmth: 65, clarity: .standard).luminance, 0.20, accuracy: 0.001)
        XCTAssertEqual(PSPalette.night(glow: 40, warmth: 65, clarity: .standard).luminance, 1, accuracy: 0.001)
        XCTAssertEqual(PSPalette.night(glow: 80, warmth: 65, clarity: .standard).luminance, 1, accuracy: 0.001)
        XCTAssertEqual(PSPalette.backlight(glow: 0), 0)
        XCTAssertEqual(PSPalette.backlight(glow: 40), 0)
        XCTAssertEqual(PSPalette.backlight(glow: 70), 0.3, accuracy: 0.001)
        XCTAssertEqual(PSPalette.backlight(glow: 100), 0.6, accuracy: 0.001)
    }

    func testDefaultNightIsReadable() {
        // WCAG contrast of ink on black at the default (Lights out) must clear 4.5:1.
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let ink = PSPalette.night(glow: Settings().glow, warmth: Settings().warmth, clarity: .standard).ink
        UIColor(ink).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        let contrast = (0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b) + 0.05) / 0.05
        XCTAssertGreaterThan(contrast, 4.5)
    }

    func testGlowScale1SettingsRestartAtLightsOut() throws {
        let old = try JSONSerialization.data(withJSONObject: ["appearance": "night", "glow": 18, "glowFloor": 24, "calibrated": true])
        let settings = try JSONDecoder().decode(Settings.self, from: old)
        XCTAssertEqual(settings.glowFloor, Settings.glowOnScale2(fromScale1: 24))
        XCTAssertEqual(settings.glowFloor, 6, "the same palette strength on the new scale")
        XCTAssertEqual(settings.glow, NightPreset.lightsOut.glow)
        let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(again, settings, "scale-2 files are not migrated twice")
    }

    func testScreenBrightnessIsRestored() {
        var screen: CGFloat = 0.7
        let controller = ScreenBrightnessController(read: { screen }, write: { screen = $0 })
        controller.update(target: 0)
        XCTAssertEqual(screen, 0)
        controller.update(target: 0.3)
        XCTAssertEqual(screen, 0.3, "glow above 40 raises the backlight")
        controller.update(target: nil)
        XCTAssertEqual(screen, 0.7, "the player's own brightness comes back")
        controller.update(target: nil)
        XCTAssertEqual(screen, 0.7)
    }

    // MARK: Copy (issues 47, 48)

    /// The first-night welcome greets by the hour, not always "Good evening.".
    func testFirstNightGreetingFollowsTheHour() {
        XCTAssertEqual(FirstNightView.greeting(hour: 9), "Good morning.")
        XCTAssertEqual(FirstNightView.greeting(hour: 5), "Good morning.")
        XCTAssertEqual(FirstNightView.greeting(hour: 12), "Good afternoon.")
        XCTAssertEqual(FirstNightView.greeting(hour: 17), "Good afternoon.")
        XCTAssertEqual(FirstNightView.greeting(hour: 18), "Good evening.")
        XCTAssertEqual(FirstNightView.greeting(hour: 2), "Good evening.")
    }

    /// Above 95% the Warmth note stops quoting a number; Red light is above it.
    func testWarmthNoteAboveNinetyFivePercent() {
        XCTAssertEqual(NightSheetView.warmthNote(95), "Blue light about 95% lower than daylight white.")
        XCTAssertEqual(NightSheetView.warmthNote(96), "Almost no blue light.")
        let red = PSPalette.night(glow: NightPreset.redLight.glow, warmth: NightPreset.redLight.warmth, clarity: .standard)
        XCTAssertEqual(NightSheetView.warmthNote(red.blueReduction), "Almost no blue light.")
    }

    /// At night givens are one weight heavier, so entered digits differ by shape as well as hue.
    func testNightGivensAreHeavier() {
        XCTAssertEqual(PSType(.standard).givenWeight(night: false), .semibold)
        XCTAssertEqual(PSType(.standard).givenWeight(night: true), .bold)
        XCTAssertEqual(PSType(.large).givenWeight(night: true), .heavy)
        XCTAssertEqual(PSType(.bold).givenWeight(night: true), .black)
    }

    func testPlayersOwnBrightnessWinsUntilGlowChanges() {
        var screen: CGFloat = 0.7
        let controller = ScreenBrightnessController(read: { screen }, write: { screen = $0 })
        controller.update(target: 0.1, request: 50)
        screen = 0.4 // the player raises brightness in Control Center
        controller.update(target: 0.1, request: 50) // the app comes back to the foreground
        XCTAssertEqual(screen, 0.4)
        controller.update(target: 0.08, request: 50) // a Drift step
        XCTAssertEqual(screen, 0.4, "Drift doesn't undo the player's choice")
        controller.update(target: 0.2, request: 60) // the player moves Glow
        XCTAssertEqual(screen, 0.2)
        controller.update(target: nil)
        XCTAssertEqual(screen, 0.7)
    }

    /// Glow 30 → 10 is a Glow change even though both targets are the minimum.
    func testGlowChangesBelow40ClearTheOverride() {
        var screen: CGFloat = 0.7
        let controller = ScreenBrightnessController(read: { screen }, write: { screen = $0 })
        controller.update(target: 0, request: 30)
        screen = 0.4
        controller.update(target: 0, request: 30)
        XCTAssertEqual(screen, 0.4)
        controller.update(target: 0, request: 10)
        XCTAssertEqual(screen, 0)
    }

    func testBacklightFollowsDriftAndCalibration() {
        let (controller, _) = makeTestController()
        controller.updateSettings { $0.glow = 70 }
        XCTAssertEqual(controller.nightBacklight, 0.3, accuracy: 0.001)
        controller.driftSteps = 20
        XCTAssertEqual(controller.nightBacklight, 0.1, accuracy: 0.001, "Drift dims the backlight above glow 40")
    }

    func testCalibrationHoldsTheMinimumByDayAndNight() {
        let target = ScreenBrightnessController.target
        XCTAssertEqual(target(.active, false, true, 0.3), 0, "Day: Check again still judges at the minimum")
        XCTAssertEqual(target(.active, true, true, 0.3), 0)
        XCTAssertEqual(target(.active, true, false, 0.3), 0.3)
        XCTAssertNil(target(.active, false, false, 0.3), "Day leaves the screen to the player")
        XCTAssertEqual(target(.inactive, true, false, 0.3), 0.3, "Control Center keeps it")
        XCTAssertNil(target(.background, true, true, 0.3))
    }
}

/// Chrome text scales with Dynamic Type and keeps the design's size at the default (CODESPEC 9).
final class PSFontTests: XCTestCase {
    func testScaledSizeKeepsTheDesignSizeAtLarge() {
        for size: CGFloat in [11, 13, 15, 17, 24, 30, 56] {
            XCTAssertEqual(PSFont.scaledSize(size, at: .large), size, accuracy: 0.01, "\(size)")
        }
    }

    func testScaledSizeGrowsAtAccessibilitySizes() {
        for size: CGFloat in [11, 15, 30] {
            let xxxLarge = PSFont.scaledSize(size, at: .xxxLarge)
            let accessibility3 = PSFont.scaledSize(size, at: .accessibility3)
            XCTAssertGreaterThan(xxxLarge, size, "\(size)")
            XCTAssertGreaterThan(accessibility3, xxxLarge, "\(size)")
        }
    }
}
