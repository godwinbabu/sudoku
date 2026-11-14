import Foundation

struct Stats: Codable, Equatable {
    var streakDays: Int
    var lastCompletionDate: Date?
    var bestTimes: [Difficulty: Int]
    var puzzlesSolved: [Difficulty: Int]
    var importedPuzzlesSolved: Int
    var totalPuzzlesSolved: Int
    var totalTimeSeconds: Int
    /// Unassisted solve times per level, newest last, for the typical (median) time.
    var solveTimes: [Difficulty: [Int]] = [:]
    /// Solves that used a hint's Place or Remove (CODESPEC 6.3.1).
    var assistedSolves = 0
    /// Days with a counted solve (start of day), newest last, for the Journal week.
    var solvedDays: [Date] = []

    /// Solve times kept per level; shortcut: the median of the last 50, enough for "typical".
    static let keptTimes = 50
    static let keptDays = 14
    /// A night of play runs until 4 am local time: a solve at 00:30 belongs to the evening before
    /// (CODESPEC 3.3).
    static let rolloverHour = 4

    /// The calendar day a solve at `date` counts for. Uses the local hour, not "minus 4 hours", so
    /// daylight-saving days move nothing across the boundary.
    static func playDay(_ date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < rolloverHour else { return day }
        return calendar.date(byAdding: .day, value: -1, to: day) ?? day
    }

    init(streakDays: Int = 0, lastCompletionDate: Date? = nil, bestTimes: [Difficulty: Int] = [:], puzzlesSolved: [Difficulty: Int] = [:], importedPuzzlesSolved: Int = 0, totalPuzzlesSolved: Int = 0, totalTimeSeconds: Int = 0) {
        self.streakDays = streakDays
        self.lastCompletionDate = lastCompletionDate
        self.bestTimes = bestTimes
        self.puzzlesSolved = puzzlesSolved
        self.importedPuzzlesSolved = importedPuzzlesSolved
        self.totalPuzzlesSolved = totalPuzzlesSolved
        self.totalTimeSeconds = totalTimeSeconds
    }

