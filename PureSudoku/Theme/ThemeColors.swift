import SwiftUI

struct ThemeColors {
    let theme: AppTheme
    let background: Color
    let gridBackground: Color
    let accent: Color
    let primaryText: Color
    let secondaryText: Color
    let error: Color
    let success: Color
    let cardBackground: Color
    let gridLine: Color
    let selection: Color
    let dimOverlayOpacity: Double

    var isSleep: Bool { theme == .sleep }
    var numberPadDisabledBackground: Color { secondaryText.opacity(0.25) }
    var numberPadDisabledText: Color { secondaryText.opacity(0.8) }
    var sameNumberHighlight: Color {
        switch theme {
        case .light:
            return accent.opacity(0.18)
        case .dark:
            return accent.opacity(0.24)
        case .sleep:
            return accent.opacity(0.28)
        case .system:
            // system maps to light in our palette
            return ThemeColors.forTheme(.light).accent.opacity(0.18)
        }
    }
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
                primaryText: Color(red: 0.1, green: 0.1, blue: 0.12),
                secondaryText: Color.gray.opacity(0.8),
                error: .appErrorRed,
                success: .appSuccessGreen,
                cardBackground: .white,
                gridLine: .black,
                selection: Color.appAccentAmber.opacity(0.15),
                dimOverlayOpacity: 0
            )
        case .dark:
            return ThemeColors(
                theme: theme,
                background: .appBackgroundDark,
                gridBackground: .appCardBackground,
                accent: .appAccentAmber,
                primaryText: Color(red: 0.92, green: 0.9, blue: 0.86),
                secondaryText: Color(red: 0.68, green: 0.7, blue: 0.74),
                error: .appErrorRed,
                success: .appSuccessGreen,
                cardBackground: .appCardBackground,
                gridLine: .white,
                selection: Color.white.opacity(0.1),
                dimOverlayOpacity: 0
            )
        case .sleep:
            return ThemeColors(
                theme: theme,
                background: .appBackgroundDark,
                gridBackground: .appCardBackground,
                accent: .appAccentOrange,
                primaryText: Color(red: 0.9, green: 0.85, blue: 0.78),
                secondaryText: Color(red: 0.68, green: 0.7, blue: 0.74),
                error: .appErrorRed,
                success: .appSuccessGreen,
                cardBackground: .appCardBackground,
                gridLine: Color.appAccentOrange.opacity(0.55),
                selection: Color.appAccentOrange.opacity(0.22),
                dimOverlayOpacity: 0.35
            )
        }
    }
}

struct ThemeManager {
    let settings: Settings

    var colors: ThemeColors { ThemeColors.forTheme(settings.themeEffective) }
}
