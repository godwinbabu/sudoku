import UIKit

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
