import Foundation
import Combine

/// Home (CODESPEC 3.1): the Continue card, the five levels and the sub-line.
@MainActor
final class MainMenuViewModel: ObservableObject {
    @Published private(set) var stats: Stats
    @Published private(set) var settings: Settings

    private let controller: AppController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: AppController) {
        self.controller = controller
        self.stats = controller.stats
        self.settings = controller.settings

        controller.$stats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.stats = stats
            }
            .store(in: &cancellables)

        controller.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.settings = settings
            }
            .store(in: &cancellables)
    }

    /// The game the Continue card resumes.
    var continueGame: GameState? { controller.continueGame }

    /// True if the saved game at `level` is unfinished and the player has entered something, so a
    /// new puzzle would replace real progress (CODESPEC 3.1).
    func hasUnfinishedEntries(at level: Difficulty) -> Bool {
        guard let game = controller.activeGames[level], !game.isCompleted else { return false }
        return game.cells.contains { !$0.given && ($0.value != nil || !$0.candidates.isEmpty) }
    }

    /// A level always starts a new puzzle (Design/v2/README.md, Home).
    func startNewGame(for difficulty: Difficulty) async -> GameViewModel? {
        await controller.startNewGame(for: difficulty)
        return controller.makeGameViewModel(for: difficulty)
    }

    func continueGame(for difficulty: Difficulty) -> GameViewModel? {
        controller.makeGameViewModel(for: difficulty)
    }

    /// "Saturday night · 6-night streak".
    func subLine(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let part = switch hour {
        case 5..<12: "morning"
        case 12..<17: "afternoon"
        case 17..<21: "evening"
        default: "night"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: date)
        let streak = stats.currentStreak(at: date, calendar: calendar)
        return streak > 0 ? "\(day) \(part) · \(streak)-night streak" : "\(day) \(part)"
    }
}
