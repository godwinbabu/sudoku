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

    func setAskBeforeHintResult(_ value: Bool) {
        controller.updateSettings { $0.askBeforeHintResult = value }
    }

    func setShortCellNames(_ value: Bool) {
        controller.updateSettings { $0.cellNameStyle = value ? .short : .long }
    }

    func setBedtimeMode(_ value: Bool) {
        controller.updateSettings { settings in
            settings.toggleBedtimeMode(value)
        }
    }

    func setActiveDisplayProfile(_ id: UUID) {
        controller.updateSettings { $0.activeDisplayProfileID = id }
    }

    func setBedtimeDisplayProfile(_ id: UUID?) {
        controller.updateSettings { $0.bedtimeDisplayProfileID = id }
    }

    func saveDisplayProfile(_ profile: DisplayProfile) {
        controller.updateSettings { $0.saveDisplayProfile(profile) }
    }

    func deleteDisplayProfile(_ id: UUID) {
        controller.updateSettings { $0.deleteDisplayProfile(id: id) }
    }

    var canAddDisplayProfile: Bool { controller.settings.displayProfiles.count < DisplayProfile.maxProfiles }

    func setKeepImportImages(_ value: Bool) {
        controller.updateSettings { $0.keepImportImages = value }
    }

    func clearImportedImages() {
        controller.clearImportedImages()
    }
}
