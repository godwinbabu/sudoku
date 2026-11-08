import XCTest
@testable import PureSudoku

final class StatsTests: XCTestCase {
    func testStreakIncrementsWithConsecutiveDays() {
        var stats = Stats()
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date()
        stats.recordCompletion(for: .easy, time: 120, usedReveal: false, source: .generated, date: day1, calendar: calendar)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        stats.recordCompletion(for: .medium, time: 140, usedReveal: false, source: .generated, date: day2, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 2)
    }

    func testRevealDoesNotAffectStreakOrBestTime() {
        var stats = Stats()
        stats.recordCompletion(for: .easy, time: 100, usedReveal: true, source: .imported)
        XCTAssertEqual(stats, Stats())
    }

    func testImportedCompletionCountsSeparately() {
        var stats = Stats()
        stats.recordCompletion(for: .easy, time: 100, usedReveal: false, source: .imported)
        XCTAssertEqual(stats.streakDays, 1)
        XCTAssertEqual(stats.bestTime(for: .easy), 100)
        XCTAssertEqual(stats.importedPuzzlesSolved, 1)
    }

    /// Journal "Typical": the median of unassisted times. Assisted solves keep the streak and counts
    /// but set neither best nor typical; Reveal counts for nothing (CODESPEC 6.3.1, 8).
    func testTypicalTimeAndAssistedRules() {
        var stats = Stats()
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for time in [300, 100, 200] {
            stats.recordCompletion(for: .expert, time: time, usedReveal: false, date: day, calendar: calendar)
        }
        XCTAssertEqual(stats.typicalTime(for: .expert), 200)
        stats.recordCompletion(for: .expert, time: 400, usedReveal: false, date: day, calendar: calendar)
        XCTAssertEqual(stats.typicalTime(for: .expert), 250, "even count: the mean of the middle two")

        stats.recordCompletion(for: .expert, time: 10, usedReveal: false, assisted: true, date: day, calendar: calendar)
        XCTAssertEqual(stats.bestTime(for: .expert), 100, "assisted sets no best time")
        XCTAssertEqual(stats.typicalTime(for: .expert), 250, "assisted sets no typical time")
        XCTAssertEqual(stats.solvedCount(for: .expert), 5, "assisted still counts")
        XCTAssertEqual(stats.assistedSolves, 1)

        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        stats.recordCompletion(for: .master, time: 10, usedReveal: false, assisted: true, date: next, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 2, "assisted keeps the streak")
        XCTAssertNil(stats.typicalTime(for: .master))

        let before = stats
        stats.recordCompletion(for: .master, time: 5, usedReveal: true, date: next, calendar: calendar)
        XCTAssertEqual(stats, before, "Reveal counts for nothing")
    }

    func testOnlyRecentSolveTimesAreKept() {
        var stats = Stats()
        for time in 1...(Stats.keptTimes + 10) {
            stats.recordCompletion(for: .easy, time: time, usedReveal: false)
        }
        XCTAssertEqual(stats.solveTimes[.easy]?.count, Stats.keptTimes)
        XCTAssertEqual(stats.solveTimes[.easy]?.first, 11, "the oldest go first")
    }

