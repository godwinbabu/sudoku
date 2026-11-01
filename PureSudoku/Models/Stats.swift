import Foundation

struct Stats: Codable, Equatable {
    var streakDays: Int
    var lastCompletionDate: Date?
    var bestTimes: [Difficulty: Int]
    var puzzlesSolved: [Difficulty: Int]
    var importedPuzzlesSolved: Int
    var totalPuzzlesSolved: Int
    var totalTimeSeconds: Int

    init(streakDays: Int = 0, lastCompletionDate: Date? = nil, bestTimes: [Difficulty: Int] = [:], puzzlesSolved: [Difficulty: Int] = [:], importedPuzzlesSolved: Int = 0, totalPuzzlesSolved: Int = 0, totalTimeSeconds: Int = 0) {
        self.streakDays = streakDays
        self.lastCompletionDate = lastCompletionDate
        self.bestTimes = bestTimes
        self.puzzlesSolved = puzzlesSolved
        self.importedPuzzlesSolved = importedPuzzlesSolved
        self.totalPuzzlesSolved = totalPuzzlesSolved
        self.totalTimeSeconds = totalTimeSeconds
    }

    /// Per CODESPEC "Streak rules", only puzzles completed without Reveal update stats.
    mutating func recordCompletion(for difficulty: Difficulty, time: Int, usedReveal: Bool, source: GameSource = .generated, date: Date = Date(), calendar: Calendar = .current) {
        guard !usedReveal else { return }
        totalPuzzlesSolved += 1
        totalTimeSeconds += time
        puzzlesSolved[difficulty, default: 0] += 1
        if source == .imported {
            importedPuzzlesSolved += 1
        }

        if let best = bestTimes[difficulty] {
            bestTimes[difficulty] = min(best, time)
        } else {
            bestTimes[difficulty] = time
        }

        if let lastDate = lastCompletionDate {
            if calendar.isDate(date, inSameDayAs: lastDate) {
                // same day, streak unchanged
            } else if let next = calendar.date(byAdding: .day, value: -1, to: date), calendar.isDate(next, inSameDayAs: lastDate) {
                streakDays += 1
            } else {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }

        lastCompletionDate = calendar.startOfDay(for: date)
    }

    func solvedCount(for difficulty: Difficulty) -> Int {
        puzzlesSolved[difficulty, default: 0]
    }

    func bestTime(for difficulty: Difficulty) -> Int? {
        bestTimes[difficulty]
    }

    private enum CodingKeys: String, CodingKey {
        case streakDays
        case lastCompletionDate
        case bestTimes
        case puzzlesSolved
        case importedPuzzlesSolved
        case totalPuzzlesSolved
        case totalTimeSeconds
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
    }
}
