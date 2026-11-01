import XCTest
@testable import PureSudoku

/// Display calibration (CODESPEC 12.3) and Sleep palette floors (CODESPEC 9).
@MainActor
final class DisplayCalibrationTests: XCTestCase {
    private let steps = stride(from: 0.0, through: 1.0, by: 0.1).map { $0 }

    func testFloorsHoldForEveryProfileSetting() {
        for dimness in steps {
            for contrast in steps {
                for warmth in [0.0, 0.5, 1.0] {
                    let profile = DisplayProfile(name: "p", dimness: dimness, contrast: contrast, warmth: warmth)
                    // Check the colors the theme actually draws, not the targets.
                    let drawn = SleepPalette(profile: profile).rendered
                    let digit = drawn.digit.luminance
                    XCTAssertGreaterThanOrEqual(digit, SleepPalette.minimumDigit * 0.98)
                    XCTAssertGreaterThanOrEqual(drawn.candidate.luminance, digit * SleepPalette.candidateShare * 0.98)
                    XCTAssertGreaterThanOrEqual(drawn.gridLine.luminance, digit * SleepPalette.gridLineShare * 0.98)
                }
            }
        }
    }

    func testIncreaseContrastMeetsWCAGOnBlack() {
        for dimness in steps {
            let drawn = SleepPalette(profile: DisplayProfile(name: "p", dimness: dimness, contrast: 0, warmth: 1), increaseContrast: true).rendered
            XCTAssertGreaterThanOrEqual(SleepPalette.contrastOnBlack(drawn.digit.luminance), 4.45)
            XCTAssertGreaterThanOrEqual(SleepPalette.contrastOnBlack(drawn.candidate.luminance), 2.97)
            XCTAssertGreaterThanOrEqual(SleepPalette.contrastOnBlack(drawn.gridLine.luminance), 2.97)
        }
    }

    /// A switch knob must stand out from the accent "on" track and the near-black "off" track.
    func testSwitchKnobStaysVisibleAgainstItsTrack() {
        for dimness in steps {
          for warmth in steps {
            let drawn = SleepPalette(profile: DisplayProfile(name: "p", dimness: dimness, warmth: warmth)).rendered
            let knob = drawn.knob.luminance
            let track = drawn.accent.luminance
            XCTAssertGreaterThanOrEqual((max(knob, track) + 0.05) / (min(knob, track) + 0.05), 1.6, "dimness \(dimness)")
            XCTAssertGreaterThanOrEqual((knob + 0.05) / (0.03 + 0.05), 1.8, "against the off track")
            XCTAssertLessThanOrEqual(knob, max(drawn.digit.luminance * 3, 0.1) + 1e-6, "not the brightest thing on screen")
          }
        }
    }

    func testDimmerProfileIsDimmerAndWarmthNeverGoesDeepRed() {
        let bright = SleepPalette(profile: DisplayProfile(name: "a", dimness: 0)).levels.digit
        let dim = SleepPalette(profile: DisplayProfile(name: "b", dimness: 1)).levels.digit
        XCTAssertGreaterThan(bright, dim * 10)
        let hottest = SleepPalette.hue(warmth: 1)
        XCTAssertGreaterThan(hottest.g, 0.4, "keep some green so the warmest palette is orange, not deep red")
    }

    func testOldDimStepsMigrateToAProfile() throws {
        for (step, dimness) in [(SleepBrightness.normal, 0.2), (.dim, 0.5), (.extraDim, 0.75)] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any])
            for key in ["displayProfiles", "activeDisplayProfileID", "bedtimeDisplayProfileID", "hasCalibratedDisplay"] { json.removeValue(forKey: key) }
            json["sleepBrightness"] = step.rawValue
            let settings = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(settings.displayProfiles.count, 1)
            XCTAssertEqual(settings.currentDisplayProfile.dimness, dimness)
            XCTAssertFalse(settings.hasCalibratedDisplay)
        }
    }

    func testProfilesRoundTripAndRespectTheLimit() throws {
        var settings = Settings()
        let night = DisplayProfile(name: "Night", dimness: 1, warmth: 1, lowersScreenBrightness: true)
        XCTAssertTrue(settings.saveDisplayProfile(night))
        XCTAssertTrue(settings.saveDisplayProfile(DisplayProfile(name: "Third")))
        XCTAssertFalse(settings.saveDisplayProfile(DisplayProfile(name: "Fourth")), "at most \(DisplayProfile.maxProfiles)")
        settings.bedtimeDisplayProfileID = night.id
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)

        settings.deleteDisplayProfile(id: night.id)
        XCTAssertNil(settings.bedtimeDisplayProfileID)
        XCTAssertFalse(settings.displayProfiles.contains { $0.id == night.id })
        while settings.displayProfiles.count > 1 { settings.deleteDisplayProfile(id: settings.displayProfiles[0].id) }
        settings.deleteDisplayProfile(id: settings.displayProfiles[0].id)
        XCTAssertEqual(settings.displayProfiles.count, 1, "the last profile cannot be deleted")
    }

    func testSleepThemeUsesTheComputedPaletteWithoutOverlay() {
        var settings = Settings()
        settings.toggleBedtimeMode(true)
        let colors = settings.themeColors
        XCTAssertEqual(colors.theme, .sleep)
    }

    func testScreenStaysLowWhenControlCenterOpens() {
        var settings = Settings()
        settings.toggleBedtimeMode(true)
        var profile = settings.currentDisplayProfile
        profile.lowersScreenBrightness = true
        settings.saveDisplayProfile(profile)
        XCTAssertTrue(ScreenBrightnessController.shouldLower(phase: .active, settings: settings))
        XCTAssertTrue(ScreenBrightnessController.shouldLower(phase: .inactive, settings: settings), "no flash on Control Center")
        XCTAssertFalse(ScreenBrightnessController.shouldLower(phase: .background, settings: settings))
        settings.toggleBedtimeMode(false)
        XCTAssertFalse(ScreenBrightnessController.shouldLower(phase: .active, settings: settings), "only in the Sleep theme")
    }

    func testNewSettingsStayReadableByOlderBuilds() throws {
        var settings = Settings()
        settings.saveDisplayProfile(DisplayProfile(name: "Dim", dimness: 0.5))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        XCTAssertEqual(json["sleepBrightness"] as? String, SleepBrightness.dim.rawValue)
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
