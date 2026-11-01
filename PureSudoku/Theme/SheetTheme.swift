import SwiftUI

/// Gives sheets the same look as the screen behind them: colour scheme, the warm Sleep palette when
/// Sleep/Bedtime is active.
struct SheetTheme: ViewModifier {
    let settings: Settings

    func body(content: Content) -> some View {
        let theme = settings.themeColors
        let isSleep = settings.themeEffective == .sleep
        content
            .scrollContentBackground(isSleep ? .hidden : .automatic)
            .background(isSleep ? theme.background.ignoresSafeArea() : nil)
            .foregroundColor(isSleep ? theme.primaryText : nil)
            .tint(theme.accent)
            .environment(\.sleepRowBackground, isSleep ? theme.cardBackground : nil)
            .environment(\.sleepTitleColor, isSleep ? theme.primaryText : nil)
            .preferredColorScheme(settings.preferredColorScheme)
    }
}

private struct SleepRowBackgroundKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private struct SleepTitleColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

/// Draws the navigation title in the Sleep palette when one is set; UIKit bars created before Sleep
/// turned on would otherwise keep a white title (CODESPEC 12.4).
struct ThemedTitle: ViewModifier {
    let title: String
    @Environment(\.sleepTitleColor) private var color

    func body(content: Content) -> some View {
        if let color {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(title).font(.headline).foregroundColor(color)
                    }
                }
        } else {
            content.navigationTitle(title)
        }
    }
}

extension EnvironmentValues {
    /// Title color while the Sleep palette is active; nil keeps the system look.
    var sleepTitleColor: Color? {
        get { self[SleepTitleColorKey.self] }
        set { self[SleepTitleColorKey.self] = newValue }
    }

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
        modifier(SheetTheme(settings: controller.settings))
    }

    func themedTitle(_ title: String) -> some View {
        modifier(ThemedTitle(title: title))
    }

    func sleepRowBackground() -> some View {
        modifier(SleepRowBackground())
    }
}
