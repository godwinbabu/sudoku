import Foundation

struct Settings: Codable, Equatable {
    var theme: AppTheme
    var showTimer: Bool
    var autoRemoveCandidates: Bool
    var autoCheckMistakes: Bool
    var bedtimeMode: Bool
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    var sleepBrightness: SleepBrightness
    var keepImportImages: Bool
    /// Ask "Try it yourself first?" before a hint shows its result (CODESPEC 6.3.1).
    var askBeforeHintResult: Bool
    /// How hint text names cells.
    var cellNameStyle: CellNameStyle

    init(theme: AppTheme = .system, showTimer: Bool = true, autoRemoveCandidates: Bool = true, autoCheckMistakes: Bool = true, bedtimeMode: Bool = false, soundsEnabled: Bool = false, hapticsEnabled: Bool = false, sleepBrightness: SleepBrightness = .extraDim, keepImportImages: Bool = true, askBeforeHintResult: Bool = true, cellNameStyle: CellNameStyle = .long) {
        self.theme = theme
        self.showTimer = showTimer
        self.autoRemoveCandidates = autoRemoveCandidates
        self.autoCheckMistakes = autoCheckMistakes
        self.bedtimeMode = bedtimeMode
        self.soundsEnabled = soundsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.sleepBrightness = sleepBrightness
        self.keepImportImages = keepImportImages
        self.askBeforeHintResult = askBeforeHintResult
        self.cellNameStyle = cellNameStyle
        enforceBedtimeRulesIfNeeded()
    }

    mutating func toggleBedtimeMode(_ enabled: Bool) {
        bedtimeMode = enabled
        if bedtimeMode {
            soundsEnabled = false
            hapticsEnabled = false
        } else {
            // retain previously selected theme when exiting Bedtime Mode
        }
    }

    mutating func updateTheme(_ newValue: AppTheme) {
        theme = newValue
    }

    mutating func enforceBedtimeRulesIfNeeded() {
        if bedtimeMode {
            soundsEnabled = false
            hapticsEnabled = false
        }
    }

    static var `default`: Settings { Settings() }

    private enum CodingKeys: String, CodingKey {
        case theme
        case showTimer
        case autoRemoveCandidates
        case autoCheckMistakes
        case bedtimeMode
        case soundsEnabled
        case hapticsEnabled
        case sleepBrightness
        case keepImportImages
        case askBeforeHintResult
        case cellNameStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(AppTheme.self, forKey: .theme)
        showTimer = try container.decode(Bool.self, forKey: .showTimer)
        autoRemoveCandidates = try container.decode(Bool.self, forKey: .autoRemoveCandidates)
        autoCheckMistakes = try container.decode(Bool.self, forKey: .autoCheckMistakes)
        bedtimeMode = try container.decode(Bool.self, forKey: .bedtimeMode)
        soundsEnabled = try container.decode(Bool.self, forKey: .soundsEnabled)
        hapticsEnabled = try container.decode(Bool.self, forKey: .hapticsEnabled)
        sleepBrightness = try container.decode(SleepBrightness.self, forKey: .sleepBrightness)
        keepImportImages = try container.decodeIfPresent(Bool.self, forKey: .keepImportImages) ?? true
        askBeforeHintResult = try container.decodeIfPresent(Bool.self, forKey: .askBeforeHintResult) ?? true
        cellNameStyle = try container.decodeIfPresent(CellNameStyle.self, forKey: .cellNameStyle) ?? .long
        enforceBedtimeRulesIfNeeded()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encode(showTimer, forKey: .showTimer)
        try container.encode(autoRemoveCandidates, forKey: .autoRemoveCandidates)
        try container.encode(autoCheckMistakes, forKey: .autoCheckMistakes)
        try container.encode(bedtimeMode, forKey: .bedtimeMode)
        try container.encode(soundsEnabled, forKey: .soundsEnabled)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(sleepBrightness, forKey: .sleepBrightness)
        try container.encode(keepImportImages, forKey: .keepImportImages)
        try container.encode(askBeforeHintResult, forKey: .askBeforeHintResult)
        try container.encode(cellNameStyle, forKey: .cellNameStyle)
    }
}
