import SwiftUI

/// Sets the screen backlight in Night from Glow (CODESPEC 12.3): the hardware minimum up to glow 40,
/// then brighter. Find my lowest glow holds the minimum while it is open, by day too. Puts the
/// player's brightness back when the app leaves the foreground or neither applies. If the player
/// changes brightness themselves (Control Center), that wins until Glow changes or they calibrate.
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

    /// The backlight the app wants, or nil to leave it to the player. Find my lowest glow holds the
    /// minimum whenever it is on screen, also by day, since its tiles show the palette layer alone.
    static func target(phase: ScenePhase, isNight: Bool, isCalibrating: Bool, nightBacklight: CGFloat) -> CGFloat? {
        guard phase != .background else { return nil }
        if isCalibrating { return 0 }
        return isNight ? nightBacklight : nil
    }

    /// `target` is the backlight to hold (Night or calibrating), or nil to give the screen back. `request` is
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
