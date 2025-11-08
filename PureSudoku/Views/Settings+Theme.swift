import SwiftUI

extension Settings {
    var preferredColorScheme: ColorScheme? {
        switch themeEffective {
        case .light: return .light
        case .dark, .sleep: return .dark
        case .system: return nil
        }
    }

    var themeEffective: AppTheme {
        bedtimeMode ? .sleep : theme
    }

    var themeColors: ThemeColors {
        ThemeColors.forTheme(themeEffective)
    }
}

extension AppController {
    var sleepOverlayOpacity: Double {
        settings.themeEffective == .sleep ? settings.sleepBrightness.overlayOpacity : 0.0
    }
}
