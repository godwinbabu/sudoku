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

    init(theme: AppTheme = .system, showTimer: Bool = true, autoRemoveCandidates: Bool = true, autoCheckMistakes: Bool = true, bedtimeMode: Bool = false, soundsEnabled: Bool = false, hapticsEnabled: Bool = false, sleepBrightness: SleepBrightness = .extraDim) {
        self.theme = theme
        self.showTimer = showTimer
        self.autoRemoveCandidates = autoRemoveCandidates
        self.autoCheckMistakes = autoCheckMistakes
        self.bedtimeMode = bedtimeMode
        self.soundsEnabled = soundsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.sleepBrightness = sleepBrightness
        enforceBedtimeRulesIfNeeded()
    }

    mutating func toggleBedtimeMode(_ enabled: Bool) {
        bedtimeMode = enabled
        enforceBedtimeRulesIfNeeded()
    }

    mutating func updateTheme(_ newValue: AppTheme) {
        theme = bedtimeMode ? .sleep : newValue
    }

    mutating func enforceBedtimeRulesIfNeeded() {
        if bedtimeMode {
            theme = .sleep
            soundsEnabled = false
            hapticsEnabled = false
            if sleepBrightness != .extraDim {
                sleepBrightness = .extraDim
            }
        }
    }

    static var `default`: Settings { Settings() }
}
