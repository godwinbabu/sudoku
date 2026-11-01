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
                    let palette = SleepPalette(profile: profile)
                    let levels = palette.levels
                    XCTAssertGreaterThanOrEqual(levels.digit, SleepPalette.minimumDigit - 1e-9)
                    XCTAssertGreaterThanOrEqual(levels.candidate, levels.digit * SleepPalette.candidateShare - 1e-9)
                    XCTAssertGreaterThanOrEqual(levels.gridLine, levels.digit * SleepPalette.gridLineShare - 1e-9)
                    // The rendered color really has the intended luminance (within rounding).
                    XCTAssertEqual(palette.color(luminance: levels.digit).luminance, levels.digit, accuracy: levels.digit * 0.02 + 1e-4)
                }
            }
        }
    }

    func testIncreaseContrastMeetsWCAGOnBlack() {
        for dimness in steps {
            let palette = SleepPalette(profile: DisplayProfile(name: "p", dimness: dimness, contrast: 0), increaseContrast: true)
            XCTAssertGreaterThanOrEqual(SleepPalette.contrastOnBlack(palette.levels.digit), 4.5 - 1e-9)
            XCTAssertGreaterThanOrEqual(SleepPalette.contrastOnBlack(palette.levels.candidate), 3 - 1e-9)
            XCTAssertGreaterThanOrEqual(SleepPalette.contrastOnBlack(palette.levels.gridLine), 3 - 1e-9)
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
        XCTAssertEqual(colors.dimOverlayOpacity, 0)
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
