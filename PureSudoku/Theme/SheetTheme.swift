import SwiftUI

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

extension View {
    func themedTitle(_ title: String) -> some View {
        modifier(ThemedTitle(title: title))
    }
}
