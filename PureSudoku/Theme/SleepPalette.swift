import SwiftUI

/// Sleep theme colors computed from a display profile (CODESPEC 7.2, 9, 12.3). No black overlay:
/// each element gets its own brightness, so small marks keep their floor while digits dim.
struct SleepPalette: Equatable {
    /// Relative luminance (0...1) of each element on the #000 background.
    struct Levels: Equatable {
        let digit: Double
        let candidate: Double
        let gridLine: Double
    }

    let levels: Levels
    /// Hue (sRGB, brightest channel = 1) from the warmth slider.
    let hue: RGB

    // MARK: Floors (CODESPEC 9)

    static let minimumDigit = 0.01
    static let candidateShare = 0.6
    static let gridLineShare = 0.4
    /// With Increase Contrast on: 4.5:1 for digits and 3:1 for lines and marks on black.
    static let accessibleDigit = 0.175
    static let accessibleMark = 0.10

    init(profile: DisplayProfile, increaseContrast: Bool = false) {
        let dimness = profile.dimness.clamped
        let contrast = profile.contrast.clamped
        let hue = Self.hue(warmth: profile.warmth.clamped)
        // Brightest Sleep digit is a soft 0.45 (about a 60% grey), dimmest is the floor. A warm hue
        // cannot get as bright as white, so the level is capped at what the hue can show.
        var digit = min(0.45 * pow(Self.minimumDigit / 0.45, dimness), hue.luminance)
        var candidate = digit * (Self.candidateShare + 0.3 * contrast)
        var gridLine = digit * (Self.gridLineShare + 0.3 * contrast)
        if increaseContrast {
            digit = max(digit, Self.accessibleDigit)
            candidate = max(candidate, Self.accessibleMark, digit * Self.candidateShare)
            gridLine = max(gridLine, Self.accessibleMark, digit * Self.gridLineShare)
        }
        levels = Levels(digit: digit, candidate: candidate, gridLine: gridLine)
        self.hue = hue
    }

    /// Neutral warm white → amber → orange-red. Never deep red (it reads as black to some players).
    static func hue(warmth: Double) -> RGB {
        let neutral = RGB(r: 1, g: 0.94, b: 0.86)
        let amber = RGB(r: 1, g: 0.72, b: 0.32)
        let orangeRed = RGB(r: 1, g: 0.48, b: 0.2)
        return warmth < 0.5 ? neutral.mix(amber, warmth * 2) : amber.mix(orangeRed, (warmth - 0.5) * 2)
    }

    /// `hue` scaled to the given relative luminance.
    func color(luminance: Double, hue: RGB? = nil) -> RGB {
        (hue ?? self.hue).scaled(toLuminance: luminance)
    }

    /// The exact colors the theme draws (tested against the floors).
    struct Rendered: Equatable {
        let digit: RGB
        let candidate: RGB
        let gridLine: RGB
        let accent: RGB
        let card: RGB
        /// Slider and switch knobs: clearly brighter than the accent-colored "on" track and the dark
        /// "off" track, so a switch's state stays visible (but far from white at dim settings).
        let knob: RGB
    }

    var rendered: Rendered {
        let accentLevel = levels.digit * 0.85
        let accent = color(luminance: accentLevel, hue: hue.mix(RGB(r: 1, g: 0.6, b: 0.2), 0.5))
        // A brighter knob when the hue allows it; on bright profiles, where the track is already
        // bright, a darker knob instead.
        let brighter = color(luminance: max(levels.digit * 3, 0.1))
        let knob = (brighter.luminance + 0.05) / (accent.luminance + 0.05) >= 1.6 ? brighter : color(luminance: accentLevel * 0.3)
        return Rendered(
            digit: color(luminance: levels.digit),
            candidate: color(luminance: levels.candidate),
            gridLine: color(luminance: levels.gridLine),
            accent: accent,
            card: color(luminance: max(levels.digit * 0.03, 0.0008)),
            knob: knob
        )
    }

    var themeColors: ThemeColors {
        let colors = rendered
        return ThemeColors(
            theme: .sleep,
            background: .black,
            gridBackground: colors.card.color,
            accent: colors.accent.color,
            primaryText: colors.digit.color,
            secondaryText: colors.candidate.color,
            error: colors.accent.color, // errors show by shape (CODESPEC 7.2), so color only needs to be visible
            success: colors.candidate.color,
            cardBackground: colors.card.color,
            gridLine: colors.gridLine.color,
            selection: colors.accent.color.opacity(0.25)
        )
    }

    /// Grid text size from the profile's text slider.
    static func typeSize(_ textSize: Double) -> DynamicTypeSize {
        switch textSize.clamped {
        case ..<0.2: return .small
        case ..<0.4: return .medium
        case ..<0.6: return .large
        case ..<0.8: return .xLarge
        default: return .xxLarge
        }
    }

    /// WCAG contrast ratio of a luminance against black.
    static func contrastOnBlack(_ luminance: Double) -> Double { (luminance + 0.05) / 0.05 }
}

/// sRGB color with 0...1 channels.
struct RGB: Equatable {
    let r: Double, g: Double, b: Double

    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    var luminance: Double { 0.2126 * Self.linear(r) + 0.7152 * Self.linear(g) + 0.0722 * Self.linear(b) }

    /// Same hue, scaled in linear light to reach `target` luminance (capped at full brightness).
    func scaled(toLuminance target: Double) -> RGB {
        let factor = luminance > 0 ? min(target / luminance, 1 / max(Self.linear(r), Self.linear(g), Self.linear(b))) : 0
        return RGB(r: Self.srgb(Self.linear(r) * factor), g: Self.srgb(Self.linear(g) * factor), b: Self.srgb(Self.linear(b) * factor))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    static func srgb(_ c: Double) -> Double { c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055 }
}

private extension Double {
    var clamped: Double { Swift.min(Swift.max(self, 0), 1) }
}
