import SwiftUI
import UIKit

/// Primary and secondary buttons (HANDOFF 3, 6). Primary is a `btnBg` pill with `btnInk` text; at night
/// a 1.5 pt `btnEdge` outline, because nothing lit may sit behind text. Secondary (`.ghost`) is a `fill`
/// pill with `accent` text, outlined by `fillEdge` at night.
struct PSButtonStyle: ButtonStyle {
    enum Kind { case primary, ghost }
    let theme: PSPalette
    var kind = Kind.primary
    var height: CGFloat = 44
    /// Disabled buttons are a hair outline with ink3 text: at least 3:1 in Day, unlike a faded fill.
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let primary = kind == .primary
        let fontSize: CGFloat = height < 40 ? 14 : 15
        configuration.label
            .psFont(fontSize, weight: .bold)
            .multilineTextAlignment(.center)
            .padding(.horizontal, fontSize < 15 ? 14 : 18)
            .padding(.vertical, 6)
            // The capsule grows with its label (CODESPEC 9), so wrapped text stays inside it.
            .frame(minHeight: height)
            .foregroundStyle(!isEnabled ? theme.ink3 : primary ? theme.btnInk : theme.accent)
            .background(Capsule().fill(!isEnabled ? .clear : primary ? theme.btnBg : theme.fill))
            .overlay(
                Capsule().strokeBorder(!isEnabled ? theme.hair : primary ? theme.btnEdge : theme.fillEdge,
                                       lineWidth: primary && isEnabled ? 1.5 : 1)
            )
            // The target is at least 44 × 44 pt, even when the capsule is drawn smaller.
            .padding(.vertical, max(0, (44 - height) / 2))
            .frame(minWidth: 44)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// Glass for controls that float over content (HANDOFF 3): system Liquid Glass on iOS 26 and later,
/// a thin material with a `glassEdge` stroke and soft shadow before that. Night has no material at all:
/// black with the 1 pt outline; Reduce Transparency gives `surface` plus a stroke.
struct PSGlass<S: InsettableShape>: ViewModifier {
    let theme: PSPalette
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if theme.isNight {
            // Black, not clear: content scrolls under the tab bar. Black is no lit fill (HANDOFF 2).
            content.background(shape.fill(theme.bg)).overlay(shape.strokeBorder(theme.glassEdge, lineWidth: 1))
        } else if reduceTransparency {
            content
                .background(shape.fill(theme.surface))
                .overlay(shape.strokeBorder(theme.hair, lineWidth: 1))
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(theme.glassEdge, lineWidth: 1))
                .shadow(color: .black.opacity(theme.isDark ? 0.6 : 0.14), radius: 15, y: 10)
        }
    }
}

extension View {
    func psGlass<S: InsettableShape>(_ theme: PSPalette, in shape: S) -> some View {
        modifier(PSGlass(theme: theme, shape: shape))
    }
}

/// One of the four tools in the game's tool bar (HANDOFF 6.2): a 22 pt symbol over a `caption` label.
/// The active tool is `accent` with a heavier symbol and label; no chip behind it.
struct ToolButton: View {
    let theme: PSPalette
    let symbol: String
    let label: String
    var isActive = false
    /// What VoiceOver reads when it differs from the label (Notes reads "Notes", with On/Off as its value).
    var spokenLabel: String?
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .frame(height: 24)
                Text(label).font(PSFont.fixed(11, weight: isActive ? .bold : .medium, display: false))
            }
            .foregroundStyle(isActive ? theme.accent : theme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFillStyle(theme: theme))
        .accessibilityLabel(spokenLabel ?? label)
        .opacity(isEnabled ? 1 : 0.35)
        // Fixed size so the tool row fits; a long press shows it large (CODESPEC 9).
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: symbol) }
    }
}

/// A 44 pt header icon: plain, or on its own round glass (`round`) for navigation (HANDOFF 6.2).
struct HeaderIconButton: View {
    let theme: PSPalette
    let symbol: String
    let label: String
    var round = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: round ? .semibold : .regular))
                .foregroundStyle(round ? theme.ink : theme.ink2)
                .frame(width: round ? 44 : 40, height: round ? 44 : 40)
                .contentShape(Circle())
                .modifier(RoundGlass(theme: theme, isOn: round))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: symbol) }
    }
}

private struct RoundGlass: ViewModifier {
    let theme: PSPalette
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn { content.psGlass(theme, in: Circle()) } else { content }
    }
}

