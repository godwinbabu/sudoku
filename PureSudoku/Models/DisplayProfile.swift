import Foundation

/// One player's calibrated Sleep display (CODESPEC 12.3). All sliders run 0...1.
struct DisplayProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    /// 0 = brightest Sleep palette, 1 = dimmest allowed.
    var dimness: Double
    /// How close candidates and grid lines are to the digits' brightness (0 = softest allowed).
    var contrast: Double
    /// 0 = neutral, 0.5 = amber, 1 = orange-red. A comfort setting, not a sleep claim.
    var warmth: Double
    /// Grid text size, on top of Dynamic Type: 0 = smaller, 0.5 = standard, 1 = largest.
    var textSize: Double
    /// Lower the screen to its minimum while the app is open (iOS restores it afterwards).
    var lowersScreenBrightness: Bool

    init(id: UUID = UUID(), name: String, dimness: Double = 0.6, contrast: Double = 0.5, warmth: Double = 0.5, textSize: Double = 0.5, lowersScreenBrightness: Bool = false) {
        self.id = id
        self.name = name
        self.dimness = dimness
        self.contrast = contrast
        self.warmth = warmth
        self.textSize = textSize
        self.lowersScreenBrightness = lowersScreenBrightness
    }

    static let maxProfiles = 3

    /// Starting profile for players upgrading from the three fixed dim steps: the same overall look.
    static func migrated(from brightness: SleepBrightness) -> DisplayProfile {
        let dimness: Double
        switch brightness {
        case .normal: dimness = 0.2
        case .dim: dimness = 0.5
        case .extraDim: dimness = 0.75
        }
        return DisplayProfile(name: "Reading in bed", dimness: dimness)
    }
}
