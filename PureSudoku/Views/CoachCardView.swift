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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The top row stops at xxLarge and the footer keeps its size, so the text gets the room (CODESPEC 9).
            topRow
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            // At accessibility sizes the slot is flexible, and ViewThatFits there can hang layout.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { bodyText(size: HintCardView.bodySize) }
                } else {
                    ViewThatFits(in: .vertical) {
                        bodyText(size: HintCardView.bodySize)
                        bodyText(size: HintCardView.smallBodySize)
                        ScrollView { bodyText(size: HintCardView.smallBodySize) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
                .dynamicTypeSize(...DynamicTypeSize.large)
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
            .psFont(size)
            .lineSpacing(HintCardView.lineSpacing)
            .foregroundStyle(theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(session.accessibilityText(names))
            .accessibilityIdentifier("coachText")
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Text(session.title)
                .psFont(18, weight: .medium, design: .serif)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("coachTitle")
            Text("· \(session.tierLabel)").psFont(11).foregroundStyle(theme.ink2).fixedSize()
            Spacer(minLength: 0)
            Text(session.position)
                .psFont(11, weight: .semibold)
                .foregroundStyle(theme.ink2)
                .fixedSize()
                .accessibilityLabel("Pattern \(session.position)")
                .accessibilityIdentifier("coachPosition")
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .psFont(13, weight: .medium)
                    .foregroundStyle(theme.ink2)
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
            if session.showsDefinition { // the pagers make room for Back and Lesson on narrow phones
                link("Back", id: "coach_definition", action: onDefinition)
                link("Lesson →", id: "coach_lesson") { onLesson(session.current.technique) }
            } else {
                pager("chevron.left", label: "Previous pattern", id: "coach_back", enabled: session.canGoBack, action: onBack)
                pager("chevron.right", label: "Next pattern", id: "coach_forward", enabled: session.canGoForward, action: onForward)
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
                .psFont(15, weight: .medium)
                .foregroundStyle(theme.ink2)
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
            .psFont(13)
            .foregroundStyle(theme.ink2)
            .frame(minHeight: 44)
            .padding(.leading, 6)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .frame(height: 34)
            .accessibilityIdentifier(id)
    }
}
