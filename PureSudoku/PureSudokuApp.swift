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

    var body: some View {
        MainMenuView(viewModel: MainMenuViewModel(controller: controller))
            .environmentObject(controller)
            .preferredColorScheme(controller.settings.preferredColorScheme)
            .overlay(SleepDimmingOverlay(opacity: controller.sleepOverlayOpacity))
    }
}
