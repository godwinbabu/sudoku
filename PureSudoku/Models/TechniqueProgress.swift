import Foundation

/// What the player knows about one technique (CODESPEC 13.4).
struct TechniqueProgress: Codable, Equatable {
    /// Unaided moves this technique explains: one per correct placement or note removal (CODESPEC 13.4).
    var credits = 0
    /// Moves credited so far, as `MasteryJudge.Move.key(puzzleID:)`: each move of each puzzle earns
    /// once, even after Undo, Erase, Continue or a replayed practice puzzle.
    var creditedMoves: Set<String> = []
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

    static let creditsNeeded = 10

    /// Mastered after 10 unaided uses.
    var level: Level {
        if credits >= Self.creditsNeeded { return .mastered }
        return credits == 0 && hintsSeen == 0 ? .new : .learning
    }

    /// Strength right now: halves every `halfLifeDays`, which grows as the player finds it more.
    func strength(at date: Date) -> Double {
        guard let since = strengthDate else { return strength }
        let days = max(0, date.timeIntervalSince(since) / 86_400)
        let halfLifeDays = 3.0 * pow(2, Double(min(foundUnaided.count, 5)))
        return strength * pow(2, -days / halfLifeDays)
    }

    /// One credited move. A move credited before (same `moveKey`) changes nothing.
    mutating func recordFound(puzzleID: String, moveKey: String? = nil, at date: Date, calendar: Calendar = .current) {
        if let moveKey, !creditedMoves.insert(moveKey).inserted { return }
        let day = Self.dayKey(date, calendar: calendar)
        lastSeen = date
        credits += 1
        // Once per puzzle: replaying a move (e.g. after Undo) doesn't add strength.
        guard !foundUnaided.contains(where: { $0.puzzleID == puzzleID }) else { return }
        foundUnaided.append(Found(puzzleID: puzzleID, day: day))
        strength = min(1, strength(at: date) + 0.34)
        strengthDate = date
    }

    mutating func recordHint(at date: Date) {
        hintsSeen += 1
        strength = strength(at: date) * 0.5
        strengthDate = date
        lastSeen = date
    }

    /// Saves from before credits have none: count one per puzzle found, and keep mastery earned
    /// under the old rule (3 puzzles on 3 days).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foundUnaided = try container.decodeIfPresent([Found].self, forKey: .foundUnaided) ?? []
        hintsSeen = try container.decodeIfPresent(Int.self, forKey: .hintsSeen) ?? 0
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen)
        strength = try container.decodeIfPresent(Double.self, forKey: .strength) ?? 0
        strengthDate = try container.decodeIfPresent(Date.self, forKey: .strengthDate)
        creditedMoves = try container.decodeIfPresent(Set<String>.self, forKey: .creditedMoves) ?? []
        if let credits = try container.decodeIfPresent(Int.self, forKey: .credits) {
            self.credits = credits
        } else {
            let earnedTheOldWay = Set(foundUnaided.map(\.day)).count >= 3 && Set(foundUnaided.map(\.puzzleID)).count >= 3
            credits = earnedTheOldWay ? max(foundUnaided.count, Self.creditsNeeded) : foundUnaided.count
        }
    }

    init() {}

    /// Two records of one technique as one (Hidden Single box and line are one lesson).
    func merged(with other: TechniqueProgress) -> TechniqueProgress {
        var result = self
        result.credits += other.credits
        result.creditedMoves.formUnion(other.creditedMoves)
        result.foundUnaided += other.foundUnaided.filter { found in !foundUnaided.contains { $0.puzzleID == found.puzzleID } }
        result.hintsSeen += other.hintsSeen
        result.lastSeen = [lastSeen, other.lastSeen].compactMap { $0 }.max()
        if (other.strengthDate ?? .distantPast) > (strengthDate ?? .distantPast) {
            result.strength = other.strength
            result.strengthDate = other.strengthDate
        }
        return result
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Which technique, if any, a player's move shows they found (CODESPEC 13.4). Credit goes to the
/// simplest technique that has a step making exactly this change on the board before the move.
enum MasteryJudge {
    enum Move: Hashable {
        case placed(cell: Int, digit: Int)
        case removedCandidate(cell: Int, digit: Int)

        /// "puzzleID|kind|cell|digit", saved in `TechniqueProgress.creditedMoves`.
        func key(puzzleID: String) -> String {
            switch self {
            case let .placed(cell, digit): return "\(puzzleID)|placed|\(cell)|\(digit)"
            case let .removedCandidate(cell, digit): return "\(puzzleID)|removed|\(cell)|\(digit)"
            }
        }
    }

    static func technique(for move: Move, on board: SolverBoard, allowsUniqueness: Bool = true) -> Technique? {
        // Only singles and BUG+1 place digits; every other technique only removes candidates.
        let placers: Set<Technique> = [.fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle, .bugPlusOne]
        let candidates = Technique.allCases.filter { technique in
            if case .placed = move { return placers.contains(technique) }
            return !placers.contains(technique)
        }
        for technique in candidates where allowsUniqueness || !technique.needsUniqueSolution {
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
