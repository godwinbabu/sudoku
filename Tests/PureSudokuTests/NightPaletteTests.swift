import XCTest
import SwiftUI
@testable import PureSudoku

/// PureSudoku 2 colour model and Display & Night settings (CODESPEC 7.2, 12).
@MainActor
final class NightPaletteTests: XCTestCase {
    // MARK: Palette

    /// Snapshots from Design/v2/styles.css (.ps-night-lamp / -out / -red).
    private let snapshots: [(NightPreset, [String: [Int]])] = [
        (.readingLamp, ["surface": [11, 6, 2], "surface2": [17, 10, 3], "ink": [154, 88, 24],
                        "ink2": [108, 62, 17], "ink3": [77, 44, 12],
                        "accent": [147, 63, 0], "accentDim": [77, 33, 0],
                        "line": [26, 15, 4], "lineMajor": [65, 37, 10], "hair": [23, 13, 4],
                        "sel": [31, 13, 0], "peer": [8, 5, 1], "same": [18, 8, 0], "err": [146, 40, 37], "status": [68, 39, 10]]),
        (.lightsOut, ["surface": [6, 2, 0], "surface2": [9, 4, 0], "ink": [79, 34, 0], "ink2": [56, 24, 0], "ink3": [40, 17, 0],
                      "accent": [76, 27, 0], "accentDim": [40, 14, 0], "line": [13, 6, 0], "lineMajor": [33, 14, 0], "hair": [12, 5, 0],
                      "sel": [16, 6, 0], "peer": [4, 2, 0], "same": [10, 3, 0], "err": [75, 21, 19], "status": [35, 15, 0]]),
        (.redLight, ["surface": [5, 2, 0], "surface2": [7, 2, 0], "ink": [65, 22, 0], "ink2": [46, 15, 0], "ink3": [33, 11, 0],
                     "accent": [63, 21, 0], "accentDim": [33, 11, 0], "line": [11, 4, 0], "lineMajor": [27, 9, 0], "hair": [10, 3, 0],
                     "sel": [13, 4, 0], "peer": [4, 1, 0], "same": [8, 3, 0], "err": [62, 17, 16], "status": [29, 10, 0]])
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
            XCTAssertEqual(settings.glow, NightPreset.lightsOut.glow)
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
        XCTAssertEqual(try decodeV1(["theme": "dark", "sleepBrightness": "dim"]).glow, 30)
    }

    func testV1DisplayProfileCarriesBrightnessAndWarmth() throws {
        let id = UUID()
        let profile: [String: Any] = ["id": id.uuidString, "name": "Mine", "dimness": 0.5, "contrast": 0.5, "warmth": 0.8,
                                      "textSize": 0.5, "lowersScreenBrightness": false]
        let other: [String: Any] = ["id": UUID().uuidString, "name": "Other", "dimness": 0.1, "contrast": 0.5, "warmth": 0.1,
                                    "textSize": 0.5, "lowersScreenBrightness": false]
        let settings = try decodeV1(["theme": "dark", "displayProfiles": [other, profile], "activeDisplayProfileID": id.uuidString])
        XCTAssertEqual(settings.glow, 30)
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
        XCTAssertEqual([settings.glow, settings.warmth], [48, 30])

        json["bedtimeMode"] = true
        settings = try decodeV1(json)
        XCTAssertEqual([settings.glow, settings.warmth], [6, 100])
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
        settings.glowFloor = 14
        settings.apply(.redLight)
        XCTAssertEqual(settings.glow, 14)
        XCTAssertEqual(settings.warmth, 100)
    }

    // MARK: Brightness

    func testScreenStaysLowWhenControlCenterOpens() {
        XCTAssertTrue(ScreenBrightnessController.shouldLower(phase: .active, isNight: true))
        XCTAssertTrue(ScreenBrightnessController.shouldLower(phase: .inactive, isNight: true), "no flash on Control Center")
        XCTAssertFalse(ScreenBrightnessController.shouldLower(phase: .background, isNight: true))
        XCTAssertFalse(ScreenBrightnessController.shouldLower(phase: .active, isNight: false), "only at night")
    }

    func testScreenBrightnessIsRestored() {
        var screen: CGFloat = 0.7
        let controller = ScreenBrightnessController(read: { screen }, write: { screen = $0 })
        controller.update(lower: true)
        XCTAssertEqual(screen, 0)
        controller.update(lower: true)
        controller.update(lower: false)
        XCTAssertEqual(screen, 0.7, "the player's own brightness comes back")
        controller.update(lower: false)
        XCTAssertEqual(screen, 0.7)
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
