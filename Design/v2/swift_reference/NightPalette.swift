// Reference implementation of the PureSudoku 2 colour model for SwiftUI.
// Mirrors ui_kits/puresudoku-2/night.js exactly. Adapt names to the codebase (it should
// replace Theme/AppColors.swift + Theme/ThemeColors.swift + Theme/SleepDimmingOverlay.swift).
import SwiftUI

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case day, night, afterDark, matchSystem
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .day: return "Day"
        case .night: return "Night"
        case .afterDark: return "After dark"
        case .matchSystem: return "Match iPhone"
        }
    }
}

enum Clarity: Int, Codable, CaseIterable, Identifiable {
    case standard = 0, large = 1, bold = 2
    var id: Int { rawValue }
    var displayName: String { ["Standard", "Large", "Bold"][rawValue] }
}

/// Size/weight scale driven by Clarity. Applies in Day and Night.
struct PSType {
    let digitScale: CGFloat      // × (cellSide · 0.6)
    let givenWeight: Font.Weight
    let userWeight: Font.Weight
    let candidateScale: CGFloat  // × (cellSide · 0.25)
    let lineScale: CGFloat       // minor line = max(1, round(1·s)) pt; box line = 1 + round(s) pt
    let uiScale: CGFloat         // keypad digit 30 pt × s

    init(_ c: Clarity) {
        switch c {
        case .standard: self = .init(1.0, .semibold, .regular, 1.0, 1.0, 1.0)
        case .large:    self = .init(1.1, .bold, .medium, 1.12, 1.5, 1.06)
        case .bold:     self = .init(1.2, .heavy, .semibold, 1.25, 2.0, 1.12)
        }
    }
    private init(_ d: CGFloat, _ g: Font.Weight, _ u: Font.Weight, _ cand: CGFloat, _ l: CGFloat, _ ui: CGFloat) {
        digitScale = d; givenWeight = g; userWeight = u; candidateScale = cand; lineScale = l; uiScale = ui
    }
}

struct PSPalette: Equatable {
    var bg, surface, surface2, ink, ink2, ink3, accent, accentDim, line, lineMajor, hair, sel, peer, same, err, status: Color
    /// Opacity for cells outside a hint/lesson spotlight.
    var focusDim: Double
    var isNight: Bool
    var kelvin: Int?
    /// Estimated % blue reduction vs. daylight white at full brightness (display only, say "about").
    var blueReduction: Int
    /// 0…1 luminance scale actually used (useful to drive UIScreen.brightness).
    var luminance: Double
}

enum Blackbody {
    /// Tanner Helland approximation. Returns 0…255 channels.
    static func rgb(kelvin k: Double) -> (r: Double, g: Double, b: Double) {
        let t = k / 100
        var r: Double, g: Double, b: Double
        if t <= 66 { r = 255; g = 99.4708025861 * log(t) - 161.1195681661 }
        else { r = 329.698727446 * pow(t - 60, -0.1332047592); g = 288.1221695283 * pow(t - 60, -0.0755148492) }
        if t >= 66 { b = 255 } else if t <= 19 { b = 0 } else { b = 138.5177312231 * log(t - 10) - 305.0447927307 }
        func c(_ v: Double) -> Double { min(255, max(0, v)) }
        return (c(r), c(g), c(b))
    }
    /// Warmth 0…100 → Kelvin 6500…1200, interpolated in mireds (perceptually even), rounded to 50 K.
    static func kelvin(forWarmth w: Double) -> Double {
        let m0 = 1e6 / 6500, m1 = 1e6 / 1200
        let k = 1e6 / (m0 + (m1 - m0) * min(100, max(0, w)) / 100)
        return (k / 50).rounded() * 50
    }
}

extension PSPalette {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: 1)
    }

    static func day(clarity: Clarity) -> PSPalette {
        PSPalette(bg: hex(0xF4F1E9), surface: hex(0xEBE6DA), surface2: hex(0xE2DCCD), ink: hex(0x1B1A17), ink2: hex(0x57534B), ink3: hex(0x8A857A),
                  accent: hex(0x9A5712), accentDim: hex(0xC9A27A), line: clarity == .standard ? hex(0xCFC8B8) : hex(0xB9B1A0), lineMajor: hex(0x2E2B25),
                  hair: hex(0xD8D1C1), sel: hex(0xEFD9B0), peer: hex(0xECE6D9), same: hex(0xF1E2C6), err: hex(0xB3261E), status: hex(0x1B1A17),
                  focusDim: 0.28, isNight: false, kelvin: nil, blueReduction: 0, luminance: 1)
    }

    /// glow, warmth: 0…100. Canvas is always pure black (OLED pixels off).
    static func night(glow: Double, warmth: Double, clarity: Clarity) -> PSPalette {
        let K = Blackbody.kelvin(forWarmth: warmth)
        let base = Blackbody.rgb(kelvin: K)
        let acc = Blackbody.rgb(kelvin: Blackbody.kelvin(forWarmth: min(100, warmth * 0.55 + 52)))
        let floor = [0.20, 0.30, 0.38][clarity.rawValue]
        let s = floor + (1 - floor) * pow(min(100, max(0, glow)) / 100, 1.15)
        let lift = [1.0, 1.25, 1.5][clarity.rawValue]
        func mul(_ c: (r: Double, g: Double, b: Double), _ k: Double) -> Color {
            Color(.sRGB, red: min(255, c.r * k) / 255, green: min(255, c.g * k) / 255, blue: min(255, c.b * k) / 255, opacity: 1)
        }
        let errc = (r: 255.0, g: 70.0, b: 64.0)
        return PSPalette(
            bg: .black, surface: mul(base, s * 0.07), surface2: mul(base, s * 0.11),
            ink: mul(base, s), ink2: mul(base, s * 0.70), ink3: mul(base, s * 0.50),
            accent: mul(acc, s * 0.96), accentDim: mul(acc, s * 0.50),
            line: mul(base, s * 0.17 * lift), lineMajor: mul(base, s * 0.42 * lift), hair: mul(base, s * 0.15),
            sel: mul(acc, s * 0.20), peer: mul(base, s * 0.055), same: mul(acc, s * 0.12), err: mul(errc, s * 0.95), status: mul(base, s * 0.44),
            focusDim: 0.22, isNight: true, kelvin: Int(K),
            blueReduction: Int(((1 - (base.b / 255) * s) * 100).rounded()), luminance: s)
    }
}

/// Presets shown as chips in the Night sheet and on Display & Night.
enum NightPreset: CaseIterable {
    case readingLamp, lightsOut, redLight
    var title: String { ["Reading lamp", "Lights out", "Red light"][index] }
    var glow: Double { [55, 18, 10][index] }
    var warmth: Double { [45, 75, 100][index] }
    private var index: Int { Self.allCases.firstIndex(of: self)! }
}
