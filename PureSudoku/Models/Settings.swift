import Foundation

/// When wrong digits are shown (CODESPEC 7.3).
enum MistakeMode: String, Codable, CaseIterable, Identifiable {
    case immediate, onCheck, never
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .immediate: return "Right away"
        case .onCheck: return "When I check"
        case .never: return "Never"
        }
    }
}

/// Hours and minutes of a day, for the After dark fallback window.
struct ClockTime: Codable, Equatable {
    var hour: Int
    var minute: Int
    var minutes: Int { hour * 60 + minute }
}

struct Settings: Codable, Equatable {
    // Display & Night (CODESPEC 12)
    var appearance: Appearance
    /// 0...100
    var glow: Double
    /// 0...100
    var warmth: Double
    var clarity: Clarity
    /// Set by "Find my lowest glow"; glow and Drift never go below it.
    var glowFloor: Double
    /// False → the first-night flow runs the first time Night is active.
    var calibrated: Bool
    /// During a night game: −1 glow / +1 warmth every 90 s, max 20 each.
    var drift: Bool
    var hideStatusBarInGames: Bool
    var useLocationForAfterDark: Bool
    /// Fallback After dark window when there is no location.
    var afterDarkStart: ClockTime
    var afterDarkEnd: ClockTime
    // Quiet: Night always forces both off.
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    // Assists
    var mistakes: MistakeMode
    /// Remove a placed digit from the notes it sees.
    var tidyNotes: Bool
    var showTimer: Bool
    // Hints
    /// How hint text names cells: "row 5, column 2" or "R5C2".
    var notation: CellNotation
    // Imports
    var keepImportImages: Bool

    init(
        appearance: Appearance = .afterDark,
        glow: Double = NightPreset.lightsOut.glow,
        warmth: Double = NightPreset.lightsOut.warmth,
        clarity: Clarity = .standard,
        glowFloor: Double = 0,
        calibrated: Bool = false,
        drift: Bool = true,
        hideStatusBarInGames: Bool = true,
        useLocationForAfterDark: Bool = true,
        afterDarkStart: ClockTime = ClockTime(hour: 21, minute: 0),
        afterDarkEnd: ClockTime = ClockTime(hour: 6, minute: 30),
        soundsEnabled: Bool = false,
        hapticsEnabled: Bool = false,
        mistakes: MistakeMode = .immediate,
        tidyNotes: Bool = true,
        showTimer: Bool = true,
        notation: CellNotation = .plain,
        keepImportImages: Bool = true
    ) {
        self.appearance = appearance
        self.glow = glow
        self.warmth = warmth
        self.clarity = clarity
        self.glowFloor = glowFloor
        self.calibrated = calibrated
        self.drift = drift
        self.hideStatusBarInGames = hideStatusBarInGames
        self.useLocationForAfterDark = useLocationForAfterDark
        self.afterDarkStart = afterDarkStart
        self.afterDarkEnd = afterDarkEnd
        self.soundsEnabled = soundsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.mistakes = mistakes
        self.tidyNotes = tidyNotes
        self.showTimer = showTimer
        self.notation = notation
        self.keepImportImages = keepImportImages
    }

    static var `default`: Settings { Settings() }

