import SwiftUI

// The PureSudoku 2 colour model (CODESPEC 7.2, 11). Ported from Design/v2/ui_kits/puresudoku-2/night.js.

/// The player's choice (CODESPEC 11.3). Night after dark is a separate switch (`Settings.nightAfterDark`).
enum Appearance: String, Codable, CaseIterable, Identifiable {
    case light, dark, night
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// What the app draws right now (CODESPEC 7.1): Light (`.day`), Dark, or Night. Only Night brings the
/// bedtime behaviour (backlight, Drift, first night, silence).
enum Look: Equatable {
    case day, dark, night
}

enum Clarity: Int, Codable, CaseIterable, Identifiable {
    case standard = 0, large = 1, bold = 2
    var id: Int { rawValue }
    var displayName: String { ["Standard", "Large", "Bold"][rawValue] }
}

/// Size and weight scale driven by Clarity (CODESPEC 7.2). Applies in every theme.
struct PSType: Equatable {
    /// × (cell side · 0.62)
    let digitScale: CGFloat
    /// Givens are 800 at every Clarity.
    let givenWeight: Font.Weight = .heavy
    /// shortcut: entries are 500 at every Clarity because the bundled Bricolage has only 500 and 800;
    /// ship the variable font to get the spec's 600 / 700 for Large and Bold.
    let userWeight: Font.Weight = .medium
    /// × (cell side · 0.24)
    let candidateScale: CGFloat
    /// Minor line = max(1, round(1·s)) pt; box line = 1 + round(s) pt.
    let lineScale: CGFloat
    /// Keypad digit = 28 pt × s.
    let uiScale: CGFloat

    init(_ clarity: Clarity) {
        switch clarity {
        case .standard: self.init(1.0, 1.0, 1.0, 1.0)
        case .large: self.init(1.1, 1.12, 1.5, 1.06)
        case .bold: self.init(1.2, 1.25, 2.0, 1.12)
        }
    }

    private init(_ digit: CGFloat, _ candidate: CGFloat, _ line: CGFloat, _ ui: CGFloat) {
        digitScale = digit
        candidateScale = candidate
        lineScale = line
        uiScale = ui
    }

    var minorLine: CGFloat { max(1, lineScale.rounded()) }
    var boxLine: CGFloat { 1 + lineScale.rounded() }
}

struct PSPalette: Equatable {
    var bg, surface, surface2, ink, ink2, ink3, accent, accentDim, line, lineMajor, hair, sel, peer, same, err, status: Color
    var isNight: Bool
    var kelvin: Int?
    /// Estimated % blue reduction against daylight white at full brightness (display only; say "about").
    var blueReduction: Int
    /// 0...1 luminance scale in use.
    var luminance: Double
    /// The neutral Dark theme for iPhone Dark mode (not Night). It follows the Day rules for fills.
    var isDark = false
    /// v3 roles (CODESPEC 7.2). `edge` outlines every surface (clear in Light and Dark); `btn*` is the
    /// primary button; `fill` the secondary button and segmented track; `focus` the hint-unit tint;
    /// `glass` floating controls; `segment` the selected segment; `pill` the selected tab.
    var edge = Color.clear
    var btnBg = Color.clear, btnInk = Color.clear, btnEdge = Color.clear
    var fill = Color.clear, fillEdge = Color.clear
    var focus = Color.clear
    var glass = Color.clear, glassEdge = Color.clear
    var segment = Color.clear, pill = Color.clear

    /// Same-digit cells are also ringed at Night, where fills alone are faint (CODESPEC 7.3). Light and
    /// Dark show them by weight (800) instead (CODESPEC 3.2).
    var ringsSameDigit: Bool { isNight }
}

/// sRGB with 0...255 channels.
struct RGB255: Equatable {
    let r: Double, g: Double, b: Double
}

enum Blackbody {
    /// Tanner Helland approximation.
    static func rgb(kelvin: Double) -> RGB255 {
        let t = kelvin / 100
        let r: Double, g: Double, b: Double
        if t <= 66 {
            r = 255
            g = 99.4708025861 * log(t) - 161.1195681661
        } else {
            r = 329.698727446 * pow(t - 60, -0.1332047592)
            g = 288.1221695283 * pow(t - 60, -0.0755148492)
        }
        if t >= 66 {
            b = 255
        } else if t <= 19 {
            b = 0
        } else {
            b = 138.5177312231 * log(t - 10) - 305.0447927307
        }
        func clamp(_ v: Double) -> Double { min(255, max(0, v)) }
        return RGB255(r: clamp(r), g: clamp(g), b: clamp(b))
    }

