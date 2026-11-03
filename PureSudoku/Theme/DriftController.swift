import Foundation

/// Drift (CODESPEC 12.3): during a night game, glow eases down and warmth eases up, one point each
/// every 90 s, up to 20. A session offset only; it is never written to settings.
@MainActor
final class DriftController: ObservableObject {
    static let interval: TimeInterval = 90
    static let maxSteps = 20

    @Published private(set) var steps = 0
    private let clock: TimeProvider
    private var startedAt: Date?

    init(clock: TimeProvider = SystemTimeProvider()) {
        self.clock = clock
    }

    /// Call on appear, on a periodic tick, and when Night or the Drift setting changes.
    /// Inactive resets the session, so leaving the game (or Night) starts Drift over.
    func update(active: Bool) {
        guard active else {
            startedAt = nil
            if steps != 0 { steps = 0 }
            return
        }
        let now = clock.now()
        let start = startedAt ?? now
        startedAt = start
        let next = min(Self.maxSteps, max(0, Int(now.timeIntervalSince(start) / Self.interval)))
        if next != steps { steps = next }
    }

    /// The settings with this session's offset. Glow never drops below `glowFloor`.
    static func apply(steps: Int, to settings: Settings) -> Settings {
        var drifted = settings
        let lowered = max(settings.glowFloor, settings.glow - Double(steps))
        drifted.glow = min(settings.glow, lowered)
        drifted.warmth = min(100, settings.warmth + Double(steps))
        return drifted
    }
}