    /// Night is active when appearance is .night, .afterDark inside the window, or .matchSystem
    /// with a dark iPhone setting.
    func isNight(now: Date = Date(), sunset: Date? = nil, sunrise: Date? = nil, systemIsDark: Bool, calendar: Calendar = .current) -> Bool {
        switch appearance {
        case .day: return false
        case .night: return true
        case .matchSystem: return systemIsDark
        case .afterDark:
            if useLocationForAfterDark, let sunset, let sunrise { return now >= sunset || now < sunrise }
            let today = calendar.startOfDay(for: now)
            return [-1, 0].contains { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return false }
                return fixedWindows(startingOn: day, calendar: calendar).contains { $0.contains(now) }
            }
        }
    }

    /// The fixed-hours Night window that starts on `day`, as instants. A wall time that happens twice
    /// (the hour repeated when clocks go back) means its first occurrence; one that is skipped (clocks
    /// go forward) means the next valid time. Equal start and end mean no window.
    func fixedWindows(startingOn day: Date, calendar: Calendar) -> [Range<Date>] {
        guard afterDarkStart.minutes != afterDarkEnd.minutes else { return [] }
        let endDay = afterDarkEnd.minutes > afterDarkStart.minutes ? day : calendar.date(byAdding: .day, value: 1, to: day)
        func at(_ time: ClockTime, _ day: Date?) -> Date? {
            day.flatMap {
                calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: $0,
                              matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
            }
        }
        guard let start = at(afterDarkStart, day), let end = at(afterDarkEnd, endDay), start < end else { return [] }
        return [start..<end]
    }

    /// 2: glow 0–40 scales the palette and 40–100 the backlight (CODESPEC 12.3).
    static let glowScale = 2

    /// The scale-2 glow that draws the palette as strongly as `glow` did on scale 1, where strength
    /// grew with (glow / 100)^1.15 and the backlight stayed at its minimum.
    static func glowOnScale2(fromScale1 glow: Double) -> Double {
        (PSPalette.paletteGlowRange * pow(min(100, max(0, glow)) / 100, 1.15 / 0.9)).rounded()
    }

    mutating func apply(_ preset: NightPreset) {
        glow = max(preset.glow, glowFloor)
        warmth = preset.warmth
    }

    // MARK: Codable, with migration from the v1 keys

    private enum CodingKeys: String, CodingKey {
        case appearance, glow, warmth, clarity, glowFloor, glowScale, calibrated, drift, hideStatusBarInGames
        case useLocationForAfterDark, afterDarkStart, afterDarkEnd
        case soundsEnabled, hapticsEnabled, mistakes, tidyNotes, showTimer
        case notation, keepImportImages
        // Read only: v1 keys, and cellNameStyle (short/long) from before `notation`.
        // askBeforeHintResult is no longer read: the hint card has no "Try it yourself first?" step.
        case cellNameStyle
        case theme, bedtimeMode, autoRemoveCandidates, autoCheckMistakes
        case hasCalibratedDisplay, displayProfiles, activeDisplayProfileID, bedtimeDisplayProfileID
    }

    /// The part of a v1 display profile we carry over.
    private struct LegacyProfile: Decodable {
        let id: UUID
        let warmth: Double
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }

        var appearance = defaults.appearance
        var warmth = defaults.warmth
        // v1: theme light → Day, dark → Night, system → Match iPhone, sleep or Bedtime Mode → Night with Lights out.
        if let theme: String = try? c.decodeIfPresent(String.self, forKey: .theme) {
            switch theme {
            case "light": appearance = .day
            case "dark", "sleep": appearance = .night
            default: appearance = .matchSystem
            }
            let bedtime = value(.bedtimeMode, false)
            let sleepy = theme == "sleep" || bedtime
            if sleepy {
                appearance = .night
                warmth = NightPreset.lightsOut.warmth
            }
            // A v1 display profile is the player's own tuning: keep its warmth (its brightness was glow scale 1,
            // reset below). Sleep players got an untuned profile until they calibrated, so for them only a
            // calibrated one beats Lights out.
            let profiles: [LegacyProfile] = value(.displayProfiles, [])
            let activeID: UUID? = value(.activeDisplayProfileID, nil)
            let wantedID: UUID? = bedtime ? (value(.bedtimeDisplayProfileID, nil) ?? activeID) : activeID
            if !sleepy || value(.hasCalibratedDisplay, false),
               let profile = profiles.first(where: { $0.id == wantedID }) ?? profiles.first {
                warmth = (profile.warmth * 100).rounded()
            }
        }

        self.appearance = value(.appearance, appearance)
        self.glow = value(.glow, defaults.glow)
        self.warmth = value(.warmth, warmth)
        clarity = value(.clarity, defaults.clarity)
        glowFloor = value(.glowFloor, defaults.glowFloor)
        // Glow scale 1 (before glow drove the backlight) was far too dark, so its glow is not kept: the
        // floor maps to the same palette strength, and glow restarts at Lights out, above the floor.
        if value(.glowScale, 1) < Self.glowScale {
            glowFloor = Self.glowOnScale2(fromScale1: glowFloor)
            self.glow = max(NightPreset.lightsOut.glow, glowFloor)
        }
        calibrated = value(.calibrated, value(.hasCalibratedDisplay, defaults.calibrated))
        drift = value(.drift, defaults.drift)
        hideStatusBarInGames = value(.hideStatusBarInGames, defaults.hideStatusBarInGames)
        useLocationForAfterDark = value(.useLocationForAfterDark, defaults.useLocationForAfterDark)
        afterDarkStart = value(.afterDarkStart, defaults.afterDarkStart)
        afterDarkEnd = value(.afterDarkEnd, defaults.afterDarkEnd)
        soundsEnabled = value(.soundsEnabled, defaults.soundsEnabled)
        hapticsEnabled = value(.hapticsEnabled, defaults.hapticsEnabled)
        let legacyMistakes: MistakeMode = value(.autoCheckMistakes, true) ? .immediate : .onCheck
        mistakes = value(.mistakes, legacyMistakes)
        tidyNotes = value(.tidyNotes, value(.autoRemoveCandidates, defaults.tidyNotes))
        showTimer = value(.showTimer, defaults.showTimer)
        let legacyNotation: CellNotation = value(.cellNameStyle, "long") == "short" ? .grid : defaults.notation
        notation = value(.notation, legacyNotation)
        keepImportImages = value(.keepImportImages, defaults.keepImportImages)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(appearance, forKey: .appearance)
        try c.encode(glow, forKey: .glow)
        try c.encode(warmth, forKey: .warmth)
        try c.encode(clarity, forKey: .clarity)
        try c.encode(glowFloor, forKey: .glowFloor)
        try c.encode(Self.glowScale, forKey: .glowScale)
        try c.encode(calibrated, forKey: .calibrated)
        try c.encode(drift, forKey: .drift)
        try c.encode(hideStatusBarInGames, forKey: .hideStatusBarInGames)
        try c.encode(useLocationForAfterDark, forKey: .useLocationForAfterDark)
        try c.encode(afterDarkStart, forKey: .afterDarkStart)
        try c.encode(afterDarkEnd, forKey: .afterDarkEnd)
        try c.encode(soundsEnabled, forKey: .soundsEnabled)
        try c.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try c.encode(mistakes, forKey: .mistakes)
        try c.encode(tidyNotes, forKey: .tidyNotes)
        try c.encode(showTimer, forKey: .showTimer)
        try c.encode(notation, forKey: .notation)
        try c.encode(keepImportImages, forKey: .keepImportImages)
    }
}
