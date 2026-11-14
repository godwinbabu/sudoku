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

    /// Match iPhone leaves the colour scheme to iOS (Day or Dark), so a forced scheme never feeds back
    /// into the system setting it follows; the other choices pin it.
    func preferredColorScheme(look: Look) -> ColorScheme? {
        appearance == .matchSystem ? nil : (look == .night ? .dark : .light)
    }
}
