import SwiftUI

/// The hint ladder panel (CODESPEC 6.3.1). Sits where the number pad is, so the grid stays visible.
/// Every step waits for a tap; nothing advances on its own (CODESPEC 12.4).
struct HintPanelView: View {
    let session: HintSession
    let names: CellNameStyle
    let theme: PSPalette
    let onBack: () -> Void
    let onNext: () -> Void
    let onShowResult: () -> Void
    let onApply: () -> Void
    let onToggleAfter: () -> Void
    let onReveal: () -> Void
    /// Undo from the mistake check (CODESPEC 6.3.1); nil hides the button.
    let onUndo: (() -> Void)?
    /// Opens the technique's lesson (first meeting, CODESPEC 13.5).
    let onLesson: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.title)
                    .font(.headline)
                    .foregroundColor(theme.ink)
                if let badge = session.badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(theme.accent, lineWidth: 1))
                        .foregroundColor(theme.accent)
                }
                Spacer()
                if session.step != nil {
                    Text("Step \(session.rung) of 4")
                        .font(.caption)
                        .foregroundColor(theme.ink2)
                }
            }
            Text(session.text(names))
                .font(.body)
                .foregroundColor(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("hintText")
            if session.canApply, session.step?.eliminations.isEmpty == false {
                Toggle("Show after", isOn: Binding(get: { session.showsAfter }, set: { _ in onToggleAfter() }))
                    .font(.footnote)
                    .foregroundColor(theme.ink2)
                    .tint(theme.accent)
                    .accessibilityIdentifier("hint_toggleAfter")
            }
            buttons
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.lineMajor.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hintPanel")
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            if session.canGoBack {
                panelButton("Back", id: "hint_back", action: onBack)
            }
            if session.isAskingBeforeResult {
                panelButton("I'll try", id: "hint_tryMyself", action: onDone)
                panelButton("Show answer", id: "hint_showResult", prominent: true, action: onShowResult)
            } else {
                if session.offersLesson {
                    panelButton("Lesson", id: "hint_lesson", action: onLesson)
                }
                if case .mistake = session.content, let onUndo {
                    panelButton("Undo", id: "hint_undo", action: onUndo)
                }
                if case .noStep(let cell) = session.content, cell != nil {
                    panelButton("Reveal cell", id: "hint_reveal", prominent: true, action: onReveal)
                }
                if session.canGoNext {
                    panelButton("Next", id: "hint_next", prominent: true, action: onNext)
                }
                if session.canApply {
                    panelButton("Apply", id: "hint_apply", prominent: true, action: onApply)
                }
                panelButton("Done", id: "hint_done", action: onDone)
            }
        }
    }

    private func panelButton(_ title: String, id: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(prominent ? theme.accent.opacity(0.22) : theme.accent.opacity(0.08))
                .foregroundColor(prominent ? theme.accent : theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
