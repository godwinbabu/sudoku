import SwiftUI

/// First night (CODESPEC 12.3): welcome → Find my lowest glow → result. Shown once, the first time
/// Night is active while `calibrated` is false. Skip applies Lights out.
struct FirstNightView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psType) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.welcome

    enum Step { case welcome, calibrate, result }

    /// Always the Night palette, even if Night ends mid-flow (Day text would be dark on black).
    static func palette(_ settings: Settings) -> PSPalette { settings.palette(isNight: true) }

    private var theme: PSPalette { Self.palette(controller.settings) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch step {
            case .calibrate:
                // Centred, so the eye rests on the tiles.
                CalibrateView(theme: theme, settings: controller.settings) { pick in
                    controller.calibrate(pick: pick)
                    go(.result)
                }
                .padding(.horizontal, 22)
            case .welcome, .result:
                message
            }
        }
        .environment(\.psPalette, theme)
        // The system status bar is white in dark mode, brighter than any ink.
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("firstNight")
    }

    private var message: some View {
        let done = step == .result
        let kelvin = NightSheetView.kelvinText(controller.settings.warmth)
        let body = done
            ? "Warmth is \(kelvin). You can change both any time from the moon at the top of every screen."
            : "Before your first puzzle, let’s set the screen for your eyes and this room. It takes twenty seconds, and nothing will flash."
        return VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "moon")
                .font(.system(size: 30))
                .foregroundColor(theme.accent)
                .accessibilityHidden(true)
            let greeting = Self.greeting(hour: Calendar.current.component(.hour, from: Date()))
            Text(done ? "Glow set to \(Int(controller.settings.glow))%." : greeting)
                .font(.system(size: 36, weight: .medium, design: .serif))
                .foregroundColor(theme.ink)
                .padding(.top, 22)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.system(size: 17))
                .foregroundColor(theme.ink2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if done {
                SamplePreview(theme: theme, type: type).padding(.top, 10)
            }
            Spacer()
            Button {
                if done { controller.endFirstNight() } else { go(.calibrate) }
            } label: {
                Text(done ? "Start playing" : "Find my lowest glow").frame(maxWidth: .infinity)
            }
            .buttonStyle(PSButtonStyle(theme: theme, height: 50))
            .accessibilityIdentifier(done ? "firstNight_start" : "firstNight_calibrate")
            if !done {
                Button("Skip for now — use Lights out") { controller.skipFirstNight() }
                    .font(.system(size: 15))
                    .foregroundColor(theme.ink3)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .accessibilityIdentifier("firstNight_skip")
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 96)
        .padding(.bottom, 24)
    }

    /// The welcome heading by time of day: Night can first come on at any hour (Match iPhone, Night).
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private func go(_ next: Step) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { step = next }
    }
}
