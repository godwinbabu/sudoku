import SwiftUI

/// The hint card (CODESPEC 6.3.1, 3.2). It fills the reserved hint slot, so nothing under the
/// board moves. Three free steps — Where, Which, Why — then one action; nothing advances on its own
/// (CODESPEC 11.4).
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The room the text gets inside the slot: the slot − 26 padding − 26 top row − 44 footer − its 4 pt
    /// gap − 2 × 4 spacing.
    static let bodyHeight: CGFloat = GameView.hintSlotHeight - 108
    static let lineSpacing: CGFloat = 1
    static let bodySize: CGFloat = 15
    static let smallBodySize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The top row stops at xxLarge and the footer keeps its size, so the text gets the room (CODESPEC 9).
            topRow
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            // Full size, then one size smaller; text that still doesn't fit scrolls, never truncates.
            // At accessibility sizes the slot is flexible, and ViewThatFits there can hang layout.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { bodyText(size: Self.bodySize) }
                } else {
                    ViewThatFits(in: .vertical) {
                        bodyText(size: Self.bodySize)
                        bodyText(size: Self.smallBodySize)
                        ScrollView { bodyText(size: Self.smallBodySize) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
                .padding(.top, 4)
                .dynamicTypeSize(...DynamicTypeSize.large)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .psCard(theme)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hintPanel")
        // Each new step is read out, as lesson steps are.
        .onChangeOf(session.level) { _ in
            UIAccessibility.post(notification: .announcement, argument: session.accessibilityText(names))
        }
    }

    private func bodyText(size: CGFloat) -> some View {
        Text(session.text(names))
            .psFont(size)
            .lineSpacing(Self.lineSpacing)
            .foregroundStyle(theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(session.accessibilityText(names))
            .accessibilityIdentifier("hintText")
    }

    /// The technique name (or the step, before it is named) and "Hint · N of 3".
    private var topRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(session.title ?? session.stepLabel)
                .psFont(21, weight: .heavy, design: .serif)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("hintStep")
                .accessibilityLabel("Step \(session.level) of \(HintSession.stepCount): \(session.title ?? session.stepLabel)")
            Spacer(minLength: 0)
            Text("Hint · \(session.level) of \(HintSession.stepCount)")
                .psFont(13, weight: .medium)
                .foregroundStyle(theme.ink2)
                .fixedSize()
                .accessibilityHidden(true) // the step label above already says it
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .psFont(13, weight: .semibold)
                    .foregroundStyle(theme.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -12) // a 44 pt target that takes no more room than the row
            .padding(.trailing, -12)
            .accessibilityLabel("Close hint")
            .accessibilityIdentifier("hint_close")
        }
        .frame(minHeight: 26)
    }

    /// Steps 1 and 2: one Next button (with All patterns at step 1). Step 3: Lesson and the action.
    private var footer: some View {
        HStack(spacing: 8) {
            if session.level == HintSession.stepCount, let technique = session.lessonTechnique {
                Button("Lesson") { onLesson(technique) }
                    .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost))
                    .frame(width: 104)
                    .accessibilityShowsLargeContentViewer()
                    .accessibilityIdentifier("hint_lesson")
            } else if session.level == 1, session.step != nil, let onCoach {
                Button("All patterns", action: onCoach)
                    .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost))
                    .fixedSize()
                    .accessibilityIdentifier("hint_coach")
            }
            if session.canGoNext, let label = session.actionLabel {
                primary(label, id: "hint_next", action: onNext)
            } else if session.canApply, let label = session.actionLabel {
                primary(label, id: "hint_apply", action: onApply)
            } else if session.offersUndo, let onUndo {
                primary("Undo", id: "hint_undo", action: onUndo)
            }
        }
        .frame(height: 44)
    }

    private func primary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(PSButtonStyle(theme: theme))
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier(id)
    }
}

/// Content cards (CODESPEC 7.2): `surface` with 22 pt corners and a 1 pt `edge` outline (black with only
/// the outline at night).
extension View {
    func psCard(_ theme: PSPalette, radius: CGFloat = 22) -> some View {
        background(RoundedRectangle(cornerRadius: radius).fill(theme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(theme.edge, lineWidth: 1))
    }
}
