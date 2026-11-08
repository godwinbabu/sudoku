import SwiftUI

/// The coach card (CODESPEC 6.3.3). Like the hint card it fills the fixed 124 pt slot, so nothing
/// under the board moves. One pattern at a time: its name and level, what it says about this board,
/// and a question; ‹ › walk through the others, "Show me" reveals the move.
struct CoachCardView: View {
    let session: CoachSession
    let names: CellNotation
    let theme: PSPalette
    let onBack: () -> Void
    let onForward: () -> Void
    let onDefinition: () -> Void
    let onReveal: () -> Void
    let onApply: () -> Void
    let onLesson: (Technique) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            topRow
            ViewThatFits(in: .vertical) {
                bodyText(size: HintCardView.bodySize)
                bodyText(size: HintCardView.smallBodySize)
                ScrollView { bodyText(size: HintCardView.smallBodySize) }
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
        .accessibilityIdentifier("coachPanel")
    }

    private func bodyText(size: CGFloat) -> some View {
        Text(session.text(names))
            .font(.system(size: size))
            .lineSpacing(HintCardView.lineSpacing)
            .foregroundColor(theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(session.accessibilityText(names))
            .accessibilityIdentifier("coachText")
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Text(session.title)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("coachTitle")
            Text("· \(session.tierLabel)").font(.system(size: 11)).foregroundColor(theme.ink2).fixedSize()
            Spacer(minLength: 0)
            Text(session.position)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.ink2)
                .fixedSize()
                .accessibilityLabel("Pattern \(session.position)")
                .accessibilityIdentifier("coachPosition")
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-12) // a 44 pt target that takes no more room than the 20 pt row
            .accessibilityLabel("Close coach")
            .accessibilityIdentifier("coach_close")
        }
        .frame(height: 20)
        .accessibilityElement(children: .contain)
    }

    private var footer: some View {
        HStack(spacing: 2) {
            pager("chevron.left", label: "Previous pattern", id: "coach_back", enabled: session.canGoBack, action: onBack)
            pager("chevron.right", label: "Next pattern", id: "coach_forward", enabled: session.canGoForward, action: onForward)
            if session.showsDefinition {
                link("Lesson →", id: "coach_lesson") { onLesson(session.current.technique) }
            } else {
                link("What is it?", id: "coach_definition", action: onDefinition)
            }
            Spacer(minLength: 0)
            if session.revealed, let label = session.hint.actionLabel {
                Button(label, action: onApply)
                    .buttonStyle(PSButtonStyle(theme: theme, height: 34))
                    .accessibilityIdentifier("coach_apply")
            } else if !session.revealed {
                Button("Show me", action: onReveal)
                    .buttonStyle(PSButtonStyle(theme: theme, height: 34))
                    .accessibilityIdentifier("coach_reveal")
            }
        }
        .frame(height: 34)
    }

    private func pager(_ symbol: String, label: String, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.ink2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 34)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func link(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13))
            .foregroundColor(theme.ink2)
            .frame(minHeight: 44)
            .padding(.leading, 6)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .frame(height: 34)
            .accessibilityIdentifier(id)
    }
}
