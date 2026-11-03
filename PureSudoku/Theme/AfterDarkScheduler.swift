import CoreLocation
import Foundation

/// A rough place on Earth, in degrees. East and north are positive.
struct Coordinate: Equatable {
    var latitude: Double
    var longitude: Double
}

struct SunTimes: Equatable {
    var sunrise: Date
    var sunset: Date
}

/// Sunrise and sunset on the device, with the NOAA solar equations (no network). Accurate to about
/// a minute away from the poles. Returns nil on days the sun does not rise or does not set.
enum SolarCalculator {
    static func sunTimes(on date: Date, at place: Coordinate, calendar: Calendar = .current) -> SunTimes? {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let midnightUTC = utc.date(from: day),
              let dayOfYear = utc.ordinality(of: .day, in: .year, for: midnightUTC) else { return nil }

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
        // Minutes after midnight UTC of the local calendar day; may fall outside 0..<1440.
        let rise = 720 - 4 * (place.longitude + ha) - eqTime
        let set = 720 - 4 * (place.longitude - ha) - eqTime
        return SunTimes(sunrise: midnightUTC + rise * 60, sunset: midnightUTC + set * 60)
    }
}

/// Decides when After dark is Night (CODESPEC 7.1): sunset to sunrise from rough location, or the
/// fixed hours without one. Fires `onBoundary` when the look should change, so the app can fade.
@MainActor
final class AfterDarkScheduler: NSObject, ObservableObject {
    @Published private(set) var coordinate: Coordinate?
    @Published private(set) var authorization: CLAuthorizationStatus
    var onBoundary: () -> Void = {}

    private let clock: TimeProvider
    private let calendar: Calendar
    private let manager: CLLocationManager?
    private var timer: Timer?

    /// Pass `manager: nil` in tests; set the place with `useCoordinate`.
    init(clock: TimeProvider = SystemTimeProvider(), calendar: Calendar = .current, manager: CLLocationManager? = CLLocationManager()) {
        self.clock = clock
        self.calendar = calendar
        self.manager = manager
        authorization = manager?.authorizationStatus ?? .notDetermined
        super.init()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyReduced
        // Permission was given earlier: refresh the place without asking again.
        if Self.isAllowed(authorization) { manager?.requestLocation() }
    }

    var now: Date { clock.now() }
    var isLocationDenied: Bool { authorization == .denied || authorization == .restricted }

    func useCoordinate(_ coordinate: Coordinate?) { self.coordinate = coordinate }

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
        coordinate.flatMap { SolarCalculator.sunTimes(on: date, at: $0, calendar: calendar) }
    }

    /// True when sunset and sunrise decide the window (location is on and known, and the sun sets today).
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
        if date < today.sunrise, let yesterday = sunTimes(on: date.addingTimeInterval(-86_400)) {
            return SunTimes(sunrise: today.sunrise, sunset: yesterday.sunset)
        }
        guard let tomorrow = sunTimes(on: date.addingTimeInterval(86_400)) else { return nil }
        return SunTimes(sunrise: tomorrow.sunrise, sunset: today.sunset)
    }

    /// The next moment After dark switches between Day and Night, or nil when not in After dark.
    func nextBoundary(after date: Date? = nil, settings: Settings) -> Date? {
        guard settings.appearance == .afterDark else { return nil }
        let date = date ?? now
        let start = calendar.startOfDay(for: date)
        var candidates: [Date] = []
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if settings.useLocationForAfterDark, let sun = sunTimes(on: day) {
                candidates += [sun.sunrise, sun.sunset]
            } else {
                candidates += [settings.afterDarkStart, settings.afterDarkEnd].compactMap {
                    calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: day)
                }
            }
        }
        return candidates.filter { $0 > date }.min()
    }

    /// Re-arms the one-shot timer for the next boundary. Call after any settings change.
    func schedule(for settings: Settings) {
        timer?.invalidate()
        timer = nil
        guard let next = nextBoundary(settings: settings) else { return }
        // A second late, so the check lands on the new side of the boundary.
        let timer = Timer(fire: next.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onBoundary()
                self.schedule(for: settings)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private static func isAllowed(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

extension AfterDarkScheduler: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if Self.isAllowed(status) { manager.requestLocation() }
            self.onBoundary()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let place = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.coordinate = Coordinate(latitude: place.latitude, longitude: place.longitude)
            self.onBoundary()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No place: After dark keeps the fixed hours.
    }
}
