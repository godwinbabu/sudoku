import SwiftUI

@main
struct PureSudokuApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(controller)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var brightness = ScreenBrightnessController()

    var body: some View {
        ZStack {
            MainMenuView(viewModel: MainMenuViewModel(controller: controller))
            // Custom panels over every screen, never system sheets, so nothing renders light at night.
            if controller.showsNightSheet {
                NightSheetView(viewModel: SettingsViewModel(controller: controller)).transition(.opacity).zIndex(1)
            }
            if controller.showsFirstNight {
                FirstNightView().transition(.opacity).zIndex(2)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: controller.showsNightSheet)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: controller.showsFirstNight)
        .environmentObject(controller)
        .environment(\.psPalette, controller.palette)
        .environment(\.psType, PSType(controller.settings.clarity))
        .preferredColorScheme(controller.preferredColorScheme)
        .onChange(of: scenePhase) { _ in
            controller.objectWillChange.send() // After dark and Match iPhone may have changed while away
            updateDisplay()
        }
        .onChange(of: controller.settings) { _ in updateDisplay() }
        // After dark can flip on any redraw (e.g. an autosave); Match iPhone flips with iOS dark mode.
        .onChange(of: controller.isNight) { _ in updateDisplay() }
        .onChange(of: colorScheme) { _ in controller.objectWillChange.send() }
        .onAppear(perform: updateDisplay)
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)) { _ in
            controller.objectWillChange.send() // Increase Contrast raises the Night floor (CODESPEC 9)
            updateDisplay()
        }
    }

    private func updateDisplay() {
        controller.updateFirstNight()
        brightness.update(lower: ScreenBrightnessController.shouldLower(phase: scenePhase, isNight: controller.isNight))
        SystemAppearance.apply(controller.palette)
    }
}
