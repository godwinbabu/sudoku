import XCTest
@testable import PureSudoku

final class StatsTests: XCTestCase {
    func testStreakIncrementsWithConsecutiveDays() {
        var stats = Stats()
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date()
        stats.recordCompletion(for: .easy, time: 120, usedReveal: false, date: day1, calendar: calendar)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        stats.recordCompletion(for: .medium, time: 140, usedReveal: false, date: day2, calendar: calendar)
        XCTAssertEqual(stats.streakDays, 2)
    }

    func testRevealDoesNotAffectStreakOrBestTime() {
        var stats = Stats()
        stats.recordCompletion(for: .easy, time: 100, usedReveal: true)
        XCTAssertEqual(stats.streakDays, 0)
        XCTAssertNil(stats.bestTime(for: .easy))
    }
}
