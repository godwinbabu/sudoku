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
        controller.setAppearance(value)
    }

    /// The preset matching the current glow and warmth (after the floor), if any.
    var currentPreset: NightPreset? { NightPreset.matching(settings) }

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

    func setDrift(_ value: Bool) {
        controller.updateSettings { $0.drift = value }
    }

    func setHideStatusBar(_ value: Bool) {
        controller.updateSettings { $0.hideStatusBarInGames = value }
    }

    func setSounds(_ value: Bool) {
        controller.updateSettings { $0.soundsEnabled = value }
    }

    func setHaptics(_ value: Bool) {
        controller.updateSettings { $0.hapticsEnabled = value }
    }

    func setUsesSun(_ value: Bool) {
        controller.setUsesSunForAfterDark(value)
    }

    /// Moves an After dark fixed hour by `minutes`, wrapping around midnight.
    func shiftAfterDark(start: Bool, by minutes: Int) {
        controller.updateSettings {
            let time = start ? $0.afterDarkStart : $0.afterDarkEnd
            let total = ((time.minutes + minutes) % 1440 + 1440) % 1440
            let shifted = ClockTime(hour: total / 60, minute: total % 60)
            if start { $0.afterDarkStart = shifted } else { $0.afterDarkEnd = shifted }
        }
    }

    func calibrate(pick: Double) {
        controller.calibrate(pick: pick)
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
