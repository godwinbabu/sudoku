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
    private var lastUpdate: Date?

    init(clock: TimeProvider = SystemTimeProvider()) {
        self.clock = clock
    }

    /// Call on appear, on a periodic tick, on resume, and when Night or the Drift setting changes.
    /// Inactive resets the session, so leaving the game (or Night) starts Drift over. So does a gap
    /// of 30 minutes or more between updates: the app was away (perhaps through a whole day), and
    /// Drift is about one continuous sitting.
    func update(active: Bool) {
        guard active else {
            startedAt = nil
            lastUpdate = nil
            if steps != 0 { steps = 0 }
            return
        }
        let now = clock.now()
        if let lastUpdate, now.timeIntervalSince(lastUpdate) >= Self.interval * Double(Self.maxSteps) { startedAt = nil }
        lastUpdate = now
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
