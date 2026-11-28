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

    /// A level always starts a new puzzle (CODESPEC 3.1).
    func startNewGame(for difficulty: Difficulty) async -> GameViewModel? {
        await controller.startNewGame(for: difficulty)
        return controller.makeGameViewModel(for: difficulty)
    }

    func continueGame(for difficulty: Difficulty) -> GameViewModel? {
        controller.makeGameViewModel(for: difficulty)
    }

    /// The game a navigation route shows, or nil if it is gone. A missing import never falls back to a level's game.
    func routeGame(importID: String?, difficulty: Difficulty) -> GameViewModel? {
        guard let importID else { return controller.makeGameViewModel(for: difficulty) }
        return controller.makeImportedGameViewModel(id: importID)
    }

    /// "Saturday night · 6-night streak".
    /// Home's date line, "Saturday, November 21" . No streak here: no streak pressure (CODESPEC 3.1).
    func dateLine(at date: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter.string(from: date)
    }
}
