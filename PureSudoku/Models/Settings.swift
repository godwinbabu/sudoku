import Foundation

struct Settings: Codable, Equatable {
    var theme: AppTheme
    var showTimer: Bool
    var autoRemoveCandidates: Bool
    var autoCheckMistakes: Bool
    var bedtimeMode: Bool
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    /// Calibrated Sleep displays, at most `DisplayProfile.maxProfiles` (CODESPEC 12.3).
    var displayProfiles: [DisplayProfile]
    /// Profile used by the Sleep theme.
    var activeDisplayProfileID: UUID
    /// Profile used while Bedtime Mode is on (nil = the active one).
    var bedtimeDisplayProfileID: UUID?
    /// True once the player has run the calibration (or dismissed the offer).
    var hasCalibratedDisplay: Bool
    var keepImportImages: Bool
    /// Ask "Try it yourself first?" before a hint shows its result (CODESPEC 6.3.1).
    var askBeforeHintResult: Bool
    /// How hint text names cells.
    var cellNameStyle: CellNameStyle

    init(
        theme: AppTheme = .system,
        showTimer: Bool = true,
        autoRemoveCandidates: Bool = true,
        autoCheckMistakes: Bool = true,
        bedtimeMode: Bool = false,
        soundsEnabled: Bool = false,
        hapticsEnabled: Bool = false,
        displayProfiles: [DisplayProfile]? = nil,
        keepImportImages: Bool = true,
        askBeforeHintResult: Bool = true,
        cellNameStyle: CellNameStyle = .long
    ) {
        self.theme = theme
        self.showTimer = showTimer
        self.autoRemoveCandidates = autoRemoveCandidates
        self.autoCheckMistakes = autoCheckMistakes
        self.bedtimeMode = bedtimeMode
        self.soundsEnabled = soundsEnabled
        self.hapticsEnabled = hapticsEnabled
        let profiles = displayProfiles ?? [DisplayProfile.migrated(from: .extraDim)]
        self.displayProfiles = profiles
        self.activeDisplayProfileID = profiles[0].id
        self.bedtimeDisplayProfileID = nil
        self.hasCalibratedDisplay = false
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

    /// The profile the Sleep theme uses now: the bedtime profile in Bedtime Mode, else the active one.
    var currentDisplayProfile: DisplayProfile {
        let id = bedtimeMode ? (bedtimeDisplayProfileID ?? activeDisplayProfileID) : activeDisplayProfileID
        return displayProfiles.first { $0.id == id } ?? displayProfiles[0]
    }

    /// Adds or replaces a profile (matched by id) and makes it active. Returns false if the
    /// profile is new and the limit is reached.
    @discardableResult
    mutating func saveDisplayProfile(_ profile: DisplayProfile) -> Bool {
        if let index = displayProfiles.firstIndex(where: { $0.id == profile.id }) {
            displayProfiles[index] = profile
        } else {
            guard displayProfiles.count < DisplayProfile.maxProfiles else { return false }
            displayProfiles.append(profile)
        }
        activeDisplayProfileID = profile.id
        hasCalibratedDisplay = true
        return true
    }

    /// Deletes a profile; the last one cannot be deleted.
    mutating func deleteDisplayProfile(id: UUID) {
        guard displayProfiles.count > 1 else { return }
        displayProfiles.removeAll { $0.id == id }
        if activeDisplayProfileID == id { activeDisplayProfileID = displayProfiles[0].id }
        if bedtimeDisplayProfileID == id { bedtimeDisplayProfileID = nil }
    }

    private enum CodingKeys: String, CodingKey {
        case theme
        case showTimer
        case autoRemoveCandidates
        case autoCheckMistakes
        case bedtimeMode
        case soundsEnabled
        case hapticsEnabled
        case sleepBrightness // read only, to migrate old files
        case displayProfiles
        case activeDisplayProfileID
        case bedtimeDisplayProfileID
        case hasCalibratedDisplay
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
        let legacy = try container.decodeIfPresent(SleepBrightness.self, forKey: .sleepBrightness) ?? .extraDim
        let profiles = try container.decodeIfPresent([DisplayProfile].self, forKey: .displayProfiles) ?? []
        displayProfiles = profiles.isEmpty ? [DisplayProfile.migrated(from: legacy)] : Array(profiles.prefix(DisplayProfile.maxProfiles))
        let active = try container.decodeIfPresent(UUID.self, forKey: .activeDisplayProfileID)
        if let active, displayProfiles.contains(where: { $0.id == active }) {
            activeDisplayProfileID = active
        } else {
            activeDisplayProfileID = displayProfiles[0].id
        }
        let bedtime = try container.decodeIfPresent(UUID.self, forKey: .bedtimeDisplayProfileID)
        bedtimeDisplayProfileID = displayProfiles.contains { $0.id == bedtime } ? bedtime : nil
        hasCalibratedDisplay = try container.decodeIfPresent(Bool.self, forKey: .hasCalibratedDisplay) ?? false
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
        try container.encode(displayProfiles, forKey: .displayProfiles)
        try container.encode(activeDisplayProfileID, forKey: .activeDisplayProfileID)
        try container.encodeIfPresent(bedtimeDisplayProfileID, forKey: .bedtimeDisplayProfileID)
        try container.encode(hasCalibratedDisplay, forKey: .hasCalibratedDisplay)
        try container.encode(keepImportImages, forKey: .keepImportImages)
        try container.encode(askBeforeHintResult, forKey: .askBeforeHintResult)
        try container.encode(cellNameStyle, forKey: .cellNameStyle)
    }
}
