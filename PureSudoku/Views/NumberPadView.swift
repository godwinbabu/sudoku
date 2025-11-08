import SwiftUI

struct NumberPadView: View {
    let theme: ThemeColors
    var disabledDigits: Set<Int>
    var onDigit: (Int) -> Void
    var onClear: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                Button(action: { onDigit(digit) }) {
                    Text("\(digit)")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(disabledDigits.contains(digit) ? theme.numberPadDisabledText : theme.primaryText)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(disabledDigits.contains(digit) ? theme.numberPadDisabledBackground : theme.accent.opacity(0.18))
                        )
                }
                .disabled(disabledDigits.contains(digit))
                .accessibilityIdentifier("number_\(digit)")
            }
            Button(action: onClear) {
                Text("Clear")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(theme.accent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.accent.opacity(0.7), lineWidth: 1)
                    )
            }
            .accessibilityIdentifier("number_clear")
        }
    }
}
