import SwiftUI

/// The Display sheet (CODESPEC 11.2, 11.3), opened by the moon anywhere. A custom panel over
/// the app, not a system sheet, so it never renders light at night. Changing Appearance re-themes it
/// at once, and the screen behind repaints live.
struct NightSheetView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: SettingsViewModel
    @State private var calibrating = false

    /// The model is an autoclosure: StateObject builds it once, not on every parent redraw (issue 70).
    init(viewModel: @autoclosure @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        let settings = viewModel.settings
        ZStack(alignment: .bottom) {
            backdrop
            VStack(spacing: 0) {
                Capsule().fill(theme.ink2.opacity(0.5)).frame(width: 36, height: 5).padding(.bottom, 10)
                    .accessibilityHidden(true)
                // As tall as its controls when they fit; scrolls when they don't (small phones, large text).
                // The side padding sits inside the scroll view, so a drag anywhere across the panel scrolls it.
                ViewThatFits(in: .vertical) {
                    panel(settings).padding([.horizontal, .bottom], 16)
                    ScrollView(showsIndicators: false) { panel(settings).padding([.horizontal, .bottom], 16) }
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .background(
                SheetTop(closed: true).fill(theme.bg)
                    .overlay(SheetTop(closed: false).stroke(theme.isNight ? theme.edge : theme.hair, lineWidth: 1))
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
            .padding(.horizontal, 6)
            .padding(.top, 6)
        } else {
            VStack(alignment: .leading, spacing: 0) { controls(settings) }
        }
    }

    private var backdrop: some View {
        (theme.isNight || theme.isDark ? Color.black.opacity(0.55) : Color.black.opacity(0.18))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
            .accessibilityLabel("Close Display")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func controls(_ settings: Settings) -> some View {
        header
        preview
        groupLabel("Appearance")
        PSSegmented(theme: theme, options: Appearance.allCases.map { ($0, $0.displayName) },
                    selection: shownAppearance(settings), idPrefix: "night_appearance_", onSelect: viewModel.setAppearance)
        VStack(spacing: 0) {
            row(title: "Night after dark", sub: "Switches at sunset, back at sunrise") {
                PSToggle(theme: theme, isOn: settings.nightAfterDark, label: "Night after dark", onChange: viewModel.setNightAfterDark)
                    .accessibilityIdentifier("night_afterDark")
            }
            if settings.nightAfterDark && settings.appearance != .night {
                AfterDarkHours(theme: theme, settings: settings, viewModel: viewModel)
                    .overlay(alignment: .top) { theme.line.frame(height: 1) }
            }
        }
        .psCard(theme, radius: 26)
        .padding(.top, 10)

        groupLabel("Night")
        PSSegmented(theme: theme, options: NightPreset.allCases.map { ($0, $0.title) }, selection: viewModel.currentPreset,
                    idPrefix: "night_preset_", onSelect: viewModel.applyPreset)
        VStack(spacing: 0) {
            sliderRow("Glow", value: settings.glow, valueText: "\(Int(settings.glow))%", id: "night_glow", onChange: viewModel.setGlow)
            sliderRow("Warmth", value: settings.warmth, valueText: Self.kelvinText(settings.warmth), id: "night_warmth",
                      onChange: viewModel.setWarmth)
                .overlay(alignment: .top) { theme.line.frame(height: 1) }
            PSAdaptiveStack(spacing: 12) {
                Text("Clarity").psFont(16, weight: .semibold).foregroundStyle(theme.ink).frame(minWidth: 68, alignment: .leading)
                PSSegmented(theme: theme, options: Clarity.allCases.map { ($0, $0.displayName) }, selection: settings.clarity,
                            idPrefix: "night_clarity_", onSelect: viewModel.setClarity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .overlay(alignment: .top) { theme.line.frame(height: 1) }
            row(title: "Drift", sub: "Dims and warms slowly over 30 minutes") {
                PSToggle(theme: theme, isOn: settings.drift, label: "Drift", onChange: viewModel.setDrift)
                    .accessibilityIdentifier("night_drift")
            }
            .overlay(alignment: .top) { theme.line.frame(height: 1) }
        }
        .psCard(theme, radius: 26)
        .padding(.top, 10)

        Button { calibrating = true } label: {
            Text("Find my lowest glow").frame(maxWidth: .infinity)
        }
        .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 48))
        .padding(.top, 14)
        .accessibilityIdentifier("night_calibrate")
    }

    /// Until the system style is adopted, the segment shows what is drawn by day.
    private func shownAppearance(_ settings: Settings) -> Appearance {
        guard settings.adoptsSystemStyle, settings.appearance != .night else { return settings.appearance }
        return theme.isDark ? .dark : .light
    }

    private var header: some View {
        HStack {
            Text("Display")
                .psFont(28, weight: .heavy, design: .serif)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Done", action: close)
                .psFont(16, weight: .bold)
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 4)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityIdentifier("night_close")
        }
        .frame(minHeight: 44)
    }

    /// Two givens and two entries in the current settings (CODESPEC 11.3).
    private var preview: some View {
        HStack(spacing: 26) {
            ForEach(Array([("2", true), ("6", false), ("9", true), ("8", false)].enumerated()), id: \.offset) { _, item in
                Text(item.0)
                    .font(PSFont.fixed(30, weight: item.1 ? .heavy : .medium).monospacedDigit())
                    .foregroundStyle(item.1 ? theme.ink : theme.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .psCard(theme, radius: 18)
        .padding(.top, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview: given digits 2 and 9, entered digits 6 and 8")
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .psFont(15, weight: .semibold)
            .foregroundStyle(theme.ink2)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 4)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func row(title: String, sub: String, @ViewBuilder control: () -> some View) -> some View {
        PSAdaptiveStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).psFont(16, weight: .semibold).foregroundStyle(theme.ink)
                Text(sub).psFont(13).foregroundStyle(theme.ink2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
    }

    private func sliderRow(_ title: String, value: Double, valueText: String, id: String,
                           onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title).psFont(16, weight: .semibold).foregroundStyle(theme.ink).frame(minWidth: 68, alignment: .leading)
            PSSlider(theme: theme, value: value, label: title, valueText: valueText, onChange: onChange)
                .accessibilityIdentifier(id)
            Text(valueText)
                .psFont(13, monospacedDigit: true)
                .foregroundStyle(theme.ink2)
                .frame(minWidth: 52, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }

    private func close() {
        controller.showsNightSheet = false
    }

    static func kelvinText(_ warmth: Double) -> String {
        "\(Int(Blackbody.kelvin(forWarmth: warmth))) K"
    }
}

/// Night after dark's hours: tonight's sun times, or the fixed hours with − / + (15 min steps), and the
/// switch between the two. Location is used only from here, and only when chosen (CODESPEC 11.3).
private struct AfterDarkHours: View {
    @EnvironmentObject private var controller: AppController
    let theme: PSPalette
    let settings: Settings
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        let scheduler = controller.afterDark
        let tonight = settings.useLocationForAfterDark ? scheduler.tonight() : nil
        VStack(alignment: .leading, spacing: 8) {
            PSAdaptiveStack(alignment: .firstTextBaseline) {
                Text(tonight == nil ? "Hours" : "Tonight").psFont(15).foregroundStyle(theme.ink)
                Spacer(minLength: 0)
                Text(tonight.map { "Sunset \($0.sunset.shortTime) → sunrise \($0.sunrise.shortTime)" }
                     ?? "\(settings.afterDarkStart.formatted) → \(settings.afterDarkEnd.formatted)")
                    .psFont(15, monospacedDigit: true)
                    .foregroundStyle(theme.ink2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("night_afterDarkHours")
            Text(note(hasSun: tonight != nil, denied: scheduler.isLocationDenied))
                .psFont(13)
                .foregroundStyle(theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if tonight == nil {
                hourStepper("Night starts", settings.afterDarkStart, start: true)
                hourStepper("Night ends", settings.afterDarkEnd, start: false)
            }
            Button(settings.useLocationForAfterDark ? "Use fixed hours instead" : "Use sunset and sunrise") {
                viewModel.setUsesSun(!settings.useLocationForAfterDark)
            }
            .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 36))
            .accessibilityIdentifier("night_afterDarkSource")
        }
        .padding(16)
    }

    private func note(hasSun: Bool, denied: Bool) -> String {
        if hasSun { return "Worked out on this iPhone from your rough location and the date. Nothing leaves the phone." }
        if settings.useLocationForAfterDark && denied {
            return "Location is off for Sudoku Masters in iOS Settings, so fixed hours are used."
        }
        return "No location, so fixed hours are used. Use − and + to change a time."
    }

    private func hourStepper(_ title: String, _ time: ClockTime, start: Bool) -> some View {
        PSAdaptiveStack(spacing: 4) {
            Text(title).psFont(15).foregroundStyle(theme.ink2)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                stepButton("minus", label: "Earlier") { viewModel.shiftAfterDark(start: start, by: -15) }
                Text(time.formatted)
                    .psFont(15, monospacedDigit: true)
                    .foregroundStyle(theme.ink)
                    .frame(minWidth: 76)
                stepButton("plus", label: "Later") { viewModel.shiftAfterDark(start: start, by: 15) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium)) // fixed: it sits in a 32 pt ring
                .foregroundStyle(theme.ink2)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(theme.hair, lineWidth: 1).frame(width: 32, height: 32))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
