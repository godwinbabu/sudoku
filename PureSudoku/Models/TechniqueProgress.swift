import Foundation

/// What the player knows about one technique (CODESPEC 13.4).
struct TechniqueProgress: Codable, Equatable {
    /// Puzzles where the player found the technique without a hint, with the day it happened.
    var foundUnaided: [Found] = []
    /// Hints shown for this technique (any rung).
    var hintsSeen = 0
    var lastSeen: Date?
    /// 0...1, as of `strengthDate`; decays over time (half-life model).
    var strength: Double = 0
    var strengthDate: Date?

    struct Found: Codable, Equatable {
        let puzzleID: String
        /// Calendar day, "yyyy-MM-dd".
        let day: String
    }

    enum Level: String { case new, learning, mastered }

    /// Mastered after finding it unaided in 3 different puzzles on 3 different days.
    var level: Level {
        if Set(foundUnaided.map(\.day)).count >= 3 && Set(foundUnaided.map(\.puzzleID)).count >= 3 { return .mastered }
        return foundUnaided.isEmpty && hintsSeen == 0 ? .new : .learning
    }

    /// Strength right now: halves every `halfLifeDays`, which grows as the player finds it more.
    func strength(at date: Date) -> Double {
        guard let since = strengthDate else { return strength }
        let days = max(0, date.timeIntervalSince(since) / 86_400)
        let halfLifeDays = 3.0 * pow(2, Double(min(foundUnaided.count, 5)))
        return strength * pow(2, -days / halfLifeDays)
    }

    mutating func recordFound(puzzleID: String, at date: Date, calendar: Calendar = .current) {
        let day = Self.dayKey(date, calendar: calendar)
        if !foundUnaided.contains(where: { $0.puzzleID == puzzleID }) {
            foundUnaided.append(Found(puzzleID: puzzleID, day: day))
        }
        strength = min(1, strength(at: date) + 0.34)
        strengthDate = date
        lastSeen = date
    }

    mutating func recordHint(at date: Date) {
        hintsSeen += 1
        strength = strength(at: date) * 0.5
        strengthDate = date
        lastSeen = date
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Which technique, if any, a player's move shows they found (CODESPEC 13.4). Credit goes to the
/// simplest technique that has a step making exactly this change on the board before the move.
enum MasteryJudge {
    enum Move: Equatable {
        case placed(cell: Int, digit: Int)
        case removedCandidate(cell: Int, digit: Int)
    }

    static func technique(for move: Move, on board: SolverBoard, allowsUniqueness: Bool = true) -> Technique? {
        for technique in Technique.allCases where allowsUniqueness || !technique.needsUniqueSolution {
            let steps = LogicalSolver.steps(for: technique, on: board)
            let matches = steps.contains { step in
                switch move {
                case let .placed(cell, digit): return step.placements.contains(CellDigit(cell: cell, digit: digit))
                case let .removedCandidate(cell, digit): return step.eliminations.contains(CellDigit(cell: cell, digit: digit))
                }
            }
            if matches { return technique }
        }
        return nil
    }
}
