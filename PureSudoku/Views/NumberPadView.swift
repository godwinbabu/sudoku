import SwiftUI

/// The 1×9 keypad (CODESPEC 3.2). Each key is its digit (Bricolage 800, 28 pt × Clarity). A finished digit
/// fades to `ink2` and is disabled, except in Notes mode, where every key stays on. In Notes mode
/// the digits are a little smaller and each shows how many are left (`caption`, `ink2`)
/// under it; the game also outlines the row. Keys have no backgrounds of their own.
struct NumberPadView: View {
    let theme: PSPalette
    /// Digits left to place; nil hides the counts and keeps every key on (import review).
    var remaining: [Int: Int]?
    var isNotesMode = false
    var keyHeight: CGFloat = 64
    var onDigit: (Int) -> Void

    @Environment(\.psType) private var type

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { digit in
                let left = remaining?[digit]
                let isDone = left.map { $0 <= 0 } ?? false
                let isOff = isDone && !isNotesMode
                Button { onDigit(digit) } label: {
                    VStack(spacing: 0) {
                        Text("\(digit)")
                            .font(PSFont.fixed((isNotesMode ? 22 : 28) * type.uiScale, weight: .heavy).monospacedDigit())
                            .foregroundStyle(isOff ? theme.ink2 : theme.ink)
                            .frame(height: 29)
                        if remaining != nil && isNotesMode {
                            Text(isDone ? " " : "\(left ?? 0)")
                                .font(PSFont.fixed(11, weight: .semibold, display: false).monospacedDigit())
                                .foregroundStyle(theme.ink2)
                                .frame(height: 13)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: keyHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressFillStyle(theme: theme))
                .disabled(isOff)
                .accessibilityShowsLargeContentViewer { Text("\(digit)") } // fixed size so the keypad fits (CODESPEC 9)
                .accessibilityIdentifier("number_\(digit)")
                .accessibilityLabel("\(digit)")
                .accessibilityValue(left.map { isDone ? "none left" : "\($0) left" } ?? "")
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Pressed keys and tools fade briefly; nothing lights up, at night or by day (CODESPEC 3.2).
struct PressFillStyle: ButtonStyle {
    let theme: PSPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.5 : 1)
    }
}
