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

    func setAppearance(_ value: Appearance) {
        controller.updateSettings { $0.appearance = value }
    }

    /// The preset matching the current glow and warmth, if any.
    var currentPreset: NightPreset? {
        NightPreset.allCases.first { $0.glow == settings.glow && $0.warmth == settings.warmth }
    }

    func applyPreset(_ preset: NightPreset) {
        controller.updateSettings { $0.apply(preset) }
    }

    func setGlow(_ value: Double) {
        controller.updateSettings { $0.glow = max(value, $0.glowFloor) }
    }

    func setWarmth(_ value: Double) {
        controller.updateSettings { $0.warmth = value }
    }

    func setClarity(_ value: Clarity) {
        controller.updateSettings { $0.clarity = value }
    }

    func setShowTimer(_ value: Bool) {
        controller.updateSettings { $0.showTimer = value }
    }

    func setTidyNotes(_ value: Bool) {
        controller.updateSettings { $0.tidyNotes = value }
    }

    func setMistakes(_ value: MistakeMode) {
        controller.updateSettings { $0.mistakes = value }
    }

    func setNotation(_ value: CellNotation) {
        controller.updateSettings { $0.notation = value }
    }

    func setKeepImportImages(_ value: Bool) {
        controller.updateSettings { $0.keepImportImages = value }
    }

    func clearImportedImages() {
        controller.clearImportedImages()
    }
}
