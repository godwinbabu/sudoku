import Foundation
import Combine

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

    func formattedBestTime(for difficulty: Difficulty) -> String {
        guard let value = stats.bestTime(for: difficulty) else { return "--" }
        return Self.format(seconds: value)
    }

    func solvedCount(for difficulty: Difficulty) -> Int {
        stats.solvedCount(for: difficulty)
    }

    func totalTimeString() -> String {
        let active = activeGames.values.filter { !$0.isCompleted }.reduce(0) { $0 + $1.elapsedSeconds }
        return Self.format(seconds: stats.totalTimeSeconds + active)
    }

    private static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
