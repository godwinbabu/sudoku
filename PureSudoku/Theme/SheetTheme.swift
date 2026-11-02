import SwiftUI

/// Gives sheets the same palette as the screen behind them (CODESPEC 12.4): `bg` canvas, `ink` text,
/// `surface` rows in Night, so no system-white fill shows at night.
struct SheetTheme: ViewModifier {
    @Environment(\.psPalette) private var palette
    let colorScheme: ColorScheme?

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(palette.bg.ignoresSafeArea())
            .foregroundColor(palette.ink)
            .tint(palette.accent)
            .preferredColorScheme(colorScheme)
    }
}

/// Draws the navigation title in `ink`; UIKit bars created earlier would otherwise keep the
/// system title colour (CODESPEC 12.4).
struct ThemedTitle: ViewModifier {
    let title: String
    @Environment(\.psPalette) private var palette

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline).foregroundColor(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

/// Form/List row background from the palette.
struct PaletteRowBackground: ViewModifier {
    @Environment(\.psPalette) private var palette

    func body(content: Content) -> some View {
        content.listRowBackground(palette.surface)
    }
}

extension View {
    func sheetTheme(_ controller: AppController) -> some View {
        modifier(SheetTheme(colorScheme: controller.preferredColorScheme))
    }

    func themedTitle(_ title: String) -> some View {
        modifier(ThemedTitle(title: title))
    }

    func paletteRowBackground() -> some View {
        modifier(PaletteRowBackground())
    }
}
