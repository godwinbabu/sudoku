// Reference only. Adapt these values into the app's existing theme layer;
// do not add this file as a second, parallel theme system.
// Values match design_handoff_v3/tokens.json.

import SwiftUI

struct V3Palette {
    let bg, surface, edge: Color
    let ink, ink2, accent: Color
    let btnBg, btnInk, btnEdge: Color
    let fill, fillEdge: Color
    let line, lineMajor, focus, err: Color
    let glass, glassEdge, pill: Color

    static let light = V3Palette(
        bg: Color(hex: 0xF2F2F7), surface: Color(hex: 0xFFFFFF), edge: .clear,
        ink: Color(hex: 0x000000), ink2: Color(hex: 0x63636A), accent: Color(hex: 0x007580),
        btnBg: Color(hex: 0x007580), btnInk: Color(hex: 0xFFFFFF), btnEdge: .clear,
        fill: Color(hex: 0x767680, opacity: 0.14), fillEdge: .clear,
        line: Color(hex: 0xD4D4DA), lineMajor: Color(hex: 0x3A3A3C),
        focus: Color(hex: 0x007C89, opacity: 0.10), err: Color(hex: 0xC4281C),
        glass: Color(hex: 0xFFFFFF, opacity: 0.62), glassEdge: Color(hex: 0xFFFFFF, opacity: 0.90),
        pill: Color(hex: 0x000000, opacity: 0.07))

    static let dark = V3Palette(
        bg: Color(hex: 0x000000), surface: Color(hex: 0x151517), edge: .clear,
        ink: Color(hex: 0xF2F2F7), ink2: Color(hex: 0xA1A1AA), accent: Color(hex: 0x5AD4E6),
        btnBg: Color(hex: 0x5AD4E6), btnInk: Color(hex: 0x00262B), btnEdge: .clear,
        fill: Color(hex: 0x767680, opacity: 0.30), fillEdge: .clear,
        line: Color(hex: 0x2C2C2E), lineMajor: Color(hex: 0x7C7C82),
        focus: Color(hex: 0x5AD4E6, opacity: 0.13), err: Color(hex: 0xFF6B5E),
        glass: Color(hex: 0x48484E, opacity: 0.50), glassEdge: Color(hex: 0xFFFFFF, opacity: 0.16),
        pill: Color(hex: 0xFFFFFF, opacity: 0.12))

    /// One snapshot of Night (the default preset). The shipping palette is
    /// computed from glow, warmth and clarity; see CODESPEC 7.2.
    static let nightSnapshot = V3Palette(
        bg: Color(hex: 0x000000), surface: Color(hex: 0x000000), edge: Color(hex: 0x3A2410),
        ink: Color(hex: 0xD08A3C), ink2: Color(hex: 0xA56A2E), accent: Color(hex: 0xD9602B),
        btnBg: .clear, btnInk: Color(hex: 0xD9602B), btnEdge: Color(hex: 0x8A3F1C),
        fill: .clear, fillEdge: Color(hex: 0x3A2410),
        line: Color(hex: 0x24160A), lineMajor: Color(hex: 0x80522A),
        focus: Color(hex: 0x140A02), err: Color(hex: 0xE0483A),
        glass: .clear, glassEdge: Color(hex: 0x3A2410),
        pill: .clear)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum V3Metric {
    static let sidePadding: CGFloat = 16
    static let boardInset: CGFloat = 6        // board width = screen width - 12
    static let ringRadius: CGFloat = 9
    static let boardRadius: CGFloat = 12
    static let cardRadius: CGFloat = 22
    static let groupRadius: CGFloat = 26
    static let tabBarHeight: CGFloat = 62
    static let tabBarInset: CGFloat = 21
    static let toolBarHeight: CGFloat = 52
    static let keypadHeight: CGFloat = 64
    static let bottomControlsInset: CGFloat = 12
    static let hitMin: CGFloat = 44
}
