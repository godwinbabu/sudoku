import SwiftUI

/// Lowers the screen to its minimum while the app is open, if the display profile asks for it
/// (CODESPEC 12.3), and puts the player's brightness back when the app leaves the foreground.
@MainActor
final class ScreenBrightnessController {
    private let read: () -> CGFloat
    private let write: (CGFloat) -> Void
    private var saved: CGFloat?

    init(read: @escaping () -> CGFloat = { UIScreen.main.brightness }, write: @escaping (CGFloat) -> Void = { UIScreen.main.brightness = $0 }) {
        self.read = read
        self.write = write
    }

    var isLowered: Bool { saved != nil }

    /// Lower while the app is on screen. `.inactive` (Control Center, a notification banner) keeps
    /// it low; restoring there would flash the screen up and back down.
    static func shouldLower(phase: ScenePhase, settings: Settings) -> Bool {
        phase != .background && settings.themeEffective == .sleep && settings.currentDisplayProfile.lowersScreenBrightness
    }

    func update(lower: Bool) {
        if lower {
            if saved == nil { saved = read() }
            write(0)
        } else if let saved {
            write(saved)
            self.saved = nil
        }
    }
}
