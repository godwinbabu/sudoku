import SwiftUI

struct ThemePalette {
    let background: Color
    let tile: Color
    let gridLine: Color
    let givenText: Color
    let entryText: Color
    let candidateText: Color
    let accent: Color
    let selection: Color
    let error: Color

    static func palette(for settings: Settings) -> ThemePalette {
        switch settings.themeEffective {
        case .light:
            return ThemePalette(
                background: Color(.systemBackground),
                tile: Color(.secondarySystemBackground),
                gridLine: Color(.systemGray4),
                givenText: .primary,
                entryText: .blue,
                candidateText: .secondary,
                accent: .blue,
                selection: Color(.systemGray5),
                error: .red
            )
        case .dark:
            return ThemePalette(
                background: Color(.black),
                tile: Color(.darkGray),
                gridLine: Color(.lightGray),
                givenText: .white,
                entryText: .cyan,
                candidateText: Color(.lightGray),
                accent: .cyan,
                selection: Color.white.opacity(0.1),
                error: Color.red.opacity(0.9)
            )
        case .sleep:
            return ThemePalette(
                background: Color(red: 0.05, green: 0.04, blue: 0.02),
                tile: Color(red: 0.12, green: 0.09, blue: 0.05),
                gridLine: Color(red: 0.4, green: 0.25, blue: 0.1),
                givenText: Color(red: 0.95, green: 0.8, blue: 0.6),
                entryText: Color(red: 0.98, green: 0.68, blue: 0.3),
                candidateText: Color(red: 0.8, green: 0.6, blue: 0.4),
                accent: Color(red: 0.98, green: 0.68, blue: 0.3),
                selection: Color(red: 0.25, green: 0.18, blue: 0.1),
                error: Color(red: 0.9, green: 0.3, blue: 0.3)
            )
        case .system:
            // degrade to system light/dark via environment; use neutral palette
            return ThemePalette(
                background: Color(.systemBackground),
                tile: Color(.secondarySystemBackground),
                gridLine: Color(.separator),
                givenText: .primary,
                entryText: .blue,
                candidateText: .secondary,
                accent: .blue,
                selection: Color(.systemGray5),
                error: .red
            )
        }
    }
}

struct SleepDimmingOverlay: View {
    let opacity: Double

    var body: some View {
        Color.black
            .opacity(opacity)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: opacity)
    }
}
