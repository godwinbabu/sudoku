import SwiftUI

/// The 1×9 keypad. Each key shows how many of its digit are left; a used-up digit fades and is
/// disabled. In Notes mode each key shows its digit small, at its pencil-mark position.
struct NumberPadView: View {
    let theme: PSPalette
    /// Digits left to place; nil hides the counts and keeps every key on (import review).
    var remaining: [Int: Int]?
    var isNotesMode = false
    var keyHeight: CGFloat = 64
    var onDigit: (Int) -> Void

    @Environment(\.psType) private var type

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...9, id: \.self) { digit in
                let left = remaining?[digit]
                let isDone = left.map { $0 <= 0 } ?? false
                Button { onDigit(digit) } label: {
                    VStack(spacing: 3) {
                        if isNotesMode {
                            notesFace(digit)
                        } else {
                            Text("\(digit)")
                                .font(.system(size: 30 * type.uiScale, weight: .regular).monospacedDigit())
                                .foregroundStyle(theme.ink)
                                .frame(height: 30)
                        }
                        if remaining != nil {
                            Text(isDone ? " " : "\(left ?? 0)")
                                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(theme.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: keyHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressFillStyle(theme: theme))
                .opacity(isDone ? 0.28 : 1)
                .disabled(isDone)
                .accessibilityShowsLargeContentViewer { Text("\(digit)") } // fixed size so the keypad fits (CODESPEC 9)
                .accessibilityIdentifier("number_\(digit)")
                .accessibilityLabel("\(digit)")
                .accessibilityValue(left.map { isDone ? "none left" : "\($0) left" } ?? "")
            }
        }
    }

    private func notesFace(_ digit: Int) -> some View {
        let row = (digit - 1) / 3, col = (digit - 1) % 3
        return Text("\(digit)")
            .font(.system(size: 13 * type.candidateScale, weight: .bold).monospacedDigit())
            .foregroundStyle(theme.accent)
            .frame(width: 10, height: 10)
            .offset(x: CGFloat(col - 1) * 10, y: CGFloat(row - 1) * 10)
            .frame(width: 30, height: 30)
    }
}

/// Pressed keys and tools get a `surface2` fill in Day; at night nothing lights up (CODESPEC 12).
struct PressFillStyle: ButtonStyle {
    let theme: PSPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isPressed && !theme.isNight ? theme.surface2 : .clear)
            )
    }
}
