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
        (.readingLamp, ["surface": [0, 0, 0], "surface2": [0, 0, 0], "ink": [255, 146, 39], "ink2": [217, 124, 33],
                        "ink3": [199, 114, 31], "accent": [245, 104, 0], "accentDim": [166, 70, 0], "line": [51, 29, 8],
                        "lineMajor": [153, 88, 23], "hair": [64, 37, 10], "sel": [84, 36, 0], "peer": [43, 18, 0],
                        "same": [64, 27, 0], "err": [242, 66, 61], "status": [112, 64, 17]]),
        (.lightsOut, ["surface": [0, 0, 0], "surface2": [0, 0, 0], "ink": [255, 132, 0], "ink2": [217, 112, 0],
                      "ink3": [199, 103, 0], "accent": [245, 97, 0], "accentDim": [166, 66, 0], "line": [51, 26, 0],
                      "lineMajor": [153, 79, 0], "hair": [64, 33, 0], "sel": [84, 33, 0], "peer": [43, 17, 0],
                      "same": [64, 25, 0], "err": [242, 66, 61], "status": [112, 58, 0]]),
        (.redLight, ["surface": [0, 0, 0], "surface2": [0, 0, 0], "ink": [208, 70, 0], "ink2": [177, 60, 0],
                     "ink3": [163, 55, 0], "accent": [200, 68, 0], "accentDim": [136, 46, 0], "line": [42, 14, 0],
                     "lineMajor": [125, 42, 0], "hair": [52, 18, 0], "sel": [69, 23, 0], "peer": [35, 12, 0],
                     "same": [52, 18, 0], "err": [198, 54, 50], "status": [92, 31, 0]])
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

    /// WCAG relative luminance of `color`, optionally drawn at `opacity` over `over`.
    private func luminance(_ color: Color, opacity: Double = 1, over: Color = .black) -> Double {
        let fg = channels(color), bg = channels(over)
        let mixed = (0..<3).map { (Double(fg[$0]) * opacity + Double(bg[$0]) * (1 - opacity)).rounded() / 255 }
        let linear = mixed.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    private func contrast(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    /// Highlights step plain < peer < same < sel, peer stays below the grid line, and no fill outshines
    /// the ink (issue #93).
    func testCellFillLadder() {
        for glow in [20.0, 45, 100] {
            for warmth in [0.0, 65, 100] {
                for clarity in Clarity.allCases {
                    let p = PSPalette.night(glow: glow, warmth: warmth, clarity: clarity)
                    let fills = [p.bg, p.peer, p.same, p.sel].map { luminance($0) }
                    let context = "glow \(glow) warmth \(warmth) \(clarity)"
                    XCTAssertEqual(fills, fills.sorted(), context)
                    XCTAssertEqual(Set(fills).count, 4, "each step is distinct: \(context)")
                    XCTAssertLessThan(luminance(p.peer), luminance(p.line), context)
                    XCTAssertLessThan(luminance(p.sel), luminance(p.ink), context)
                    // At full strength each step is big enough to see (CIE L*; it was 2.2 for peer before #93).
                    let lightness = fills.map { $0 > 0.008856 ? 116 * pow($0, 1.0 / 3) - 16 : 903.3 * $0 }
                    for i in 1..<4 where glow >= 40 {
                        XCTAssertGreaterThanOrEqual(lightness[i] - lightness[i - 1], 5, "step \(i), \(context)")
                    }
                }
            }
        }
    }

    /// At full palette strength every cell mark keeps 3:1 on every fill it can sit on, at any warmth.
    func testCellMarksKeepThreeToOneOnEveryFill() {
        for clarity in Clarity.allCases {
            for warmth in stride(from: 0.0, through: 100, by: 1) {
                assertCellMarks(PSPalette.night(glow: 45, warmth: warmth, clarity: clarity), "\(clarity) warmth \(warmth)")
            }
        }
    }

    private func assertCellMarks(_ p: PSPalette, _ context: String) {
        for (fillName, fill) in [("bg", p.bg), ("peer", p.peer), ("same", p.same), ("sel", p.sel)] {
            let back = luminance(fill)
            let marks: [(String, Double)] = [
                ("ink", luminance(p.ink)), ("accent", luminance(p.accent)), ("ink2", luminance(p.ink2)),
                ("err", luminance(p.err))
            ]
            for (name, mark) in marks {
                XCTAssertGreaterThanOrEqual(contrast(mark, back), 3, "\(name) on \(fillName), \(context)")
            }
        }
        // Ghost digits, struck notes and ruled-out rings (ink3) show only with a hint open, where there is
        // no selection.
        for fill in [p.bg, p.peer, p.same] {
            XCTAssertGreaterThanOrEqual(contrast(luminance(p.ink3), luminance(fill)), 3, "ink3, \(context)")
            let ghost = luminance(p.accent, opacity: 0.75, over: fill)
            XCTAssertGreaterThanOrEqual(contrast(ghost, luminance(fill)), 3, "ghost, \(context)")
        }
    }

    /// The same-digit ring is Night and Dark only, and the selection and hint rings take precedence (CODESPEC 7.3).
    func testSameDigitRingPrecedence() {
        var state = CellState()
        state.isSameDigit = true
        XCTAssertTrue(state.showsSameDigitRing(enabled: true))
        XCTAssertFalse(state.showsSameDigitRing(enabled: false), "Day is unchanged")
        for keyPath in [\CellState.isSelected, \CellState.isEvidence, \CellState.isTarget] {
            var ringed = state
            ringed[keyPath: keyPath] = true
            XCTAssertFalse(ringed.showsSameDigitRing(enabled: true), "\(keyPath)")
        }
        XCTAssertFalse(CellState().showsSameDigitRing(enabled: true))
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
        XCTAssertFalse(settings.isNight(now: at(12, 0), systemIsDark: true, calendar: calendar), "Match iPhone never means Night")
        XCTAssertEqual(settings.look(now: at(12, 0), systemIsDark: true, calendar: calendar), .dark)
        XCTAssertEqual(settings.look(now: at(23, 0), systemIsDark: false, calendar: calendar), .day)
        settings.appearance = .afterDark
        XCTAssertEqual(settings.look(now: at(23, 0), systemIsDark: false, calendar: calendar), .night)
        XCTAssertEqual(settings.look(now: at(12, 0), systemIsDark: true, calendar: calendar), .day, "After dark ignores iOS")
    }

    // MARK: Dark (CODESPEC 7.2)

    /// Every Dark variant: text 4.5:1 on the ground, cards and cell fills; marks and controls 3:1; a visible
    /// fill ladder with peer below the grid line.
    func testDarkPaletteContrast() {
        let variants = Clarity.allCases.map { PSPalette.dark(clarity: $0) } + [PSPalette.dark(clarity: .standard, increaseContrast: true)]
        for (n, p) in variants.enumerated() {
            let context = "variant \(n)"
            XCTAssertTrue(p.isDark)
            XCTAssertFalse(p.isNight)
            XCTAssertFalse(p.ringsSameDigit, "Dark shows the same digit by weight")
            for (textName, text) in [("ink", p.ink), ("ink2", p.ink2), ("ink3", p.ink3), ("accent", p.accent), ("err", p.err)] {
                for (ground, fill) in [("bg", p.bg), ("surface", p.surface), ("surface2", p.surface2)] {
                    XCTAssertGreaterThanOrEqual(contrast(luminance(text), luminance(fill)), 4.5, "\(textName) on \(ground), \(context)")
                }
            }
            for (fillName, fill) in [("bg", p.bg), ("peer", p.peer), ("same", p.same), ("sel", p.sel)] {
                for (name, text) in [("ink", p.ink), ("accent", p.accent), ("err", p.err)] {
                    XCTAssertGreaterThanOrEqual(contrast(luminance(text), luminance(fill)), 4.5, "\(name) on \(fillName), \(context)")
                }
                for (name, mark) in [("ink2", luminance(p.ink2)), ("ink3", luminance(p.ink3)),
                                     ("ghost", luminance(p.accent, opacity: 0.75, over: fill))] {
                    XCTAssertGreaterThanOrEqual(contrast(mark, luminance(fill)), 3, "\(name) on \(fillName), \(context)")
                }
            }
            // Primary button (bg text on an accent fill), toggle, board ground and mistake bar.
            XCTAssertGreaterThanOrEqual(contrast(luminance(p.bg), luminance(p.accent)), 4.5, context)
            XCTAssertGreaterThanOrEqual(contrast(luminance(p.accent), luminance(p.surface)), 3, context)
            for ground in [p.bg, p.surface] { // the off toggle's outline, on the page and on a card
                XCTAssertGreaterThanOrEqual(contrast(luminance(PSToggle.offRing(p)), luminance(ground)), 3, context)
            }
            XCTAssertGreaterThanOrEqual(contrast(luminance(p.lineMajor), luminance(p.bg)), 3, context)
            let fills = [p.bg, p.peer, p.same, p.sel].map { luminance($0) }
            let lightness = fills.map { $0 > 0.008856 ? 116 * pow($0, 1.0 / 3) - 16 : 903.3 * $0 }
            for i in 1..<4 { XCTAssertGreaterThanOrEqual(lightness[i] - lightness[i - 1], 5, "step \(i), \(context)") }
            XCTAssertLessThan(luminance(p.peer), luminance(p.line), context)
        }
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

    /// Settings still on the old Lights out default (45 / 65) move to the new one once; nothing else moves.
    func testOldLightsOutDefaultMovesOnce() throws {
        func decode(_ json: [String: Any]) throws -> Settings {
            try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: json))
        }
        let base: [String: Any] = ["appearance": "night", "glowScale": 2, "glowFloor": 8, "calibrated": true]
        let old = try decode(base.merging(["glow": 45, "warmth": 65]) { $1 })
        XCTAssertEqual([old.glow, old.warmth], [55, 55])
        XCTAssertEqual(old.glowFloor, 8)
        XCTAssertTrue(old.calibrated)
        let floorAbove = try decode(base.merging(["glow": 45, "warmth": 65, "glowFloor": 60]) { $1 })
        XCTAssertEqual(floorAbove.glow, 60, "never below the floor")

        let tuned = try decode(base.merging(["glow": 45, "warmth": 70]) { $1 })
        XCTAssertEqual([tuned.glow, tuned.warmth], [45, 70], "the player's own tuning stays")
        let chosenLater = try decode(base.merging(["glow": 45, "warmth": 65, "lightsOutRevision": 2]) { $1 })
        XCTAssertEqual([chosenLater.glow, chosenLater.warmth], [45, 65], "migrated files are not moved again")
        let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(again, old)

        // A glow-scale-1 file on the old Lights out gets both migrations: glow and warmth.
        let scale1 = try decode(["appearance": "night", "glow": 45, "warmth": 65, "calibrated": true])
        XCTAssertEqual([scale1.glow, scale1.warmth], [55, 55])
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
    /// Givens are 800 at every Clarity and in every theme; entries stay lighter, so the two differ by
    /// shape where Night's single hue can't tell them apart (HANDOFF 2).
    func testGivensAreHeavierThanEntries() {
        for clarity in Clarity.allCases {
            XCTAssertEqual(PSType(clarity).givenWeight, .heavy)
            XCTAssertEqual(PSType(clarity).userWeight, .medium)
        }
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

    /// Before the window scene connects there is no screen (#71): nothing is written or saved, so the
    /// player's real brightness is saved once the scene is active, and restored later.
    func testBrightnessWaitsForTheScreen() {
        var screen: CGFloat? // no scene yet
        var writes: [CGFloat] = []
        let controller = ScreenBrightnessController(read: { screen }, write: { writes.append($0); screen = $0 })
        controller.update(target: 0.1, request: 50) // cold launch into Night
        XCTAssertEqual(writes, [])
        screen = 0.7 // the scene connects
        controller.update(target: 0.1, request: 50) // the scene turns active
        XCTAssertEqual(screen, 0.1)
        controller.update(target: nil)
        XCTAssertEqual(screen, 0.7, "the real brightness, not a placeholder")
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

// MARK: v3 (HANDOFF 2, 4, 8)

extension NightPaletteTests {
    /// v3 contrast rules in every theme (HANDOFF 8): text tokens keep 4.5:1 on the background and on
    /// surfaces, and the box lines keep 3:1.
    func testEveryThemeKeepsTextContrast() {
        var themes: [(String, PSPalette)] = [("light", .day(clarity: .standard)), ("dark", .dark(clarity: .standard))]
        // Red light is dim deep red by choice (glow 30, 1200 K), so it is held to the cell-mark 3:1 rule only.
        for preset in NightPreset.allCases where preset != .redLight {
            themes.append((preset.title, .night(glow: preset.glow, warmth: preset.warmth, clarity: .standard)))
        }
        for (name, p) in themes {
            for (ground, fill) in [("bg", p.bg), ("surface", p.surface)] {
                for (token, text) in [("ink", p.ink), ("ink2", p.ink2), ("accent", p.accent), ("err", p.err)] {
                    XCTAssertGreaterThanOrEqual(contrast(luminance(text), luminance(fill)), 4.5, "\(name) \(token) on \(ground)")
                }
                XCTAssertGreaterThanOrEqual(contrast(luminance(p.lineMajor), luminance(fill)), 3, "\(name) lineMajor on \(ground)")
            }
            if !p.isNight {
                XCTAssertGreaterThanOrEqual(contrast(luminance(p.btnInk), luminance(p.btnBg)), 4.5, "\(name) primary button")
            }
        }
    }

    /// Night draws no lit fill behind text: surfaces, glass, fills and the primary button are black or clear.
    func testNightHasNoLitFills() {
        let p = PSPalette.night(glow: 100, warmth: 0, clarity: .standard)
        for (token, color) in [("surface", p.surface), ("surface2", p.surface2), ("glass", p.glass),
                               ("fill", p.fill), ("btnBg", p.btnBg), ("segment", p.segment), ("pill", p.pill)] {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            XCTAssertTrue(a == 0 || (r == 0 && g == 0 && b == 0), token)
        }
    }

    /// The bundled faces register under the PostScript names PSFont asks for (Info.plist UIAppFonts).
    func testBundledFontsLoad() {
        for weight in [Font.Weight.regular, .medium, .semibold, .bold] {
            for display in [true, false] {
                let name = PSFont.faceName(weight: weight, display: display)
                XCTAssertNotNil(UIFont(name: name, size: 12), name)
            }
        }
    }
}
