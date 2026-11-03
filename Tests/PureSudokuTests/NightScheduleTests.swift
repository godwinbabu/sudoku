import XCTest
@testable import PureSudoku

/// After dark, Drift and the first-night flow (CODESPEC 7.1, 12.3).
@MainActor
final class NightScheduleTests: XCTestCase {
    private let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
    private let newYork = Coordinate(latitude: 40.7128, longitude: -74.0060)

    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    /// "2024-06-21 04:43" in the calendar's time zone.
    private func date(_ calendar: Calendar, _ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    private func assertNear(_ actual: Date?, _ expected: Date, minutes: Double = 2, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else { return XCTFail("no time", file: file, line: line) }
        XCTAssertLessThanOrEqual(abs(actual.timeIntervalSince(expected)), minutes * 60, "\(actual) vs \(expected)", file: file, line: line)
    }

    // MARK: NOAA sunrise and sunset

    func testSunTimesMatchPublishedTimesWithinTwoMinutes() throws {
        // Published: London 21 June 2024, sunrise 04:43, sunset 21:21 (BST).
        let uk = calendar("Europe/London")
        let june = try XCTUnwrap(SolarCalculator.sunTimes(on: date(uk, "2024-06-21 12:00"), at: london, calendar: uk))
        assertNear(june.sunrise, date(uk, "2024-06-21 04:43"))
        assertNear(june.sunset, date(uk, "2024-06-21 21:21"))
        // New York 21 December 2024, sunrise 7:17 AM, sunset 4:32 PM (EST). West of Greenwich, so the
        // sunset falls on the next UTC day.
        let ny = calendar("America/New_York")
        let december = try XCTUnwrap(SolarCalculator.sunTimes(on: date(ny, "2024-12-21 12:00"), at: newYork, calendar: ny))
        assertNear(december.sunrise, date(ny, "2024-12-21 07:17"))
        assertNear(december.sunset, date(ny, "2024-12-21 16:32"))
    }

    func testPolarNightHasNoSunTimes() {
        let tromso = Coordinate(latitude: 69.65, longitude: 18.96)
        let oslo = calendar("Europe/Oslo")
        XCTAssertNil(SolarCalculator.sunTimes(on: date(oslo, "2024-12-21 12:00"), at: tromso, calendar: oslo))
    }

    // MARK: After dark boundaries

    private func scheduler(at now: Date, place: Coordinate?, calendar: Calendar) -> AfterDarkScheduler {
        let scheduler = AfterDarkScheduler(clock: MockTimeProvider(date: now), calendar: calendar, manager: nil)
        scheduler.useCoordinate(place)
        return scheduler
    }

    func testAfterDarkWithLocationFollowsSunsetAndSunrise() {
        let uk = calendar("Europe/London")
        let noon = date(uk, "2024-06-21 12:00")
        let scheduler = scheduler(at: noon, place: london, calendar: uk)
        let settings = Settings(appearance: .afterDark)
        XCTAssertTrue(scheduler.usesSun(settings))
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 21:17")))
        XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 21:25")))
        XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 04:39")))
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 04:47")))
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 21:00")),
                       "the fixed 9:00 PM start is not used when the sun is known")

        assertNear(scheduler.nextBoundary(after: noon, settings: settings), date(uk, "2024-06-21 21:21"))
        assertNear(scheduler.nextBoundary(after: date(uk, "2024-06-21 23:00"), settings: settings), date(uk, "2024-06-22 04:43"))
        let tonight = scheduler.tonight(at: date(uk, "2024-06-21 23:00"))
        assertNear(tonight?.sunset, date(uk, "2024-06-21 21:21"))
        assertNear(tonight?.sunrise, date(uk, "2024-06-22 04:43"))
    }

    func testAfterDarkWithoutLocationUsesFixedHours() {
        let uk = calendar("Europe/London")
        let noon = date(uk, "2024-06-21 12:00")
        let settings = Settings(appearance: .afterDark)
        for scheduler in [scheduler(at: noon, place: nil, calendar: uk), scheduler(at: noon, place: london, calendar: uk)] {
            var settings = settings
            // With a place, turning location off also falls back to the fixed hours.
            if scheduler.coordinate != nil { settings.useLocationForAfterDark = false }
            XCTAssertFalse(scheduler.usesSun(settings))
            XCTAssertFalse(scheduler.isNight(settings, systemIsDark: true, at: date(uk, "2024-06-21 20:59")))
            XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 21:00")))
            XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-22 06:29")))
            XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-22 06:30")))
            XCTAssertEqual(scheduler.nextBoundary(after: noon, settings: settings), date(uk, "2024-06-21 21:00"))
            XCTAssertEqual(scheduler.nextBoundary(after: date(uk, "2024-06-21 22:00"), settings: settings), date(uk, "2024-06-22 06:30"))
        }
    }

