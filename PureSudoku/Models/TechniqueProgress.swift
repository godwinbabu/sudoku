import Foundation

/// What the player knows about one technique (CODESPEC 13.4).
struct TechniqueProgress: Codable, Equatable {
    /// Unaided moves this technique explains: one per correct placement or note removal (CODESPEC 13.4).
    var credits = 0
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

    /// One credited move (`LearningLedger` decides which moves earn one).
    mutating func recordFound(puzzleID: String, at date: Date, calendar: Calendar = .current) {
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

        var change: CellDigit {
            switch self {
            case let .placed(cell, digit), let .removedCandidate(cell, digit): return CellDigit(cell: cell, digit: digit)
            }
        }

        /// "puzzleKey|kind|cell|digit", as kept in `LearningLedger.credited`.
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

/// Which moves may still earn learning credit (CODESPEC 13.4). One store, owned by AppController and
/// saved in the same file as the technique progress (`LearningFile`), so Undo, Restart, Continue and reopening a practice puzzle
/// can't lose a hint or replay a credit. Keys start with the puzzle id; ids never contain "|".
struct LearningLedger: Codable, Equatable {
    /// "puzzle|kind|cell|digit": moves already credited, under any technique.
    var credited: Set<String> = []
    /// "puzzle|cell|digit": cells and digits a hint showed.
    var hintedMoves: Set<String> = []
    /// "puzzle|technique": lesson techniques hinted in a puzzle (Hidden Single line counts as box).
    var hintedTechniques: Set<String> = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        credited = try container.decodeIfPresent(Set<String>.self, forKey: .credited) ?? []
        hintedMoves = try container.decodeIfPresent(Set<String>.self, forKey: .hintedMoves) ?? []
        hintedTechniques = try container.decodeIfPresent(Set<String>.self, forKey: .hintedTechniques) ?? []
    }

    /// Records a hint; true the first time this puzzle hints this technique.
    @discardableResult
    mutating func recordHint(puzzle: String, technique: Technique?, changes: [CellDigit]) -> Bool {
        for change in changes { hintedMoves.insert(Self.key(puzzle, change)) }
        guard let technique else { return false }
        return hintedTechniques.insert("\(puzzle)|\(technique.rawValue)").inserted
    }

    /// Whether `move` earns a credit for `technique` (a lesson technique), recording it if so.
    mutating func credit(_ move: MasteryJudge.Move, technique: Technique, puzzle: String) -> Bool {
        guard !hintedMoves.contains(Self.key(puzzle, move.change)),
              !hintedTechniques.contains("\(puzzle)|\(technique.rawValue)") else { return false }
        return credited.insert(move.key(puzzleID: puzzle)).inserted
    }

    /// Keeps practice puzzles (bundled, so they come back) and the given saved games; drops finished ones.
    mutating func prune(keeping puzzles: Set<String>) {
        let keep = { (key: String) in
            let puzzle = String(key.prefix { $0 != "|" })
            return puzzle.hasPrefix("practice-") || puzzles.contains(puzzle)
        }
        credited = credited.filter(keep)
        hintedMoves = hintedMoves.filter(keep)
        hintedTechniques = hintedTechniques.filter(keep)
    }

    private static func key(_ puzzle: String, _ change: CellDigit) -> String { "\(puzzle)|\(change.cell)|\(change.digit)" }
}

/// technique_progress.json: progress and the ledger in one atomic file, so they are kept or lost
/// together and a lost ledger can never let a credited move earn again (CODESPEC 13.4).
struct LearningFile: Codable {
    var progress: [String: TechniqueProgress] = [:]
    var ledger = LearningLedger()

    enum CodingKeys: String, CodingKey { case progress, ledger }

    init(progress: [String: TechniqueProgress] = [:], ledger: LearningLedger = LearningLedger()) {
        self.progress = progress
        self.ledger = ledger
    }

    /// Saves before the ledger hold only the progress dictionary (no technique is named "progress").
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self), container.contains(.progress) {
            progress = try container.decode([String: TechniqueProgress].self, forKey: .progress)
            ledger = try container.decodeIfPresent(LearningLedger.self, forKey: .ledger) ?? LearningLedger()
        } else {
            progress = try decoder.singleValueContainer().decode([String: TechniqueProgress].self)
        }
    }
}
