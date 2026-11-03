import Foundation
import Combine

/// The Journal's numbers (CODESPEC 3.3): streak, week, and per-level solved, best and typical times.
@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var stats: Stats
    @Published private(set) var activeGames: [Difficulty: GameState]

    private let controller: AppController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: AppController) {
        self.controller = controller
        self.stats = controller.stats
        self.activeGames = controller.activeGames

        controller.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.stats = stats
            }
            .store(in: &cancellables)

        controller.$activeGames
            .receive(on: RunLoop.main)
            .sink { [weak self] games in
                self?.activeGames = games
            }
            .store(in: &cancellables)
    }

    func streak(at date: Date = Date()) -> Int { stats.currentStreak(at: date) }

    /// This week, Monday first: (initial, solved that day).
    /// One day of the Journal week: the letter shown, the full name for VoiceOver.
    struct WeekDay {
        let day: String
        let name: String
        let solved: Bool
    }

    func week(at date: Date = Date(), calendar: Calendar = .current) -> [WeekDay] {
        var monday = Calendar(identifier: .gregorian)
        monday.timeZone = calendar.timeZone
        monday.firstWeekday = 2
        guard let start = monday.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names.enumerated().map { offset, name in
            let day = monday.date(byAdding: .day, value: offset, to: start) ?? start
            return WeekDay(day: String(name.prefix(1)), name: name, solved: stats.solved(on: day, calendar: calendar))
        }
    }

    func formattedBestTime(for difficulty: Difficulty) -> String {
        stats.bestTime(for: difficulty).map(Self.format) ?? "—"
    }

    func formattedTypicalTime(for difficulty: Difficulty) -> String {
        stats.typicalTime(for: difficulty).map(Self.format) ?? "—"
    }

    func solvedText(for difficulty: Difficulty) -> String {
        let count = stats.solvedCount(for: difficulty)
        return count == 0 ? "—" : "\(count)"
    }

    /// "Expert: 3 solved, best 4:12, typical 5:00", with "none yet" for missing values.
    func rowLabel(for difficulty: Difficulty) -> String {
        let count = stats.solvedCount(for: difficulty)
        let best = stats.bestTime(for: difficulty).map(Self.format) ?? "none yet"
        let typical = stats.typicalTime(for: difficulty).map(Self.format) ?? "none yet"
        return "\(difficulty.displayName): \(count == 0 ? "none" : "\(count)") solved, best \(best), typical \(typical)"
    }

    var assistedLine: String {
        let count = stats.assistedSolves
        return "\(count) assisted solve\(count == 1 ? "" : "s") kept your streak but don’t set best times."
    }

    /// Totals from the old Stats screen: all solves, imports and time played.
    var totalsLine: String {
        let total = stats.totalPuzzlesSolved
        return "\(total) solved in all · \(stats.importedPuzzlesSolved) imported · \(totalTimeString()) played"
    }

    func totalTimeString() -> String {
        let active = activeGames.values.filter { !$0.isCompleted }.reduce(0) { $0 + $1.elapsedSeconds }
        return Self.format(seconds: stats.totalTimeSeconds + active)
    }

    static func format(seconds: Int) -> String {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60, secs = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}
