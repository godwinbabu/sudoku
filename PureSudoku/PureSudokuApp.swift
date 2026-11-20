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
        // In the strip updateDisplay reserves just below the safe area, so it never covers a control. No fill:
        // the screen's own background shows through.
        .overlay {
            if controller.settings.showBuildNumber {
                // Pure-black screens hide it but keep its strip, so the game does not shift under them.
                let hidden = controller.showsBlackout || controller.showsFirstNight
                // A game's Drift warms and dims its palette; the label follows it, as GameView does.
                let palette = controller.driftSteps > 0
                    ? DriftController.apply(steps: controller.driftSteps, to: controller.settings).palette(isNight: true)
                    : controller.palette
                GeometryReader { geometry in
                    // A fixed size, not Dynamic Type: larger text would outgrow the reserved strip.
                    Text(SettingsViewModel.appVersionLine)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(palette.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        // The reader ends at the safe area; the strip is the next buildLabelHeight points.
                        .position(x: geometry.size.width / 2, y: geometry.size.height + Self.buildLabelHeight / 2)
                        .opacity(hidden ? 0 : 1)
                        .accessibilityHidden(hidden)
                        .accessibilityIdentifier("buildLabel")
                }
                .allowsHitTesting(false)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: controller.showsNightSheet)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: controller.showsFirstNight)
        .environmentObject(controller)
        .environment(\.psPalette, controller.palette)
        .environment(\.psType, PSType(controller.settings.clarity))
        .preferredColorScheme(controller.preferredColorScheme)
        .persistentSystemOverlays(controller.hidesHomeIndicator || controller.showsFirstNight ? .hidden : .automatic)
        .onChangeOf(scenePhase) { _ in
            controller.objectWillChange.send() // After dark and Match iPhone may have changed while away
            updateDisplay()
        }
        .onChangeOf(controller.settings) { _ in updateDisplay() }
        // After dark can flip on any redraw (e.g. an autosave); Match iPhone flips Day ↔ Dark with iOS.
        // The look, not isNight: Day ↔ Dark keeps isNight false but changes the UIKit colours.
        .onChangeOf(controller.look) { _ in updateDisplay() }
        .onChangeOf(controller.driftSteps) { _ in updateDisplay() }
        .onChangeOf(controller.isCalibrating) { _ in updateDisplay() }
        .onChangeOf(colorScheme) { _ in controller.objectWillChange.send() }
        .onAppear(perform: updateDisplay)
        // Delivered on the main run loop: this closure is main-actor code (Swift 6 traps off it).
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .receive(on: RunLoop.main)) { _ in
            controller.objectWillChange.send() // Increase Contrast raises the Night floor (CODESPEC 9)
            updateDisplay()
        }
    }

    private func updateDisplay() {
        controller.updateFirstNight()
        let target = ScreenBrightnessController.target(phase: scenePhase, isNight: controller.isNight,
                                                       isCalibrating: controller.isCalibrating,
                                                       nightBacklight: controller.nightBacklight)
        brightness.update(target: target, request: [controller.settings.glow, controller.isCalibrating ? 1 : 0])
        SystemAppearance.apply(controller.palette)
        SystemAppearance.reserveBottom(controller.settings.showBuildNumber ? Self.buildLabelHeight : 0)
    }

    private static let buildLabelHeight: CGFloat = 16
}
