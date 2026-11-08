import SwiftUI

/// The hint card (CODESPEC 6.3.1). It fills the fixed 124 pt hint slot, so nothing under the board
/// moves. Three free steps, then one action; nothing advances on its own (CODESPEC 12.4).
struct HintCardView: View {
    let session: HintSession
    let names: CellNotation
    let theme: PSPalette
    let onNext: () -> Void
    let onApply: () -> Void
    /// Undo for entries that clash (imports); nil hides the button.
    let onUndo: (() -> Void)?
    let onLesson: (Technique) -> Void
    /// Opens the coach on this board; shown at step 1 of a technique hint.
    var onCoach: (() -> Void)?
    let onClose: () -> Void

    /// Text sizes and the room the text gets inside the 124 pt slot: 124 − 24 padding − 20 top row
    /// − 34 footer − 2 × 4 spacing.
    static let bodyHeight: CGFloat = 38
    static let lineSpacing: CGFloat = 2
    static let bodySize: CGFloat = 14
    static let smallBodySize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            topRow
            // Full size, then one size smaller; text that still doesn't fit scrolls, never truncates.
            ViewThatFits(in: .vertical) {
                bodyText(size: session.level == 1 ? 16 : Self.bodySize)
                bodyText(size: Self.smallBodySize)
                ScrollView { bodyText(size: Self.smallBodySize) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Night: no lit fill behind text, only the hairline (CODESPEC 7.2).
        .background(RoundedRectangle(cornerRadius: 18).fill(theme.isNight ? Color.clear : theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.hair, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hintPanel")
    }

    private func bodyText(size: CGFloat) -> some View {
        Text(session.text(names))
            .font(.system(size: size))
            .lineSpacing(Self.lineSpacing)
            .foregroundColor(session.level == 1 ? theme.ink : theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(session.accessibilityText(names))
            .accessibilityIdentifier("hintText")
    }

    /// Pills, the step label, and the tier. At step 2 the technique name takes the label's place,
    /// so the definition below gets two full lines.
    private var topRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...HintSession.stepCount, id: \.self) { step in
                    Capsule()
                        .fill(step <= session.level ? theme.accent : theme.hair)
                        .frame(width: step == session.level ? 14 : 5, height: 5)
                }
            }
            .accessibilityHidden(true)
            Group {
                if let title = session.title {
                    Text(title)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(session.stepLabel.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.9)
                        .foregroundColor(theme.ink3)
                }
            }
            .accessibilityIdentifier("hintStep")
            .accessibilityLabel("Step \(session.level) of \(HintSession.stepCount): \(session.title ?? session.stepLabel)")
            if let tier = session.tierLabel {
                Text("· \(tier)").font(.system(size: 11)).foregroundColor(theme.ink3).fixedSize()
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.ink3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-12) // a 44 pt target that takes no more room than the 20 pt row
            .accessibilityLabel("Close hint")
            .accessibilityIdentifier("hint_close")
        }
        .frame(height: 20)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let technique = session.lessonTechnique {
                Button("Lesson →") { onLesson(technique) }
                    .font(.system(size: 13))
                    .foregroundColor(theme.ink2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hint_lesson")
            } else if session.level == 1, session.step != nil, let onCoach {
                Button("All patterns →", action: onCoach)
                    .font(.system(size: 13))
                    .foregroundColor(theme.ink2)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hint_coach")
            }
            Spacer(minLength: 0)
            if session.canGoNext, let label = session.actionLabel {
                primary(label, id: "hint_next", action: onNext)
            } else if session.canApply, let label = session.actionLabel {
                primary(label, id: "hint_apply", action: onApply)
            } else if session.offersUndo, let onUndo {
                primary("Undo", id: "hint_undo", action: onUndo)
            }
        }
        .frame(height: 34)
    }

    private func primary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PSButtonStyle(theme: theme, height: 34))
            .accessibilityIdentifier(id)
    }
}
