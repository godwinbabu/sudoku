import SwiftUI

/// Sets the screen backlight from Glow while the app is open in Night (CODESPEC 12.3): the hardware
/// minimum up to glow 40, then brighter. Puts the player's brightness back when the app leaves the
/// foreground or Night ends. If the player changes brightness themselves (Control Center), that wins
/// until Glow changes.
@MainActor
final class ScreenBrightnessController {
    private let read: () -> CGFloat
    private let write: (CGFloat) -> Void
    /// The player's brightness from before Night took over.
    private var saved: CGFloat?
    /// What we last wrote, to tell our own change from the player's.
    private var written: CGFloat?
    private var lastRequest: AnyHashable?

    init(read: @escaping () -> CGFloat = { UIScreen.main.brightness }, write: @escaping (CGFloat) -> Void = { UIScreen.main.brightness = $0 }) {
        self.read = read
        self.write = write
    }

    /// Night owns the backlight while the app is on screen. `.inactive` (Control Center, a
    /// notification banner) keeps it; restoring there would flash the screen up and back down.
    static func shouldLower(phase: ScenePhase, isNight: Bool) -> Bool {
        phase != .background && isNight
    }

    /// `target` is the Night backlight, or nil to give the screen back to the player. `request` is
    /// what the player asked for (their Glow, or calibrating): a brightness they set themselves is kept
    /// until it changes, even if the target moves on its own (Drift).
    func update(target: CGFloat?, request: AnyHashable = 0) {
        guard let target else {
            if let saved { write(saved) }
            saved = nil
            written = nil
            return
        }
        if saved == nil {
            saved = read()
        } else if request == lastRequest, let written, abs(read() - written) > 0.01 {
            return // the player moved the brightness themselves and hasn't changed Glow since
        }
        write(target)
        written = target
        lastRequest = request
    }
}