    func testWeekDaysAndCurrentStreak() {
        var stats = Stats()
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 22))!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        stats.recordCompletion(for: .easy, time: 60, usedReveal: false, date: monday, calendar: calendar)
        stats.recordCompletion(for: .easy, time: 60, usedReveal: false, date: tuesday, calendar: calendar)
        stats.recordCompletion(for: .easy, time: 60, usedReveal: false, date: tuesday, calendar: calendar)
        XCTAssertEqual(stats.solvedDays.count, 2, "one entry per day")
        XCTAssertTrue(stats.solved(on: monday, calendar: calendar))
        XCTAssertFalse(stats.solved(on: calendar.date(byAdding: .day, value: 2, to: monday)!, calendar: calendar))
        XCTAssertEqual(stats.currentStreak(at: calendar.date(byAdding: .day, value: 1, to: tuesday)!, calendar: calendar), 2,
                       "the streak still stands the next day")
        XCTAssertEqual(stats.currentStreak(at: calendar.date(byAdding: .day, value: 2, to: tuesday)!, calendar: calendar), 0,
                       "a whole day without a solve ends it")
    }

    /// Stats and games saved with three levels still load; the new fields default (CODESPEC 2.3).
    func testOldStatsAndGamesWithThreeLevelsDecode() throws {
        let oldStats = """
        {"streakDays":3,"bestTimes":["hard",400,"easy",90],"puzzlesSolved":["medium",2,"hard",1],
         "totalPuzzlesSolved":3,"totalTimeSeconds":900}
        """
        let stats = try JSONDecoder().decode(Stats.self, from: Data(oldStats.utf8))
        XCTAssertEqual(stats.bestTime(for: .hard), 400)
        XCTAssertEqual(stats.solvedCount(for: .medium), 2)
        XCTAssertEqual(stats.solveTimes, [:])
        XCTAssertEqual(stats.assistedSolves, 0)
        XCTAssertEqual(stats.solvedDays, [], "no last solve day, nothing to seed")
        let withLast = oldStats.replacingOccurrences(of: "\"streakDays\":3,", with: "\"streakDays\":3,\"lastCompletionDate\":0,")
        let seeded = try JSONDecoder().decode(Stats.self, from: Data(withLast.utf8))
        XCTAssertEqual(seeded.solvedDays, [Date(timeIntervalSinceReferenceDate: 0)], "the last solve day starts the week")

        for level in ["easy", "medium", "hard"] {
            XCTAssertEqual(try JSONDecoder().decode(Difficulty.self, from: Data("\"\(level)\"".utf8)).rawValue, level)
        }
        let encoded = try JSONEncoder().encode(GameState.newGame(for: TestData.puzzle))
        var game = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var puzzle = try XCTUnwrap(game["puzzle"] as? [String: Any])
        puzzle["difficulty"] = "hard"
        game["puzzle"] = puzzle
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: game))
        XCTAssertEqual(decoded.puzzle.difficulty, .hard)

        // The new levels round-trip, including as dictionary keys.
        var newStats = Stats()
        newStats.recordCompletion(for: .master, time: 500, usedReveal: false)
        XCTAssertEqual(try JSONDecoder().decode(Stats.self, from: JSONEncoder().encode(newStats)), newStats)
    }

    // MARK: - QA fixes (#35, #34)

    /// A night of play runs to 4 am: Monday 23:30 then Wednesday 00:30 is two nights in a row.
    func testStreakSurvivesMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
        }
        var stats = Stats()
        stats.recordCompletion(for: .easy, time: 100, usedReveal: false, date: at(2, 23, 30), calendar: calendar)
        XCTAssertEqual(stats.currentStreak(at: at(3, 0, 5), calendar: calendar), 1, "still Monday night at 00:05")
        stats.recordCompletion(for: .easy, time: 100, usedReveal: false, date: at(4, 0, 30), calendar: calendar)
        XCTAssertEqual(stats.streakDays, 2, "Tuesday night, after midnight")
        XCTAssertTrue(stats.solved(on: at(3, 12, 0), calendar: calendar), "the 00:30 solve counts for Tuesday")
        XCTAssertEqual(stats.currentStreak(at: at(5, 3, 59), calendar: calendar), 2, "Wednesday night is not over until 4 am")
        XCTAssertEqual(stats.currentStreak(at: at(6, 4, 1), calendar: calendar), 0, "a whole night missed")
    }

    func testSolveWithSeveralSolutionsSetsNoTimes() {
        var stats = Stats()
        stats.recordCompletion(for: .master, time: 30, usedReveal: false, setsTimes: false, source: .imported)
        XCTAssertNil(stats.bestTime(for: .master))
        XCTAssertNil(stats.typicalTime(for: .master))
        XCTAssertEqual(stats.solvedCount(for: .master), 1, "it still counts as solved")
        XCTAssertEqual(stats.streakDays, 1)
        XCTAssertEqual(stats.assistedSolves, 0)
    }
}
