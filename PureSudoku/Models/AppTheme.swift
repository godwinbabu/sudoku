import Foundation

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case sleep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .sleep: return "Bedtime"
        }
    }
}

/// The three fixed dim steps used before display profiles. Kept only to migrate old settings files.
enum SleepBrightness: String, Codable, CaseIterable, Identifiable {
    case normal
    case dim
    case extraDim

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .dim: return "Dim"
        case .extraDim: return "Extra Dim"
        }
    }
}
