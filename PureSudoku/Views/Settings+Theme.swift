import SwiftUI

extension Settings {
    /// The palette for the current look (CODESPEC 7.2). Increase Contrast raises the Night floor
    /// and line lift to the Bold level; digit sizes still follow the player's Clarity.
    @MainActor func palette(look: Look, increaseContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled) -> PSPalette {
        switch look {
        case .day: return .day(clarity: clarity)
        case .dark: return .dark(clarity: clarity, increaseContrast: increaseContrast)
        case .night: return .night(glow: glow, warmth: warmth, clarity: increaseContrast ? .bold : clarity)
        }
    }

    @MainActor func palette(isNight: Bool, increaseContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled) -> PSPalette {
        palette(look: isNight ? .night : .day, increaseContrast: increaseContrast)
    }

    /// Light pins light, Dark and Night pin dark. Until the system style has been adopted, Light and Dark
    /// are left to iOS, so the app can read it without its own override feeding back.
    func preferredColorScheme(look: Look) -> ColorScheme? {
        if adoptsSystemStyle && look != .night { return nil }
        return look == .day ? .light : .dark
    }
}
