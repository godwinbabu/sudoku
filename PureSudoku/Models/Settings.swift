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
    /// Ask "Try it yourself first?" before a hint shows its result (CODESPEC 6.3.1).
    var askBeforeHintResult: Bool
    /// How hint text names cells.
    var cellNameStyle: CellNameStyle
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
        askBeforeHintResult: Bool = true,
        cellNameStyle: CellNameStyle = .long,
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
        self.askBeforeHintResult = askBeforeHintResult
        self.cellNameStyle = cellNameStyle
        self.keepImportImages = keepImportImages
    }

    static var `default`: Settings { Settings() }

    /// Night is active when appearance is .night, .afterDark inside the window, or .matchSystem
    /// with a dark iPhone setting.
    func isNight(now: Date, sunset: Date? = nil, sunrise: Date? = nil, systemIsDark: Bool, calendar: Calendar = .current) -> Bool {
        switch appearance {
        case .day: return false
        case .night: return true
        case .matchSystem: return systemIsDark
        case .afterDark:
            if useLocationForAfterDark, let sunset, let sunrise { return now >= sunset || now < sunrise }
            let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            let start = afterDarkStart.minutes, end = afterDarkEnd.minutes
            return start <= end ? (minute >= start && minute < end) : (minute >= start || minute < end)
        }
    }

    mutating func apply(_ preset: NightPreset) {
        glow = max(preset.glow, glowFloor)
        warmth = preset.warmth
    }

    // MARK: Codable, with migration from the v1 keys

    private enum CodingKeys: String, CodingKey {
        case appearance, glow, warmth, clarity, glowFloor, calibrated, drift, hideStatusBarInGames
        case useLocationForAfterDark, afterDarkStart, afterDarkEnd
        case soundsEnabled, hapticsEnabled, mistakes, tidyNotes, showTimer
        case askBeforeHintResult, cellNameStyle, keepImportImages
        // v1, read only
        case theme, bedtimeMode, sleepBrightness, autoRemoveCandidates, autoCheckMistakes
        case hasCalibratedDisplay, displayProfiles, activeDisplayProfileID
    }

    /// The part of a v1 display profile we carry over.
    private struct LegacyProfile: Decodable {
        let id: UUID
        let dimness: Double
        let warmth: Double
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }

        var appearance = defaults.appearance
        var glow = defaults.glow
        var warmth = defaults.warmth
        // v1: theme light → Day, dark → Night, system → Match iPhone, sleep or Bedtime Mode → Night with Lights out.
        if let theme: String = try? c.decodeIfPresent(String.self, forKey: .theme) {
            switch theme {
            case "light": appearance = .day
            case "dark", "sleep": appearance = .night
            default: appearance = .matchSystem
            }
            switch value(.sleepBrightness, "extraDim") {
            case "normal": glow = 55
            case "dim": glow = 30
            default: glow = 18
            }
            // A v1 display profile is the player's own tuning: keep its brightness and warmth.
            let profiles: [LegacyProfile] = value(.displayProfiles, [])
            let activeID: UUID? = value(.activeDisplayProfileID, nil)
            if let profile = profiles.first(where: { $0.id == activeID }) ?? profiles.first {
                glow = ((1 - profile.dimness) * 60).rounded()
                warmth = (profile.warmth * 100).rounded()
            }
            if theme == "sleep" || value(.bedtimeMode, false) {
                appearance = .night
                glow = NightPreset.lightsOut.glow
                warmth = NightPreset.lightsOut.warmth
            }
        }

        self.appearance = value(.appearance, appearance)
        self.glow = value(.glow, glow)
        self.warmth = value(.warmth, warmth)
        clarity = value(.clarity, defaults.clarity)
        glowFloor = value(.glowFloor, defaults.glowFloor)
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
        askBeforeHintResult = value(.askBeforeHintResult, defaults.askBeforeHintResult)
        cellNameStyle = value(.cellNameStyle, defaults.cellNameStyle)
        keepImportImages = value(.keepImportImages, defaults.keepImportImages)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(appearance, forKey: .appearance)
        try c.encode(glow, forKey: .glow)
        try c.encode(warmth, forKey: .warmth)
        try c.encode(clarity, forKey: .clarity)
        try c.encode(glowFloor, forKey: .glowFloor)
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
        try c.encode(askBeforeHintResult, forKey: .askBeforeHintResult)
        try c.encode(cellNameStyle, forKey: .cellNameStyle)
        try c.encode(keepImportImages, forKey: .keepImportImages)
    }
}
