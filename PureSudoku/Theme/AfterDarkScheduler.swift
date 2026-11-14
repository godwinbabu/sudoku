import CoreLocation
import Foundation
import UIKit

/// A rough place on Earth, in degrees. East and north are positive.
struct Coordinate: Equatable {
    var latitude: Double
    var longitude: Double
}

struct SunTimes: Equatable {
    var sunrise: Date
    var sunset: Date
}

extension Calendar {
    /// Gregorian in the given calendar's time zone: the sun maths and the fixed hours need real
    /// Gregorian dates, whatever calendar the device uses (a Buddhist year 2567 is not 2567 AD).
    var gregorianInSameZone: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        return gregorian
    }
}

/// Sunrise and sunset on the device, with the NOAA solar equations (no network). Accurate to about
/// a minute away from the poles. Returns nil on days the sun does not rise or does not set.
enum SolarCalculator {
    /// The sunrise and sunset of the solar day whose noon falls on `date`'s local day. Near the poles
    /// the sunset can fall after local midnight; across the date line this picks the right UTC day.
    static func sunTimes(on date: Date, at place: Coordinate, timeZone: TimeZone) -> SunTimes? {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = local.dateComponents([.year, .month, .day], from: date)
        guard let dayStart = local.date(from: day), let dayEnd = local.date(byAdding: .day, value: 1, to: dayStart),
              let utcDay = utc.date(from: day) else { return nil }
        for offset in [0, -1, 1] {
            guard let midnightUTC = utc.date(byAdding: .day, value: offset, to: utcDay),
                  let event = events(midnightUTC: midnightUTC, calendar: utc, place: place) else { continue }
            if event.noon >= dayStart && event.noon < dayEnd { return event.times }
        }
        return nil
    }

    private static func events(midnightUTC: Date, calendar utc: Calendar, place: Coordinate) -> (noon: Date, times: SunTimes)? {
        guard let dayOfYear = utc.ordinality(of: .day, in: .year, for: midnightUTC) else { return nil }
        let gamma = 2 * Double.pi / 365 * Double(dayOfYear - 1)
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let lat = place.latitude * .pi / 180
        // 90.833°: the sun's radius plus atmospheric refraction.
        let cosHA = cos(90.833 * .pi / 180) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl)
        guard (-1...1).contains(cosHA) else { return nil }
        let ha = acos(cosHA) * 180 / .pi
        // Minutes after midnight UTC; may fall outside 0..<1440.
        let noon = 720 - 4 * place.longitude - eqTime
        let times = SunTimes(sunrise: midnightUTC + (noon - 4 * ha) * 60, sunset: midnightUTC + (noon + 4 * ha) * 60)
        return (midnightUTC + noon * 60, times)
    }
}

/// Decides when After dark is Night (CODESPEC 7.1): sunset to sunrise from rough location, or the
/// fixed hours without one. Each local day uses one source: the sun when it rises and sets that day,
/// else the fixed hours. Calls `onBoundary` whenever the look may have changed, so the app can fade.
@MainActor
final class AfterDarkScheduler: NSObject {
    private(set) var coordinate: Coordinate?
    private(set) var authorization: CLAuthorizationStatus
    /// When the armed timer fires (a second after the boundary), for tests.
    private(set) var scheduledFire: Date?
    var onBoundary: () -> Void = {}

    private let clock: TimeProvider
    private let deviceCalendar: Calendar
    private let manager: CLLocationManager?
    private var timer: Timer?
    private var settings = Settings()

