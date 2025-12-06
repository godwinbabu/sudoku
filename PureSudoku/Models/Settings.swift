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
}
