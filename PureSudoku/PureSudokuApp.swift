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
    @State private var brightness = ScreenBrightnessController()

    var body: some View {
        MainMenuView(viewModel: MainMenuViewModel(controller: controller))
            .environmentObject(controller)
            .preferredColorScheme(controller.settings.preferredColorScheme)
            .onChange(of: scenePhase) { _ in updateDisplay() }
            .onChange(of: controller.settings) { _ in updateDisplay() }
            .onAppear(perform: updateDisplay)
            .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)) { _ in
                controller.objectWillChange.send() // Increase Contrast changes the Sleep floors (CODESPEC 9)
                updateDisplay()
            }
    }

    private func updateDisplay() {
        let settings = controller.settings
        brightness.update(lower: ScreenBrightnessController.shouldLower(phase: scenePhase, settings: settings))
        let palette = settings.themeEffective == .sleep
            ? SleepPalette(profile: settings.currentDisplayProfile, increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled)
            : nil
        SystemAppearance.apply(palette)
    }
}
