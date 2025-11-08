import Foundation

struct Stats: Codable, Equatable {
    var streakDays: Int
    var lastCompletionDate: Date?
    var bestTimes: [Difficulty: Int]
    var puzzlesSolved: [Difficulty: Int]
    var totalPuzzlesSolved: Int
    var totalTimeSeconds: Int

    init(streakDays: Int = 0, lastCompletionDate: Date? = nil, bestTimes: [Difficulty: Int] = [:], puzzlesSolved: [Difficulty: Int] = [:], totalPuzzlesSolved: Int = 0, totalTimeSeconds: Int = 0) {
        self.streakDays = streakDays
        self.lastCompletionDate = lastCompletionDate
        self.bestTimes = bestTimes
        self.puzzlesSolved = puzzlesSolved
        self.totalPuzzlesSolved = totalPuzzlesSolved
        self.totalTimeSeconds = totalTimeSeconds
    }

    mutating func recordCompletion(for difficulty: Difficulty, time: Int, usedReveal: Bool, date: Date = Date(), calendar: Calendar = .current) {
        totalPuzzlesSolved += 1
        totalTimeSeconds += time
        puzzlesSolved[difficulty, default: 0] += 1

        guard !usedReveal else {
            // reveal-assisted completions do not affect streaks or best times
            return
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
}