/// A custom popover card (the More menu and confirmations): surface2 in Day, black with a hair
/// border at night. Never a system menu or dialog, which
/// could render light at night (CODESPEC 12).
struct PopoverCard<Content: View>: View {
    let theme: PSPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            // At night the card is black, not lit, so it still hides the board behind it (CODESPEC 7.2).
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.isNight ? theme.bg : theme.surface2))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.hair, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            // VoiceOver stays inside the menu or confirmation, not on the board behind it.
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            // Sort after the board: XCUITest (and likely VoiceOver touch) picks tap points by accessibility
            // order, so a card sorted among the cells counts as under them. Real touches are unaffected.
            .accessibilitySortPriority(-1)
    }
}

struct MenuRow: View {
    let theme: PSPalette
    let title: String
    var detail: String?
    var showsDivider = true
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            PSAdaptiveStack {
                Text(title).psFont(15).foregroundStyle(theme.ink)
                Spacer(minLength: 0)
                if let detail { Text(detail).psFont(12).foregroundStyle(theme.ink3) }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { if showsDivider { theme.hair.frame(height: 1) } }
    }
}

/// The Solved screen under the faded board (HANDOFF 6.5): "Solved", a greeting for the time of day,
/// the level and time, what the solve counts for, one outlined chip per technique the grid needed, and
/// Another (secondary) and Goodnight (primary) at the bottom. No confetti, sound or haptic.
struct SolvedPanel: View {
    let theme: PSPalette
    let greeting: String
    let summary: String
    let note: String?
    let techniques: [String]
    var bottomPadding: CGFloat = 0
    let onAnother: () -> Void
    let onGoodnight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Solved")
                .psFont(52, weight: .heavy, design: .serif)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(greeting)
                .psFont(17, weight: .medium)
                .foregroundStyle(theme.ink)
                .accessibilityIdentifier("solved_greeting")
            Text(summary)
                .psFont(17, monospacedDigit: true)
                .foregroundStyle(theme.ink2)
            if let note {
                Text(note).psFont(13).foregroundStyle(theme.ink2).padding(.top, 6)
            }
            if !techniques.isEmpty {
                Text("This grid needed").psFont(13, weight: .medium).foregroundStyle(theme.ink2).padding(.top, 18).padding(.bottom, 8)
                FlowLayout(spacing: 6) {
                    ForEach(techniques, id: \.self) { name in
                        Text(name)
                            .psFont(14, weight: .semibold)
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(Capsule().fill(theme.fill))
                            .overlay(Capsule().strokeBorder(theme.fillEdge, lineWidth: 1))
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 16)
            PSButtonRow(trailing: false) {
                Button(action: onAnother) { Text("Another").frame(maxWidth: .infinity) }
                    .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 50))
                    .accessibilityIdentifier("solved_another")
                Button(action: onGoodnight) { Text("Goodnight").frame(maxWidth: .infinity) }
                    .buttonStyle(PSButtonStyle(theme: theme, height: 50))
                    .accessibilityIdentifier("solved_goodnight")
            }
            .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("solvedPanel")
    }
}

/// Lays its children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + size.width > width { rows.append(Row()) }
            var row = rows[rows.count - 1]
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// Pure black with one line of text that fades out. Hush and Goodnight both use it; any tap returns.
struct BlackoutView: View {
    let theme: PSPalette
    let text: String
    var serif = false
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsText = true

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                Text(text)
                    .psFont(serif ? 30 : 13, weight: serif ? .medium : .regular, design: serif ? .serif : .default)
                    .foregroundStyle(theme.ink3)
                    .opacity(showsText ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { showsText = false }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits([.isButton, .isModal])
    }
}

/// Pops the main navigation stack back to the menu (Goodnight from a practice game, CODESPEC 3.2).
private struct PopToRootKey: EnvironmentKey {
    /// A no-op that is never mutated, so sharing it across actors is safe.
    nonisolated(unsafe) static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var popToRoot: () -> Void {
        get { self[PopToRootKey.self] }
        set { self[PopToRootKey.self] = newValue }
    }
}

/// Calls `action` on a two-finger tap anywhere in the window, without taking touches from the
/// views under it.
struct TwoFingerTapCatcher: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> Hook {
        let hook = Hook()
        hook.action = action
        return hook
    }

    func updateUIView(_ hook: Hook, context: Context) { hook.action = action }

    final class Hook: UIView, UIGestureRecognizerDelegate {
        var action: () -> Void = {}
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(fire))
            tap.numberOfTouchesRequired = 2
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            isUserInteractionEnabled = false
            tap.view?.removeGestureRecognizer(tap)
            window?.addGestureRecognizer(tap)
        }

        @objc private func fire() { action() }

        // The board's buttons have their own recognizers; without this they can win the touches.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
