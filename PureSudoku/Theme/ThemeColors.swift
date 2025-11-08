import SwiftUI

struct ThemeColors {
    let theme: AppTheme
    let background: Color
    let gridBackground: Color
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let error: Color
    let cardBackground: Color
    let gridLine: Color
    let selection: Color
    let dimOverlayOpacity: Double

    var isSleep: Bool { theme == .sleep }
    var numberPadDisabledBackground: Color { secondaryText.opacity(0.25) }
    var numberPadDisabledText: Color { secondaryText.opacity(0.8) }
}

extension ThemeColors {
    static func forTheme(_ theme: AppTheme) -> ThemeColors {
        switch theme {
        case .system:
            return ThemeColors.forTheme(.light)
        case .light:
            return ThemeColors(
                theme: theme,
                background: .white,
                gridBackground: Color(white: 0.95),
                accent: .appAccentAmber,
                primaryText: .black,
                secondaryText: .gray,
                error: .appErrorRed,
                cardBackground: .white,
                gridLine: Color.black.opacity(0.1),
                selection: Color.appAccentAmber.opacity(0.15),
                dimOverlayOpacity: 0
            )
        case .dark:
            return ThemeColors(
                theme: theme,
                background: .appBackgroundDark,
                gridBackground: .appCardBackground,
                accent: .appAccentAmber,
                primaryText: .appTextPrimary,
                secondaryText: .appTextSecondary,
                error: .appErrorRed,
                cardBackground: .appCardBackground,
                gridLine: Color.white.opacity(0.1),
                selection: Color.white.opacity(0.08),
                dimOverlayOpacity: 0
            )
        case .sleep:
            return ThemeColors(
                theme: theme,
                background: .appBackgroundDark,
                gridBackground: .appCardBackground,
                accent: .appAccentOrange,
                primaryText: .appTextPrimary,
                secondaryText: .appTextSecondary,
                error: .appErrorRed,
                cardBackground: .appCardBackground,
                gridLine: Color.white.opacity(0.08),
                selection: Color.appAccentOrange.opacity(0.18),
                dimOverlayOpacity: 0.35
            )
        }
    }
}

struct ThemeManager {
    let settings: Settings

    var colors: ThemeColors { ThemeColors.forTheme(settings.themeEffective) }
}
