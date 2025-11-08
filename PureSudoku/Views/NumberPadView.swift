import SwiftUI

struct NumberPadView: View {
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(disabledDigits.contains(digit) ? Color.gray.opacity(0.2) : Color.accentColor.opacity(0.15))
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
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 1))
            }
            .accessibilityIdentifier("number_clear")
        }
    }
}
