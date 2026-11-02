import SwiftUI

extension Settings {
    /// The palette for the current look (CODESPEC 7.2). Increase Contrast raises the Night floor
    /// and line lift to the Bold level; digit sizes still follow the player's Clarity.
    func palette(isNight: Bool, increaseContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled) -> PSPalette {
        guard isNight else { return .day(clarity: clarity) }
        return .night(glow: glow, warmth: warmth, clarity: increaseContrast ? .bold : clarity)
    }

    func isNight(systemIsDark: Bool, now: Date = Date()) -> Bool {
        isNight(now: now, systemIsDark: systemIsDark)
    }

    /// Match iPhone leaves the colour scheme to iOS; the other choices pin it.
    func preferredColorScheme(isNight: Bool) -> ColorScheme? {
        appearance == .matchSystem ? nil : (isNight ? .dark : .light)
    }
}