    /// Per CODESPEC "Streak rules", only puzzles completed without Reveal update stats. An assisted
    /// solve keeps the streak and counts, but sets no best time (CODESPEC 6.3.1). Neither does a
    /// puzzle with several solutions (`setsTimes` false: an import any valid fill solves).
    mutating func recordCompletion(for difficulty: Difficulty, time: Int, usedReveal: Bool, assisted: Bool = false,
                                   setsTimes: Bool = true, source: GameSource = .generated, date: Date = Date(),
                                   calendar: Calendar = .current) {
        guard !usedReveal else { return }
        totalPuzzlesSolved += 1
        totalTimeSeconds += time
        puzzlesSolved[difficulty, default: 0] += 1
        if source == .imported {
            importedPuzzlesSolved += 1
        }

        if assisted {
            assistedSolves += 1
        } else if setsTimes {
            recordTime(for: difficulty, time: time)
        }
        let day = Self.playDay(date, calendar: calendar)
        if !solvedDays.contains(where: { calendar.isDate($0, inSameDayAs: day) }) {
            solvedDays = (solvedDays + [day]).suffix(Self.keptDays)
        }

        if let lastDate = lastCompletionDate {
            if calendar.isDate(day, inSameDayAs: lastDate) {
                // same day, streak unchanged
            } else if let previous = calendar.date(byAdding: .day, value: -1, to: day), calendar.isDate(previous, inSameDayAs: lastDate) {
                streakDays += 1
            } else {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }

        lastCompletionDate = day
    }

    // shortcut: one id (~40 bytes) per solve, never pruned; prune to games still on disk if it grows.
    /// Games whose solve is in the stats (`apply`), so a retried handoff counts it once. Files from
    /// before it decode it empty; their counted games never come back here, as only a
    /// `PendingCompletion` adds a solve.
    var countedGameIDs: Set<String> = []

    /// Bumped when the file's meaning changes. 2: `countedGameIDs`.
    static let schemaVersion = 2

    /// Adds a pending solve once: a game already counted does nothing.
    mutating func apply(_ completion: PendingCompletion, calendar: Calendar = .current) {
        guard countedGameIDs.insert(completion.gameID).inserted else { return }
        recordCompletion(for: completion.difficulty, time: completion.elapsedSeconds, usedReveal: false,
                         assisted: completion.assisted, setsTimes: completion.setsTimes, source: completion.source,
                         date: completion.date, calendar: calendar)
    }

    /// Imports whose late time is recorded (`recordLateTime`), so a retried handoff adds it once.
    var lateTimeIDs: Set<String> = []

    /// An import's time that waited for its solution count; a second call with the same id does nothing.
    mutating func recordLateTime(id: String, for difficulty: Difficulty, time: Int) {
        guard lateTimeIDs.insert(id).inserted else { return }
        recordTime(for: difficulty, time: time)
    }

    /// Adds a solve's time to the best and typical times only; the solve itself is counted elsewhere.
    mutating func recordTime(for difficulty: Difficulty, time: Int) {
        bestTimes[difficulty] = min(bestTimes[difficulty] ?? time, time)
        solveTimes[difficulty, default: []].append(time)
        solveTimes[difficulty] = solveTimes[difficulty]?.suffix(Self.keptTimes)
    }

    func solvedCount(for difficulty: Difficulty) -> Int {
        puzzlesSolved[difficulty, default: 0]
    }

    func bestTime(for difficulty: Difficulty) -> Int? {
        bestTimes[difficulty]
    }

    /// The median unassisted solve time at a level (the Journal's "Typical").
    func typicalTime(for difficulty: Difficulty) -> Int? {
        let times = solveTimes[difficulty, default: []].sorted()
        guard !times.isEmpty else { return nil }
        let middle = times.count / 2
        return times.count.isMultiple(of: 2) ? (times[middle - 1] + times[middle]) / 2 : times[middle]
    }

    /// The streak as of `date`: zero once a whole day (to 4 am) has passed without a solve.
    func currentStreak(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let last = lastCompletionDate else { return 0 }
        let today = Self.playDay(date, calendar: calendar)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
        return days <= 1 ? streakDays : 0
    }

    /// True if a counted solve happened on `date`'s day.
    func solved(on date: Date, calendar: Calendar = .current) -> Bool {
        solvedDays.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    private enum CodingKeys: String, CodingKey {
        case streakDays
        case lastCompletionDate
        case bestTimes
        case puzzlesSolved
        case importedPuzzlesSolved
        case totalPuzzlesSolved
        case totalTimeSeconds
        case solveTimes
        case assistedSolves
        case solvedDays
        case lateTimeIDs
        case countedGameIDs
        case schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streakDays = try container.decode(Int.self, forKey: .streakDays)
        lastCompletionDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletionDate)
        bestTimes = try container.decode([Difficulty: Int].self, forKey: .bestTimes)
        puzzlesSolved = try container.decode([Difficulty: Int].self, forKey: .puzzlesSolved)
        importedPuzzlesSolved = try container.decodeIfPresent(Int.self, forKey: .importedPuzzlesSolved) ?? 0
        totalPuzzlesSolved = try container.decode(Int.self, forKey: .totalPuzzlesSolved)
        totalTimeSeconds = try container.decode(Int.self, forKey: .totalTimeSeconds)
        solveTimes = try container.decodeIfPresent([Difficulty: [Int]].self, forKey: .solveTimes) ?? [:]
        assistedSolves = try container.decodeIfPresent(Int.self, forKey: .assistedSolves) ?? 0
        // Files from before the Journal week know only the last solve day; start the week from it.
        solvedDays = try container.decodeIfPresent([Date].self, forKey: .solvedDays) ?? (lastCompletionDate.map { [$0] } ?? [])
        lateTimeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .lateTimeIDs) ?? []
        countedGameIDs = try container.decodeIfPresent(Set<String>.self, forKey: .countedGameIDs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(streakDays, forKey: .streakDays)
        try container.encodeIfPresent(lastCompletionDate, forKey: .lastCompletionDate)
        try container.encode(bestTimes, forKey: .bestTimes)
        try container.encode(puzzlesSolved, forKey: .puzzlesSolved)
        try container.encode(importedPuzzlesSolved, forKey: .importedPuzzlesSolved)
        try container.encode(totalPuzzlesSolved, forKey: .totalPuzzlesSolved)
        try container.encode(totalTimeSeconds, forKey: .totalTimeSeconds)
        try container.encode(solveTimes, forKey: .solveTimes)
        try container.encode(assistedSolves, forKey: .assistedSolves)
        try container.encode(solvedDays, forKey: .solvedDays)
        try container.encode(lateTimeIDs, forKey: .lateTimeIDs)
        try container.encode(countedGameIDs, forKey: .countedGameIDs)
        try container.encode(Self.schemaVersion, forKey: .schemaVersion)
    }
}

/// A solve, copied when it finished, waiting in pending_completions.json until it is in the saved
/// stats and its game is saved as counted (CODESPEC 8). A failed save or a relaunch retries it; a
/// later Restart or new game can't change its time or date.
struct PendingCompletion: Codable, Equatable {
    var gameID: String
    var difficulty: Difficulty
    var elapsedSeconds: Int
    var date: Date
    var assisted: Bool
    var setsTimes: Bool
    var source: GameSource
}

extension PendingCompletion {
    init(_ game: GameState, at difficulty: Difficulty, date: Date) {
        self.init(gameID: game.puzzle.id, difficulty: difficulty, elapsedSeconds: game.elapsedSeconds, date: date,
                  assisted: game.assisted, setsTimes: game.puzzle.isUnique, source: game.puzzle.source)
    }
}
