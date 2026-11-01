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
        // CODESPEC 12.7: Bedtime Mode sets in-app brightness to minimum.
        if settings.bedtimeMode { return SleepBrightness.extraDim.overlayOpacity }
        return settings.themeEffective == .sleep ? settings.sleepBrightness.overlayOpacity : 0.0
    }
}
