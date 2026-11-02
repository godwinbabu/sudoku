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

    /// Sleep colors come from the current display profile (CODESPEC 12.3); other themes are fixed.
    var themeColors: ThemeColors {
        guard themeEffective == .sleep else { return ThemeColors.forTheme(themeEffective) }
        return SleepPalette(profile: currentDisplayProfile, increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled).themeColors
    }
}
