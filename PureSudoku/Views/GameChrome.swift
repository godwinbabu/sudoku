import SwiftUI
import UIKit

/// Primary and ghost buttons. Day: primary is an `accent` fill. Night: primary is a 1.5 pt `accentDim`
/// outline with `accent` text, because nothing lit may sit behind text (CODESPEC 7.2).
struct PSButtonStyle: ButtonStyle {
    enum Kind { case primary, ghost }
    let theme: PSPalette
    var kind = Kind.primary
    var height: CGFloat = 40
    /// Disabled buttons are a hair outline with ink3 text: at least 3:1 in Day, unlike a faded fill.
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let primary = kind == .primary && isEnabled
        configuration.label
            .font(.system(size: height < 40 ? 14 : 15, weight: .semibold))
            .padding(.horizontal, height < 40 ? 14 : 18)
            .frame(minHeight: max(height, 44))
            .foregroundColor(!isEnabled ? theme.ink3
                             : primary ? (theme.isNight ? theme.accent : theme.bg) : (theme.isNight ? theme.ink2 : theme.ink))
            .background(
                Capsule().fill(primary && !theme.isNight ? theme.accent : .clear).frame(height: height)
            )
            .overlay(
                Capsule()
                    .strokeBorder(primary ? (theme.isNight ? theme.accentDim : .clear) : theme.hair, lineWidth: primary ? 1.5 : 1)
                    .frame(height: height)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

/// One of the four tools under the board: a 23 pt symbol over an 11 pt label.
struct ToolButton: View {
    let theme: PSPalette
    let symbol: String
    let label: String
    var isActive = false
    var badge: String?
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .regular))
                    .frame(height: 24)
                    .overlay(alignment: .topTrailing) {
                        if let badge { badgeView(badge).offset(x: 16, y: -6) }
                    }
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isActive ? theme.accent : theme.ink2)
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFillStyle(theme: theme))
        .opacity(isEnabled ? 1 : 0.35)
    }

    /// ON/OFF badge. Day ON is an `accent` fill; at night both are outlines.
    private func badgeView(_ text: String) -> some View {
        let filled = !theme.isNight
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundColor(isActive ? (filled ? theme.bg : theme.accent) : theme.ink2)
            .background(RoundedRectangle(cornerRadius: 6).fill(filled ? (isActive ? theme.accent : theme.surface2) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(filled ? .clear : (isActive ? theme.accent : theme.hair), lineWidth: 1))
            .fixedSize()
    }
}

/// A 44 pt header icon.
struct HeaderIconButton: View {
    let theme: PSPalette
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(theme.ink2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
            HStack {
                Text(title).font(.system(size: 15)).foregroundColor(theme.ink)
                Spacer()
                if let detail { Text(detail).font(.system(size: 12)).foregroundColor(theme.ink3) }
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

/// "Solved." over the faded board.
struct SolvedPanel: View {
    let theme: PSPalette
    let summary: String
    let note: String?
    let techniques: String?
    let onAnother: () -> Void
    let onGoodnight: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Solved.")
                .font(.system(size: 44, weight: .medium, design: .serif))
                .foregroundColor(theme.ink)
            Text(summary)
                .font(.system(size: 15).monospacedDigit())
                .foregroundColor(theme.ink2)
            if let note {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundColor(theme.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(theme.hair, lineWidth: 1))
            }
            if let techniques {
                Text(techniques)
                    .font(.system(size: 13))
                    .foregroundColor(theme.ink3)
                    .padding(.top, 4)
            }
            HStack(spacing: 10) {
                Button("Another", action: onAnother)
                    .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost))
                    .accessibilityIdentifier("solved_another")
                Button("Goodnight", action: onGoodnight)
                    .buttonStyle(PSButtonStyle(theme: theme))
                    .accessibilityIdentifier("solved_goodnight")
            }
            .padding(.top, 14)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("solvedPanel")
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
                    .font(serif ? .system(size: 30, weight: .medium, design: .serif) : .system(size: 13))
                    .foregroundColor(theme.ink3)
                    .opacity(showsText ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .task {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { showsText = false }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }
}

/// Pops the main navigation stack back to the menu (Goodnight from a practice game, CODESPEC 3.2).
private struct PopToRootKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
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
