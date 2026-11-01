import SwiftUI

/// Gives sheets the same look as the screen behind them: colour scheme, the warm Sleep palette when
/// Sleep/Bedtime is active, and the bedtime dimming overlay (sheets sit above the root overlay).
struct SheetTheme: ViewModifier {
    let settings: Settings
    let overlayOpacity: Double

    func body(content: Content) -> some View {
        let theme = settings.themeColors
        let isSleep = settings.themeEffective == .sleep
        content
            .scrollContentBackground(isSleep ? .hidden : .automatic)
            .background(isSleep ? theme.background.ignoresSafeArea() : nil)
            .foregroundColor(isSleep ? theme.primaryText : nil)
            .tint(theme.accent)
            .environment(\.sleepRowBackground, isSleep ? theme.cardBackground : nil)
            .preferredColorScheme(settings.preferredColorScheme)
            .overlay(SleepDimmingOverlay(opacity: overlayOpacity).ignoresSafeArea())
    }
}

private struct SleepRowBackgroundKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// Row background for Form/List sections while the Sleep palette is active; nil keeps the system look.
    var sleepRowBackground: Color? {
        get { self[SleepRowBackgroundKey.self] }
        set { self[SleepRowBackgroundKey.self] = newValue }
    }
}

/// Applies the Sleep row background to a Form/List section when one is set.
struct SleepRowBackground: ViewModifier {
    @Environment(\.sleepRowBackground) private var background

    func body(content: Content) -> some View {
        content.listRowBackground(background)
    }
}

extension View {
    func sheetTheme(_ controller: AppController) -> some View {
        modifier(SheetTheme(settings: controller.settings, overlayOpacity: controller.sleepOverlayOpacity))
    }

    func sleepRowBackground() -> some View {
        modifier(SleepRowBackground())
    }
}