    /// Warmth 0...100 → Kelvin 6500...1200, interpolated in mireds (perceptually even), rounded to 50 K.
    static func kelvin(forWarmth warmth: Double) -> Double {
        let m0 = 1e6 / 6500, m1 = 1e6 / 1200
        let k = 1e6 / (m0 + (m1 - m0) * min(100, max(0, warmth)) / 100)
        return (k / 50).rounded() * 50
    }
}

extension PSPalette {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: 1)
    }

    static func hex(_ v: UInt32, _ opacity: Double) -> Color {
        hex(v).opacity(opacity)
    }

    /// Light (CODESPEC 7.2): iOS grouped grey ground, white surfaces, black ink, one teal accent.
    static func day(clarity: Clarity) -> PSPalette {
        PSPalette(
            bg: hex(0xF2F2F7), surface: hex(0xFFFFFF), surface2: hex(0xE5E5EA),
            ink: hex(0x000000), ink2: hex(0x63636A), ink3: hex(0x63636A),
            accent: hex(0x007580), accentDim: hex(0x7FBAC0),
            line: clarity == .standard ? hex(0xD4D4DA) : hex(0xBCBCC2), lineMajor: hex(0x3A3A3C), hair: hex(0xD4D4DA),
            // Cell fills are the teal focus tint at 10 / 14 / 20% over white.
            sel: hex(0xCCE5E7), peer: hex(0xE6F2F3), same: hex(0xDBEDEF), err: hex(0xC4281C), status: hex(0x000000),
            isNight: false, kelvin: nil, blueReduction: 0, luminance: 1,
            btnBg: hex(0x007580), btnInk: hex(0xFFFFFF),
            fill: hex(0x767680, 0.14),
            focus: hex(0x007C89, 0.10),
            glass: hex(0xFFFFFF, 0.62), glassEdge: hex(0xFFFFFF, 0.90),
            segment: hex(0xFFFFFF), pill: hex(0x000000, 0.07)
        )
    }

    /// Dark (CODESPEC 7.2): black ground, near-black surfaces, light ink, a cyan accent. Text keeps 4.5:1 on
    /// the background, cards and every cell fill; marks and rings keep 3:1. Increase Contrast lifts lines
    /// and secondary text.
    static func dark(clarity: Clarity, increaseContrast: Bool = false) -> PSPalette {
        let strong = clarity != .standard || increaseContrast
        let ink2 = increaseContrast ? hex(0xC7C7CC) : hex(0xA1A1AA)
        return PSPalette(
            bg: hex(0x000000), surface: hex(0x151517), surface2: hex(0x2C2C2E),
            ink: hex(0xF2F2F7), ink2: ink2, ink3: ink2,
            accent: hex(0x5AD4E6), accentDim: hex(0x2D6A73),
            // Lines stay lighter than every cell fill, the focus tint included (#1E2E32 over the board).
            line: strong ? hex(0x545458) : hex(0x48484A), lineMajor: increaseContrast ? hex(0xA1A1AA) : hex(0x7C7C82),
            hair: increaseContrast ? hex(0x3A3A3C) : hex(0x2C2C2E),
            // Cell fills are the accent at 10 / 17 / 24% over black.
            sel: hex(0x163337), peer: hex(0x0A1719), same: hex(0x0F2427), err: hex(0xFF6B5E), status: hex(0xF2F2F7),
            isNight: false, kelvin: nil, blueReduction: 0, luminance: 1, isDark: true,
            btnBg: hex(0x5AD4E6), btnInk: hex(0x00262B),
            fill: hex(0x767680, 0.30),
            focus: hex(0x5AD4E6, 0.13),
            glass: hex(0x48484E, 0.50), glassEdge: hex(0xFFFFFF, 0.16),
            segment: hex(0x636366), pill: hex(0xFFFFFF, 0.12)
        )
    }

    /// Glow at which the palette reaches full strength; above it, glow raises the screen backlight
    /// (CODESPEC 11.3).
    static let paletteGlowRange: Double = 40

    /// Screen brightness (0...1) for a Night glow: the hardware minimum up to `paletteGlowRange`,
    /// then a straight ramp to 0.6 at glow 100.
    static func backlight(glow: Double) -> CGFloat {
        CGFloat(0.6 * max(0, min(100, glow) - paletteGlowRange) / (100 - paletteGlowRange))
    }

    /// glow, warmth: 0...100. The canvas is always pure black (OLED pixels off).
    static func night(glow: Double, warmth: Double, clarity: Clarity) -> PSPalette {
        let kelvin = Blackbody.kelvin(forWarmth: warmth)
        let base = Blackbody.rgb(kelvin: kelvin)
        let acc = Blackbody.rgb(kelvin: Blackbody.kelvin(forWarmth: min(100, warmth * 0.55 + 52)))
        let floor = [0.20, 0.30, 0.38][clarity.rawValue]
        let s = floor + (1 - floor) * pow(min(1, max(0, glow) / paletteGlowRange), 0.9)
        let lift = [1.0, 1.25, 1.5][clarity.rawValue]
        func mul(_ c: RGB255, _ k: Double) -> Color {
            // Round to whole channels like the CSS snapshots, so tests and the prototype agree.
            func channel(_ v: Double) -> Double { min(255, v * k).rounded() / 255 }
            return Color(.sRGB, red: channel(c.r), green: channel(c.g), blue: channel(c.b), opacity: 1)
        }
        let errColor = RGB255(r: 255, g: 70, b: 64)
        // v3 levels (CODESPEC 7.2), adjusted to keep contrast: ink2 0.85 (3:1 on the selected cell), line 0.30
        // (v2's value: it shows against the kept v2 cell fills) and lineMajor 0.60 (the table's 0.42 falls below 3:1 on black).
        let edge = mul(base, s * 0.25)
        let accentDim = mul(acc, s * 0.65)
        return PSPalette(
            // No lit fill behind text: surfaces are black and drawn by their `edge` outline.
            bg: .black, surface: .black, surface2: .black,
            ink: mul(base, s), ink2: mul(base, s * 0.85), ink3: mul(base, s * 0.78),
            accent: mul(acc, s * 0.96), accentDim: accentDim,
            line: mul(base, s * 0.30 * lift), lineMajor: mul(base, s * 0.60 * lift), hair: edge,
            // Fills step plain < peer < same < sel (all accent, so the steps hold at any warmth), peer stays below line, and every cell mark keeps 3:1 on its
            // fill at full strength (CODESPEC 7.2, issue #93).
            sel: mul(acc, s * 0.33), peer: mul(acc, s * 0.17), same: mul(acc, s * 0.25),
            err: mul(errColor, s * 0.95), status: mul(base, s * 0.44),
            isNight: true, kelvin: Int(kelvin),
            blueReduction: Int(((1 - (base.b / 255) * s) * 100).rounded()), luminance: s,
            edge: edge, btnInk: mul(acc, s * 0.96), btnEdge: accentDim, fillEdge: edge,
            focus: mul(base, s * 0.08), glassEdge: edge
        )
    }
}

/// Presets shown as chips in the Night sheet and on Display & Night.
enum NightPreset: String, CaseIterable, Identifiable {
    case readingLamp, lightsOut, redLight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .readingLamp: return "Reading lamp"
        case .lightsOut: return "Lights out"
        case .redLight: return "Red light"
        }
    }
    var glow: Double {
        switch self {
        case .readingLamp: return 70
        case .lightsOut: return 55
        case .redLight: return 30
        }
    }
    var warmth: Double {
        switch self {
        case .readingLamp: return 45
        case .lightsOut: return 55
        case .redLight: return 100
        }
    }
}

private struct PSPaletteKey: EnvironmentKey {
    static let defaultValue = PSPalette.day(clarity: .standard)
}

private struct PSTypeKey: EnvironmentKey {
    static let defaultValue = PSType(.standard)
}

extension EnvironmentValues {
    var psPalette: PSPalette {
        get { self[PSPaletteKey.self] }
        set { self[PSPaletteKey.self] = newValue }
    }

    var psType: PSType {
        get { self[PSTypeKey.self] }
        set { self[PSTypeKey.self] = newValue }
    }
}