    func testEditedFixedHoursMoveTheBoundary() {
        let uk = calendar("Europe/London")
        var settings = Settings(appearance: .afterDark, useLocationForAfterDark: false)
        settings.afterDarkStart = ClockTime(hour: 22, minute: 15)
        let scheduler = scheduler(at: date(uk, "2024-06-21 12:00"), place: nil, calendar: uk)
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: date(uk, "2024-06-21 22:00")))
        XCTAssertEqual(scheduler.nextBoundary(settings: settings), date(uk, "2024-06-21 22:15"))
    }

    func testOnlyAfterDarkHasBoundaries() {
        let scheduler = scheduler(at: Date(), place: london, calendar: .current)
        for appearance in [Appearance.day, .night, .matchSystem] {
            XCTAssertNil(scheduler.nextBoundary(settings: Settings(appearance: appearance)))
        }
    }

    func testShiftingFixedHoursWrapsAroundMidnight() {
        let (controller, _) = makeTestController()
        let viewModel = SettingsViewModel(controller: controller)
        controller.updateSettings { $0.afterDarkStart = ClockTime(hour: 23, minute: 50) }
        viewModel.shiftAfterDark(start: true, by: 15)
        XCTAssertEqual(controller.settings.afterDarkStart, ClockTime(hour: 0, minute: 5))
        viewModel.shiftAfterDark(start: false, by: -15)
        XCTAssertEqual(controller.settings.afterDarkEnd, ClockTime(hour: 6, minute: 15))
    }

    // MARK: Drift

    func testDriftStepsEvery90SecondsAndStopsAt20() {
        let clock = AdvancingTimeProvider()
        let drift = DriftController(clock: clock)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 0)
        clock.advance(89)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 0)
        clock.advance(1)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 1)
        clock.advance(3 * 3600)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, DriftController.maxSteps)
        drift.update(active: false)
        XCTAssertEqual(drift.steps, 0, "leaving the game resets the session")
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 0, "a new session starts from zero")
    }

    func testDriftNeverGoesBelowTheFloor() {
        let settings = Settings(glow: 18, warmth: 95, glowFloor: 10)
        let drifted = DriftController.apply(steps: 20, to: settings)
        XCTAssertEqual(drifted.glow, 10)
        XCTAssertEqual(drifted.warmth, 100)
        XCTAssertEqual(DriftController.apply(steps: 5, to: settings).glow, 13)
        XCTAssertEqual(DriftController.apply(steps: 20, to: Settings(glow: 40, warmth: 50)).glow, 20)
        XCTAssertEqual(DriftController.apply(steps: 20, to: Settings(glow: 40, warmth: 50)).warmth, 70)
        XCTAssertEqual(DriftController.apply(steps: 3, to: Settings(glow: 5, glowFloor: 10)).glow, 5, "drift never raises glow")
        XCTAssertEqual(DriftController.apply(steps: 20, to: settings).glowFloor, settings.glowFloor)
    }

    // MARK: First night

    func testFirstNightAppearsExactlyOnce() {
        let (controller, dir) = makeTestController()
        controller.updateSettings { $0.appearance = .day }
        controller.updateFirstNight()
        XCTAssertFalse(controller.showsFirstNight, "not in Day")

        controller.updateSettings { $0.appearance = .night }
        controller.updateFirstNight()
        XCTAssertTrue(controller.showsFirstNight)
        controller.skipFirstNight()
        XCTAssertFalse(controller.showsFirstNight)
        XCTAssertTrue(controller.settings.calibrated)
        XCTAssertEqual(controller.settings.glow, NightPreset.lightsOut.glow)
        XCTAssertEqual(controller.settings.warmth, NightPreset.lightsOut.warmth)
        controller.updateFirstNight()
        XCTAssertFalse(controller.showsFirstNight)

        let images = ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true))
        let reopened = AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider(), imageStore: images)
        XCTAssertTrue(reopened.settings.calibrated)
        reopened.updateFirstNight()
        XCTAssertFalse(reopened.showsFirstNight, "never again after a relaunch")
    }

    func testCalibratingSetsTheFloorAndKeepsTheResultOpen() {
        let (controller, _) = makeTestController()
        controller.updateSettings { $0.appearance = .night }
        controller.updateFirstNight()
        controller.calibrate(pick: 14)
        XCTAssertEqual(controller.settings.glowFloor, 14)
        XCTAssertEqual(controller.settings.glow, 18)
        XCTAssertTrue(controller.settings.calibrated)
        XCTAssertTrue(controller.showsFirstNight, "the result screen stays until Start playing")
        controller.endFirstNight()
        XCTAssertFalse(controller.showsFirstNight)
        controller.updateFirstNight()
        XCTAssertFalse(controller.showsFirstNight)

        controller.calibrate(pick: 100)
        XCTAssertEqual(controller.settings.glow, 100, "glow tops out at 100")
        let viewModel = SettingsViewModel(controller: controller)
        viewModel.setGlow(30)
        XCTAssertEqual(controller.settings.glow, 100, "the slider cannot go below the floor")
    }

    func testPresetsRespectTheFloorAndStillMatch() {
        let (controller, _) = makeTestController()
        let viewModel = SettingsViewModel(controller: controller)
        controller.calibrate(pick: 24)
        viewModel.applyPreset(.lightsOut)
        XCTAssertEqual(controller.settings.glow, 24)
        XCTAssertEqual(NightPreset.matching(controller.settings), .lightsOut)
    }
}
