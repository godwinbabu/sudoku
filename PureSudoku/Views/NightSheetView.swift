import SwiftUI

/// The Night sheet (CODESPEC 12.2), opened from the moon. A custom bottom panel over the app, not a
/// system sheet, so it never renders light at night. The screen behind repaints live.
struct NightSheetView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: SettingsViewModel
    @State private var calibrating = false

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let settings = viewModel.settings
        ZStack(alignment: .bottom) {
            backdrop
            VStack(spacing: 0) {
                Capsule().fill(theme.hair).frame(width: 36, height: 5).padding(.bottom, 6)
                // Scrolls only when the controls do not fit (iPhone SE, large text).
                ViewThatFits(in: .vertical) {
                    panel(settings)
                    ScrollView(showsIndicators: false) { panel(settings) }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(
                SheetTop(closed: true).fill(theme.bg)
                    .overlay(SheetTop(closed: false).stroke(theme.hair, lineWidth: 1))
                    .ignoresSafeArea(edges: .bottom)
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("nightSheet")
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: calibrating)
            // The backdrop always shows above the panel, so a tap there can close it.
            .padding(.top, 56)
        }
        // The system status bar is white in dark mode, brighter than any ink.
        .statusBarHidden(theme.isNight)
    }

    @ViewBuilder
    private func panel(_ settings: Settings) -> some View {
        if calibrating {
            CalibrateView(theme: theme, settings: settings, onCancel: { calibrating = false }, onUse: {
                viewModel.calibrate(pick: $0)
                calibrating = false
            })
            .padding(.horizontal, 22)
            .padding(.top, 6)
        } else {
            VStack(spacing: 0) { controls(settings) }
        }
    }

    private var backdrop: some View {
        // Black at 55% at night; warm brown at 18% in Day.
        (theme.isNight ? Color.black.opacity(0.55) : Color(.sRGB, red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.18))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
            .accessibilityLabel("Close Night")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func controls(_ settings: Settings) -> some View {
        let nightControls = settings.appearance != .day
        let night = PSPalette.night(glow: settings.glow, warmth: settings.warmth, clarity: settings.clarity)
        HStack {
            Text("Night")
                .font(.system(size: 26, weight: .medium, design: .serif))
                .foregroundColor(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HeaderIconButton(theme: theme, symbol: "xmark", label: "Close", action: close)
                .accessibilityIdentifier("night_close")
        }
        .padding(.leading, 22)
        .padding(.trailing, 12)
        .padding(.bottom, 6)

        VStack(alignment: .leading, spacing: 4) {
            PSSegmented(theme: theme, options: [(Appearance.day, "Day"), (.night, "Night"), (.afterDark, "After dark")],
                        selection: settings.appearance == .matchSystem ? nil : settings.appearance,
                        idPrefix: "night_appearance_", onSelect: viewModel.setAppearance)
            if settings.appearance == .afterDark {
                Text(afterDarkNote(settings))
                    .font(.system(size: 13))
                    .foregroundColor(theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)

        if nightControls {
            PresetChips(theme: theme, current: viewModel.currentPreset, idPrefix: "night_preset_", onSelect: viewModel.applyPreset)
            NightSliders(theme: theme, settings: settings, glowNote: Self.glowNote(settings.glow),
                         warmthNote: "Blue light about \(night.blueReduction)% lower than daylight white.",
                         idPrefix: "night_", onGlow: viewModel.setGlow, onWarmth: viewModel.setWarmth)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Clarity").font(.system(size: 16)).foregroundColor(theme.ink)
            PSSegmented(theme: theme, options: Clarity.allCases.map { ($0, $0.displayName) }, selection: settings.clarity,
                        idPrefix: "night_clarity_", onSelect: viewModel.setClarity)
            Text("Bigger, heavier digits and stronger lines. Readable at lower glow.")
                .font(.system(size: 13))
                .foregroundColor(theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)

        if nightControls {
            VStack(spacing: 0) {
                SettingRow(theme: theme, label: "Drift", sub: "Over 30 minutes, glow eases down and warmth eases up.") {
                    PSToggle(theme: theme, isOn: settings.drift, label: "Drift", onChange: viewModel.setDrift)
                        .accessibilityIdentifier("night_drift")
                }
                SettingRow(theme: theme, label: "Find my lowest glow",
                           sub: "A 20-second check of what your eyes can read tonight.", last: true) {
                    LinkButton(theme: theme, title: "Start") { calibrating = true }
                        .accessibilityIdentifier("night_calibrate")
                }
            }
            .padding(.horizontal, 6)
            .overlay(alignment: .top) { theme.hair.frame(height: 1) }
        }
    }

    private func afterDarkNote(_ settings: Settings) -> String {
        let hours = "\(settings.afterDarkStart.formatted) to \(settings.afterDarkEnd.formatted)"
        if controller.afterDark.usesSun(settings), let tonight = controller.afterDark.tonight() {
            return "Night from sunset (\(tonight.sunset.shortTime)) to sunrise, worked out on this iPhone. Without location: \(hours)."
        }
        return "Night from \(hours). Without location, fixed hours are used."
    }

    private func close() {
        controller.showsNightSheet = false
    }

    static func glowNote(_ glow: Double) -> String {
        glow <= PSPalette.paletteGlowRange ? "Below your iPhone’s lowest brightness." : "Above 40%, the screen itself gets brighter."
    }

    static func kelvinText(_ warmth: Double) -> String {
        "\(Int(Blackbody.kelvin(forWarmth: warmth)).formatted()) K"
    }
}

/// The sheet's top edge: a 28 pt radius. Closed for the fill; open (top and corners only) for the hairline.
struct SheetTop: Shape {
    let closed: Bool
    var radius: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: closed ? rect.maxY : rect.minY + radius))
        if closed { path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius)) }
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

extension ClockTime {
    /// "9:00 PM" in the device's locale.
    var formatted: String {
        (Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()).shortTime
    }
}

extension Date {
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}
