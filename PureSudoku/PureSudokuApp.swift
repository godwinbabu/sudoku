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
            .onChange(of: scenePhase) { _ in updateBrightness() }
            .onChange(of: controller.settings) { _ in updateBrightness() }
            .onAppear(perform: updateBrightness)
    }

    /// Lowers the screen only while the app is active in the Sleep theme and the profile asks for it.
    private func updateBrightness() {
        let settings = controller.settings
        brightness.update(lower: scenePhase == .active && settings.themeEffective == .sleep && settings.currentDisplayProfile.lowersScreenBrightness)
    }
}
