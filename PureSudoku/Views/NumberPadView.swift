import SwiftUI

/// The 1×9 keypad (HANDOFF 6.2). Each key is its digit (Bricolage 800, 28 pt × Clarity) over how many are
/// left (`caption`, `ink2`). A finished digit fades to `ink2`, loses its count and is disabled. Keys have no
/// backgrounds of their own; the game puts the row on glass and outlines it in Notes mode.
struct NumberPadView: View {
    let theme: PSPalette
    /// Digits left to place; nil hides the counts and keeps every key on (import review).
    var remaining: [Int: Int]?
    var keyHeight: CGFloat = 64
    var onDigit: (Int) -> Void

    @Environment(\.psType) private var type

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { digit in
                let left = remaining?[digit]
                let isDone = left.map { $0 <= 0 } ?? false
                Button { onDigit(digit) } label: {
                    VStack(spacing: 0) {
                        Text("\(digit)")
                            .font(PSFont.fixed(28 * type.uiScale, weight: .heavy).monospacedDigit())
                            .foregroundStyle(isDone ? theme.ink2 : theme.ink)
                            .frame(height: 29)
                        if remaining != nil {
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
                .disabled(isDone)
                .accessibilityShowsLargeContentViewer { Text("\(digit)") } // fixed size so the keypad fits (CODESPEC 9)
                .accessibilityIdentifier("number_\(digit)")
                .accessibilityLabel("\(digit)")
                .accessibilityValue(left.map { isDone ? "none left" : "\($0) left" } ?? "")
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Pressed keys and tools fade briefly; nothing lights up, at night or by day (HANDOFF 6.2).
struct PressFillStyle: ButtonStyle {
    let theme: PSPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.5 : 1)
    }
}
