import Foundation
import Combine

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

    func makeGameViewModel(for difficulty: Difficulty) -> GameViewModel {
        controller.makeGameViewModel(for: difficulty)
    }

    func continueOrStartGame(for difficulty: Difficulty) -> GameViewModel {
        if controller.activeGames[difficulty]?.isCompleted != false {
            controller.startNewGame(for: difficulty)
        }
        return controller.makeGameViewModel(for: difficulty)
    }

    func startNewGame(for difficulty: Difficulty) {
        controller.startNewGame(for: difficulty)
    }

    func toggleBedtimeMode() {
        let enabled = !controller.settings.bedtimeMode
        controller.updateSettings { settings in
            settings.toggleBedtimeMode(enabled)
        }
    }
}
