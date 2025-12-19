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

    var overlayOpacity: Double {
        switch self {
        case .normal: return 0.0
        case .dim: return 0.25
        case .extraDim: return 0.45
        }
    }
}