    /// Pass `manager: nil` in tests; set the place with `useCoordinate`. The default calendar follows
    /// time zone changes.
    init(clock: TimeProvider = SystemTimeProvider(), calendar: Calendar = .autoupdatingCurrent,
         manager: CLLocationManager? = CLLocationManager()) {
        self.clock = clock
        deviceCalendar = calendar
        self.manager = manager
        authorization = manager?.authorizationStatus ?? .notDetermined
        super.init()
        // iOS calls locationManagerDidChangeAuthorization right after this; that fetches the place
        // when permission was given earlier, without asking again.
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyReduced
        let center = NotificationCenter.default
        for name in [UIApplication.significantTimeChangeNotification, .NSSystemTimeZoneDidChange] {
            center.addObserver(self, selector: #selector(clockChanged), name: name, object: nil)
        }
    }

    var now: Date { clock.now() }
    var isLocationDenied: Bool { authorization == .denied || authorization == .restricted }
    /// Gregorian, in the device's current time zone.
    private var calendar: Calendar { deviceCalendar.gregorianInSameZone }

    func useCoordinate(_ coordinate: Coordinate?) {
        self.coordinate = coordinate
        refresh()
    }

    /// Permission changes from iOS. Without permission the cached place is dropped.
    func handleAuthorization(_ status: CLAuthorizationStatus) {
        authorization = status
        if Self.isAllowed(status) {
            manager?.requestLocation()
        } else {
            coordinate = nil
        }
        refresh()
    }

    /// Asks for rough location. Called only when the player picks After dark or sunset and sunrise.
    func requestLocation() {
        guard let manager else { return }
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if Self.isAllowed(authorization) {
            manager.requestLocation()
        }
    }

    func sunTimes(on date: Date) -> SunTimes? {
        coordinate.flatMap { SolarCalculator.sunTimes(on: date, at: $0, timeZone: calendar.timeZone) }
    }

    /// True when sunset and sunrise decide the window on `date`'s day.
    func usesSun(_ settings: Settings, on date: Date? = nil) -> Bool {
        settings.useLocationForAfterDark && sunTimes(on: date ?? now) != nil
    }

    func isNight(_ settings: Settings, systemIsDark: Bool, at date: Date? = nil) -> Bool {
        let date = date ?? now
        let sun = settings.useLocationForAfterDark ? sunTimes(on: date) : nil
        return settings.isNight(now: date, sunset: sun?.sunset, sunrise: sun?.sunrise, systemIsDark: systemIsDark, calendar: calendar)
    }

    /// Tonight's window for the Display page: this evening's sunset (or last night's, before dawn)
    /// to the next sunrise.
    func tonight(at date: Date? = nil) -> SunTimes? {
        let date = date ?? now
        guard let today = sunTimes(on: date) else { return nil }
        if date < today.sunrise {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: date).flatMap(sunTimes(on:)) else { return nil }
            return SunTimes(sunrise: today.sunrise, sunset: yesterday.sunset)
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date).flatMap(sunTimes(on:)) else { return nil }
        return SunTimes(sunrise: tomorrow.sunrise, sunset: today.sunset)
    }

    /// The next moment After dark switches between Day and Night, or nil when not in After dark.
    /// It gathers every moment a switch could happen (sunrises, sunsets, fixed-hour starts and ends,
    /// whichever day's window they belong to, and local midnights, where a day can change source),
    /// then returns the first where `isNight` really changes.
    func nextBoundary(after date: Date? = nil, settings: Settings) -> Date? {
        guard settings.appearance == .afterDark else { return nil }
        let date = date ?? now
        let calendar = calendar
        let today = calendar.startOfDay(for: date)
        var candidates: [Date] = []
        for offset in -1...3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            candidates.append(day)
            if settings.useLocationForAfterDark, let sun = sunTimes(on: day) { candidates += [sun.sunrise, sun.sunset] }
            candidates += settings.fixedWindows(startingOn: day, calendar: calendar).flatMap { [$0.lowerBound, $0.upperBound] }
        }
        let later = Set(candidates.filter { $0 > date }).sorted()
        let current = isNight(settings, systemIsDark: false, at: date)
        // shortcut: with no switch in the next few days (an empty fixed window), re-check at the last candidate.
        return later.first { isNight(settings, systemIsDark: false, at: $0) != current } ?? later.last
    }

    /// Re-arms the one-shot timer for the next boundary. Call after any settings change.
    func schedule(for settings: Settings) {
        self.settings = settings
        timer?.invalidate()
        timer = nil
        scheduledFire = nil
        guard let next = nextBoundary(settings: settings) else { return }
        // A second late, so the check lands on the new side of the boundary.
        let fire = next.addingTimeInterval(1)
        let timer = Timer(fire: fire, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        scheduledFire = fire
    }

    /// Something that moves the window changed (a boundary, the place, permission, the clock or the
    /// time zone): re-arm the timer and let the app repaint.
    private func refresh() {
        schedule(for: settings)
        onBoundary()
    }

    /// The system can post clock and time-zone changes off the main thread; Swift 6 would trap there.
    @objc nonisolated private func clockChanged() {
        NSTimeZone.resetSystemTimeZone()
        if Thread.isMainThread {
            MainActor.assumeIsolated { refresh() }
        } else {
            Task { @MainActor in self.refresh() }
        }
    }

    private static func isAllowed(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

extension AfterDarkScheduler: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handleAuthorization(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let place = locations.last?.coordinate else { return }
        Task { @MainActor in self.useCoordinate(Coordinate(latitude: place.latitude, longitude: place.longitude)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No place: After dark keeps the fixed hours.
    }
}
