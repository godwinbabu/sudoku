import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: Settings

    private let controller: AppController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: AppController) {
        self.controller = controller
        self.settings = controller.settings

        controller.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] newSettings in
                self?.settings = newSettings
            }
            .store(in: &cancellables)
    }

    func setTheme(_ theme: AppTheme) {
        controller.updateSettings { settings in
            settings.updateTheme(theme)
        }
    }

    func setShowTimer(_ value: Bool) {
        controller.updateSettings { $0.showTimer = value }
    }

    func setAutoRemoveCandidates(_ value: Bool) {
        controller.updateSettings { $0.autoRemoveCandidates = value }
    }

    func setAutoCheckMistakes(_ value: Bool) {
        controller.updateSettings { $0.autoCheckMistakes = value }
    }

    func setBedtimeMode(_ value: Bool) {
        controller.updateSettings { settings in
            settings.toggleBedtimeMode(value)
        }
    }

    func setSleepBrightness(_ brightness: SleepBrightness) {
        controller.updateSettings { $0.sleepBrightness = brightness }
    }
}
