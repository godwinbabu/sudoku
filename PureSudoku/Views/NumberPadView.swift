import SwiftUI

struct NumberPadView: View {
    let theme: ThemeColors
    var disabledDigits: Set<Int>
    var isCandidateMode: Bool
    var onDigit: (Int) -> Void
    var onClear: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                let isDisabled = disabledDigits.contains(digit)
                Button(action: { onDigit(digit) }) {
                    Text("\(digit)")
                        .font(isCandidateMode ? .body.weight(.semibold) : .title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isCandidateMode ? 8 : 10)
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                        .foregroundColor(isDisabled ? theme.numberPadDisabledText : theme.primaryText)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDisabled ? theme.numberPadDisabledBackground : buttonBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCandidateMode ? theme.accent.opacity(0.6) : .clear, lineWidth: isCandidateMode ? 1 : 0)
                                )
                        )
                }
                .disabled(isDisabled)
                .accessibilityIdentifier("number_\(digit)")
            }
            Button(action: onClear) {
                Label("", systemImage: "delete.left")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(theme.accent)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.accent.opacity(0.7), lineWidth: 1)
                    )
            }
            .accessibilityIdentifier("number_clear")
        }
    }

    private var buttonBackground: Color {
        isCandidateMode ? theme.cardBackground : theme.accent.opacity(0.18)
    }
}
