import UIKit
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
        let june = try XCTUnwrap(SolarCalculator.sunTimes(on: date(uk, "2024-06-21 12:00"), at: london, timeZone: uk.timeZone))
        assertNear(june.sunrise, date(uk, "2024-06-21 04:43"))
        assertNear(june.sunset, date(uk, "2024-06-21 21:21"))
        // New York 21 December 2024, sunrise 7:17 AM, sunset 4:32 PM (EST). West of Greenwich, so the
        // sunset falls on the next UTC day.
        let ny = calendar("America/New_York")
        let december = try XCTUnwrap(SolarCalculator.sunTimes(on: date(ny, "2024-12-21 12:00"), at: newYork, timeZone: ny.timeZone))
        assertNear(december.sunrise, date(ny, "2024-12-21 07:17"))
        assertNear(december.sunset, date(ny, "2024-12-21 16:32"))
    }

    func testPolarNightHasNoSunTimes() {
        let tromso = Coordinate(latitude: 69.65, longitude: 18.96)
        let oslo = calendar("Europe/Oslo")
        XCTAssertNil(SolarCalculator.sunTimes(on: date(oslo, "2024-12-21 12:00"), at: tromso, timeZone: oslo.timeZone))
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

    /// C1: a place that arrives after launch re-arms the timer for sunset, not the fixed 9:00 PM.
    func testLocationUpdateRearmsTheTimer() {
        let uk = calendar("Europe/London")
        let scheduler = scheduler(at: date(uk, "2024-06-21 12:00"), place: nil, calendar: uk)
        var repaints = 0
        scheduler.onBoundary = { repaints += 1 }
        scheduler.schedule(for: Settings(appearance: .afterDark))
        XCTAssertEqual(scheduler.scheduledFire, date(uk, "2024-06-21 21:00").addingTimeInterval(1))
        scheduler.useCoordinate(london)
        assertNear(scheduler.scheduledFire, date(uk, "2024-06-21 21:21"))
        XCTAssertEqual(repaints, 1)
    }

    /// C2: when permission is taken away, the cached place is dropped and the fixed hours return.
    func testRevokedPermissionDropsThePlace() {
        let uk = calendar("Europe/London")
        let scheduler = scheduler(at: date(uk, "2024-06-21 12:00"), place: london, calendar: uk)
        let settings = Settings(appearance: .afterDark)
        scheduler.schedule(for: settings)
        XCTAssertTrue(scheduler.usesSun(settings))
        scheduler.handleAuthorization(.denied)
        XCTAssertNil(scheduler.coordinate)
        XCTAssertTrue(scheduler.isLocationDenied)
        XCTAssertFalse(scheduler.usesSun(settings))
        XCTAssertEqual(scheduler.scheduledFire, date(uk, "2024-06-21 21:00").addingTimeInterval(1))
    }

    /// C3: across the date line both events land on the requested local day.
    func testSunTimesLandOnTheLocalDayAcrossTheDateLine() throws {
        let places: [(String, Coordinate)] = [
            ("Pacific/Kiritimati", Coordinate(latitude: 1.8721, longitude: -157.4278)),
            ("Pacific/Pago_Pago", Coordinate(latitude: -14.2756, longitude: -170.7020)),
            ("Pacific/Auckland", Coordinate(latitude: -36.8485, longitude: 174.7633)),
            ("Pacific/Tongatapu", Coordinate(latitude: -21.1393, longitude: -175.2049))
        ]
        for (zone, place) in places {
            let local = calendar(zone)
            let noon = date(local, "2024-06-21 12:00")
            let sun = try XCTUnwrap(SolarCalculator.sunTimes(on: noon, at: place, timeZone: local.timeZone), zone)
            XCTAssertTrue(local.isDate(sun.sunrise, inSameDayAs: noon), "\(zone) sunrise \(sun.sunrise)")
            XCTAssertTrue(local.isDate(sun.sunset, inSameDayAs: noon), "\(zone) sunset \(sun.sunset)")
            XCTAssertLessThan(sun.sunrise, sun.sunset, zone)
        }
        // Kiritimati (UTC+14), 21 June 2024: about 6:24 AM and 6:37 PM.
        let kiritimati = calendar("Pacific/Kiritimati")
        let kiritimatiNoon = date(kiritimati, "2024-06-21 12:00")
        let sun = try XCTUnwrap(SolarCalculator.sunTimes(on: kiritimatiNoon, at: places[0].1, timeZone: kiritimati.timeZone))
        assertNear(sun.sunrise, date(kiritimati, "2024-06-21 06:24"))
        assertNear(sun.sunset, date(kiritimati, "2024-06-21 18:37"))
    }

    /// C4: a Buddhist (or any non-Gregorian) device calendar gives the same times.
    func testNonGregorianCalendarGivesTheSameTimes() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Europe/London")!
        let uk = calendar("Europe/London")
        let scheduler = scheduler(at: date(uk, "2024-06-21 12:00"), place: london, calendar: buddhist)
        assertNear(scheduler.sunTimes(on: date(uk, "2024-06-21 12:00"))?.sunset, date(uk, "2024-06-21 21:21"))
        let fixed = Settings(appearance: .afterDark, useLocationForAfterDark: false)
        XCTAssertEqual(scheduler.nextBoundary(after: date(uk, "2024-06-21 12:00"), settings: fixed), date(uk, "2024-06-21 21:00"))
        XCTAssertTrue(scheduler.isNight(fixed, systemIsDark: false, at: date(uk, "2024-06-21 23:00")))
    }

    /// C5: a time zone or clock change re-arms the timer and repaints.
    func testClockChangesRearmTheTimer() {
        let scheduler = scheduler(at: Date(), place: nil, calendar: .current)
        var repaints = 0
        scheduler.onBoundary = { repaints += 1 }
        scheduler.schedule(for: Settings(appearance: .afterDark))
        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        NotificationCenter.default.post(name: UIApplication.significantTimeChangeNotification, object: nil)
        XCTAssertEqual(repaints, 2)
        XCTAssertNotNil(scheduler.scheduledFire)
    }

    /// C5: a clock change posted off the main thread re-arms on the main actor instead of trapping.
    func testClockChangeFromABackgroundThreadRearms() async {
        let scheduler = scheduler(at: Date(), place: nil, calendar: .current)
        var repaints = 0
        scheduler.onBoundary = { repaints += 1 }
        scheduler.schedule(for: Settings(appearance: .afterDark))
        await Task.detached {
            NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        }.value
        for _ in 0..<100 where repaints == 0 { try? await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(repaints, 1)
        XCTAssertNotNil(scheduler.scheduledFire)
    }

    /// C6: when clocks go back, a repeated end time means its first occurrence, for both the
    /// Night check and the boundary list. New York, 3 November 2024, hours 9:00 PM → 1:30 AM.
    func testRepeatedHourUsesTheFirstOccurrence() throws {
        let ny = calendar("America/New_York")
        var settings = Settings(appearance: .afterDark, useLocationForAfterDark: false)
        settings.afterDarkEnd = ClockTime(hour: 1, minute: 30)
        let scheduler = scheduler(at: Date(), place: nil, calendar: ny)
        let utc = ISO8601DateFormatter()
        let firstHalfPast = try XCTUnwrap(utc.date(from: "2024-11-03T05:30:00Z")) // 1:30 AM EDT
        let earlyFirst = try XCTUnwrap(utc.date(from: "2024-11-03T05:15:00Z")) // 1:15 AM EDT
        let earlySecond = try XCTUnwrap(utc.date(from: "2024-11-03T06:15:00Z")) // 1:15 AM EST, again
        XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: earlyFirst))
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: firstHalfPast))
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: earlySecond), "Night ended at the first 1:30")
        XCTAssertEqual(scheduler.nextBoundary(after: earlyFirst, settings: settings), firstHalfPast)
        XCTAssertEqual(scheduler.nextBoundary(after: firstHalfPast, settings: settings), date(ny, "2024-11-03 21:00"))
    }

    /// C7: Tromsø, 17 May 2024. The sun sets at 00:11 on the 18th, and the 18th has no sunset, so
    /// that day uses the fixed hours. Midnight is a boundary.
    func testPolarFallbackDayStartsAtMidnight() {
        let oslo = calendar("Europe/Oslo")
        let tromso = Coordinate(latitude: 69.65, longitude: 18.96)
        let scheduler = scheduler(at: date(oslo, "2024-05-17 23:00"), place: tromso, calendar: oslo)
        let settings = Settings(appearance: .afterDark)
        XCTAssertNotNil(scheduler.sunTimes(on: date(oslo, "2024-05-17 12:00")))
        XCTAssertNil(scheduler.sunTimes(on: date(oslo, "2024-05-18 12:00")))
        assertNear(scheduler.sunTimes(on: date(oslo, "2024-05-17 12:00"))?.sunset, date(oslo, "2024-05-18 00:11"))
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: date(oslo, "2024-05-17 23:00")), "the sun is still up")
        XCTAssertEqual(scheduler.nextBoundary(settings: settings), date(oslo, "2024-05-18 00:00"))
        XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: date(oslo, "2024-05-18 00:01")), "fixed hours from midnight")
        // The first fallback day still ends at 6:30 AM: that end belongs to the window that starts the day before.
        XCTAssertEqual(scheduler.nextBoundary(after: date(oslo, "2024-05-18 00:12"), settings: settings), date(oslo, "2024-05-18 06:30"))
        XCTAssertEqual(scheduler.nextBoundary(after: date(oslo, "2024-05-18 06:30"), settings: settings), date(oslo, "2024-05-18 21:00"))
    }

    /// The reverse: the last fallback day before the sun sets again. Its 9:00 PM start is a boundary,
    /// and the night then ends at the next day's sunrise, not at the fixed 6:30 AM.
    func testLastPolarFallbackDayHandsOverToTheSun() throws {
        let oslo = calendar("Europe/Oslo")
        let tromso = Coordinate(latitude: 69.65, longitude: 18.96)
        let scheduler = scheduler(at: date(oslo, "2024-07-01 12:00"), place: tromso, calendar: oslo)
        let settings = Settings(appearance: .afterDark)
        var day = date(oslo, "2024-07-01 12:00")
        while scheduler.sunTimes(on: oslo.date(byAdding: .day, value: 1, to: day)!) == nil {
            day = oslo.date(byAdding: .day, value: 1, to: day)!
        }
        XCTAssertNil(scheduler.sunTimes(on: day), "the last fallback day")
        let nextDay = oslo.date(byAdding: .day, value: 1, to: day)!
        let sun = try XCTUnwrap(scheduler.sunTimes(on: nextDay))
        let evening = oslo.date(bySettingHour: 20, minute: 0, second: 0, of: day)!
        let start = oslo.date(bySettingHour: 21, minute: 0, second: 0, of: day)
        XCTAssertEqual(scheduler.nextBoundary(after: evening, settings: settings), start)
        let night = oslo.date(bySettingHour: 22, minute: 0, second: 0, of: day)!
        XCTAssertTrue(scheduler.isNight(settings, systemIsDark: false, at: night))
        let morning = try XCTUnwrap(scheduler.nextBoundary(after: night, settings: settings))
        XCTAssertEqual(morning, sun.sunrise)
        XCTAssertFalse(scheduler.isNight(settings, systemIsDark: false, at: morning))
    }

    /// Walks `nextBoundary` from `start` to `end`: Night must flip at every returned boundary and
    /// hold between them (checked every 10 minutes and a second before each boundary).
    private func walk(_ scheduler: AfterDarkScheduler, _ settings: Settings, from start: Date, to end: Date,
                      file: StaticString = #filePath, line: UInt = #line) {
        var time = start
        var boundaries = 0
        while time < end {
            guard let next = scheduler.nextBoundary(after: time, settings: settings) else {
                return XCTFail("no boundary after \(time)", file: file, line: line)
            }
            XCTAssertGreaterThan(next, time, file: file, line: line)
            let state = scheduler.isNight(settings, systemIsDark: false, at: time)
            var probe = time.addingTimeInterval(600)
            while probe < next {
                if scheduler.isNight(settings, systemIsDark: false, at: probe) != state {
                    return XCTFail("Night changed at \(probe) before the boundary \(next)", file: file, line: line)
                }
                probe += 600
            }
            XCTAssertEqual(scheduler.isNight(settings, systemIsDark: false, at: next.addingTimeInterval(-1)), state, file: file, line: line)
            let after = scheduler.isNight(settings, systemIsDark: false, at: next)
            XCTAssertNotEqual(after, state, "no change at \(next)", file: file, line: line)
            time = next
            boundaries += 1
        }
        XCTAssertGreaterThan(boundaries, 0, file: file, line: line)
    }

    func testBoundariesAreExactAcrossTromsoSummer() {
        let oslo = calendar("Europe/Oslo")
        let scheduler = scheduler(at: Date(), place: Coordinate(latitude: 69.65, longitude: 18.96), calendar: oslo)
        walk(scheduler, Settings(appearance: .afterDark), from: date(oslo, "2024-05-01 00:00"), to: date(oslo, "2024-08-31 00:00"))
    }

    func testBoundariesAreExactAcrossNewYorkClockChanges() {
        let ny = calendar("America/New_York")
        var late = Settings(appearance: .afterDark, useLocationForAfterDark: false)
        late.afterDarkStart = ClockTime(hour: 21, minute: 0)
        late.afterDarkEnd = ClockTime(hour: 1, minute: 30)
        var skipped = late
        skipped.afterDarkStart = ClockTime(hour: 2, minute: 15) // does not exist on 10 March
        skipped.afterDarkEnd = ClockTime(hour: 7, minute: 0)
        let withSun = scheduler(at: Date(), place: newYork, calendar: ny)
        let noPlace = scheduler(at: Date(), place: nil, calendar: ny)
        for (from, to) in [("2024-03-07 00:00", "2024-03-14 00:00"), ("2024-10-31 00:00", "2024-11-07 00:00")] {
            walk(withSun, Settings(appearance: .afterDark), from: date(ny, from), to: date(ny, to))
            walk(noPlace, Settings(appearance: .afterDark), from: date(ny, from), to: date(ny, to))
            walk(noPlace, late, from: date(ny, from), to: date(ny, to))
            walk(noPlace, skipped, from: date(ny, from), to: date(ny, to))
        }
    }

    /// C12: tonight's sunrise is the next calendar day, also when clocks go forward overnight.
    func testTonightUsesCalendarDaysOnTheSpringForwardNight() throws {
        let uk = calendar("Europe/London")
        let scheduler = scheduler(at: date(uk, "2024-03-30 23:00"), place: london, calendar: uk)
        let tonight = try XCTUnwrap(scheduler.tonight())
        XCTAssertTrue(uk.isDate(tonight.sunset, inSameDayAs: date(uk, "2024-03-30 12:00")))
        XCTAssertTrue(uk.isDate(tonight.sunrise, inSameDayAs: date(uk, "2024-03-31 12:00")), "\(tonight.sunrise)")
        let beforeDawn = try XCTUnwrap(scheduler.tonight(at: date(uk, "2024-03-31 03:30")))
        XCTAssertTrue(uk.isDate(beforeDawn.sunset, inSameDayAs: date(uk, "2024-03-30 12:00")))
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
        for _ in 0..<18 { // three hours of play, updated every 10 minutes
            clock.advance(600)
            drift.update(active: true)
        }
        XCTAssertEqual(drift.steps, DriftController.maxSteps)
        drift.update(active: false)
        XCTAssertEqual(drift.steps, 0, "leaving the game resets the session")
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 0, "a new session starts from zero")
    }

    /// C11: away from 11 PM until the next night at 11 PM (suspended, so no updates): a new session.
    func testDriftRestartsAfterTheAppWasAway() {
        let clock = AdvancingTimeProvider()
        let drift = DriftController(clock: clock)
        drift.update(active: true)
        clock.advance(15 * 60)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 10)
        clock.advance(24 * 3600)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 0)
        clock.advance(90)
        drift.update(active: true)
        XCTAssertEqual(drift.steps, 1, "the new session steps as usual")
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

    /// C9: the flow keeps the Night palette even if Night ends while it is open.
    func testFirstNightKeepsTheNightPalette() {
        XCTAssertTrue(FirstNightView.palette(Settings(appearance: .day)).isNight)
        XCTAssertEqual(FirstNightView.palette(Settings(appearance: .day, glow: 18, warmth: 75)).ink,
                       Settings(glow: 18, warmth: 75).palette(isNight: true).ink)
    }

    func testCalibratingSetsTheFloorAndKeepsTheResultOpen() {
        let (controller, _) = makeTestController()
        controller.updateSettings { $0.appearance = .night }
        controller.updateFirstNight()
        controller.calibrate(pick: 14)
        XCTAssertEqual(controller.settings.glowFloor, 14)
        XCTAssertEqual(controller.settings.glow, NightPreset.lightsOut.glow, "glow starts mid-range, not at the edge of readable")
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
        controller.calibrate(pick: 32) // the brightest tile, above Red light's glow 30
        viewModel.applyPreset(.redLight)
        XCTAssertEqual(controller.settings.glow, 32)
        XCTAssertEqual(NightPreset.matching(controller.settings), .redLight)
    }
}
