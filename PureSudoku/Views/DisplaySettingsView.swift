import SwiftUI

/// Display & Night (CODESPEC 3.3, 12): the full page behind the Night sheet. Pushed from Journal.
struct DisplaySettingsView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Environment(\.psType) private var type
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    @State private var calibrating = false

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private static let appearances: [(Appearance, String)] = [
        (.day, "Warm paper. For daylight and lamps."),
        (.night, "Black screen, warm digits, silent."),
        (.afterDark, "Sunset to sunrise where you are."),
        (.matchSystem, "Follows Light and Dark in iOS Settings.")
    ]

    var body: some View {
        let settings = viewModel.settings
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HeaderIconButton(theme: theme, symbol: "chevron.left", label: "Back") {
                    if calibrating { calibrating = false } else { dismiss() }
                }
                .padding(.horizontal, 10)
                .frame(height: 48)
                .accessibilityIdentifier("display_back")
                if calibrating {
                    CalibrateView(theme: theme, settings: settings, onCancel: { calibrating = false }, onUse: {
                        viewModel.calibrate(pick: $0)
                        calibrating = false
                    })
                    .padding(.horizontal, 22)
                    .padding(.top, 40)
                } else {
                    content(settings)
                }
            }
            .padding(.bottom, 40)
        }
        .background(theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(controller.isNight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("displaySettings")
    }

    @ViewBuilder
    private func content(_ settings: Settings) -> some View {
        Text("Display & Night")
            .font(.system(size: 30, weight: .medium, design: .serif))
            .foregroundColor(theme.ink)
            .padding(.horizontal, 22)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
        PSCard(theme: theme) { SamplePreview(theme: theme, type: type) }
            .padding(.top, 10)
            .padding(.bottom, 24)

        SectionLabel(theme: theme, title: "Appearance")
        PSCard(theme: theme) {
            ForEach(Array(Self.appearances.enumerated()), id: \.offset) { index, item in
                appearanceRow(item.0, sub: item.1, selected: settings.appearance == item.0,
                              divider: index < Self.appearances.count - 1 || settings.appearance == .afterDark)
            }
            if settings.appearance == .afterDark { afterDarkHours(settings) }
        }
        .padding(.bottom, 24)

        SectionLabel(theme: theme, title: "Night screen")
        PresetChips(theme: theme, current: viewModel.currentPreset, idPrefix: "display_preset_", onSelect: viewModel.applyPreset)
            .padding(.bottom, 8)
        NightSliders(theme: theme, settings: settings,
                     glowNote: theme.isNight ? NightSheetView.glowNote(settings.glow) : "Applies when Night is on.",
                     warmthNote: "Higher is warmer, with less blue light.",
                     idPrefix: "display_", onGlow: viewModel.setGlow, onWarmth: viewModel.setWarmth)

        SectionLabel(theme: theme, title: "Your eyes").padding(.top, 8)
        PSCard(theme: theme) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clarity").font(.system(size: 16)).foregroundColor(theme.ink)
                PSSegmented(theme: theme, options: Clarity.allCases.map { ($0, $0.displayName) }, selection: settings.clarity,
                            idPrefix: "display_clarity_", onSelect: viewModel.setClarity)
                Text("Bigger, heavier digits and stronger lines. Day and Night.")
                    .font(.system(size: 13)).foregroundColor(theme.ink3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
            SettingRow(theme: theme, label: "Lowest readable glow",
                       sub: settings.calibrated ? "Set at \(Int(settings.glowFloor))%. Glow and Drift never go below it." : "Not set yet.",
                       last: true) {
                LinkButton(theme: theme, title: "Check again") { calibrating = true }
                    .accessibilityIdentifier("display_calibrate")
            }
        }
        .padding(.bottom, 24)

        quiet(settings)
    }

    @ViewBuilder
    private func quiet(_ settings: Settings) -> some View {
        SectionLabel(theme: theme, title: "Quiet")
        PSCard(theme: theme) {
            SettingRow(theme: theme, label: "Drift", sub: "Over 30 minutes, glow eases down and warmth eases up.") {
                PSToggle(theme: theme, isOn: settings.drift, label: "Drift", onChange: viewModel.setDrift)
            }
            SettingRow(theme: theme, label: "Hide status bar in games", sub: "Clock and battery give off light too.") {
                PSToggle(theme: theme, isOn: settings.hideStatusBarInGames, label: "Hide status bar in games",
                         onChange: viewModel.setHideStatusBar)
            }
            SettingRow(theme: theme, label: "Sounds") {
                PSToggle(theme: theme, isOn: settings.soundsEnabled, label: "Sounds", onChange: viewModel.setSounds)
            }
            SettingRow(theme: theme, label: "Vibration", sub: "Night always keeps sound and vibration off.", last: true) {
                PSToggle(theme: theme, isOn: settings.hapticsEnabled, label: "Vibration", onChange: viewModel.setHaptics)
            }
        }
        .padding(.bottom, 24)

        Text("Hush: tap with two fingers anywhere in a game to turn the screen black. Tap again to come back.")
            .font(.system(size: 13))
            .foregroundColor(theme.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
    }

    private func appearanceRow(_ appearance: Appearance, sub: String, selected: Bool, divider: Bool) -> some View {
        Button { viewModel.setAppearance(appearance) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appearance.displayName).font(.system(size: 16)).foregroundColor(theme.ink)
                    Text(sub).font(.system(size: 13)).foregroundColor(theme.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.accent)
                    .opacity(selected ? 1 : 0)
                    .frame(width: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { if divider { theme.hair.frame(height: 1) } }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("display_appearance_\(appearance.rawValue)")
    }

    /// The After dark block: tonight's sun times, or the fixed hours with − / + to change them.
    @ViewBuilder
    private func afterDarkHours(_ settings: Settings) -> some View {
        let scheduler = controller.afterDark
        let tonight = settings.useLocationForAfterDark ? scheduler.tonight() : nil
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(tonight == nil ? "Hours" : "Tonight").font(.system(size: 15)).foregroundColor(theme.ink)
                Spacer()
                Text(tonight.map { "Sunset \($0.sunset.shortTime) → sunrise \($0.sunrise.shortTime)" }
                     ?? "\(settings.afterDarkStart.formatted) → \(settings.afterDarkEnd.formatted)")
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundColor(theme.ink2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("display_afterDarkHours")
            Text(afterDarkNote(settings, hasSun: tonight != nil, denied: scheduler.isLocationDenied))
                .font(.system(size: 13))
                .foregroundColor(theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
            if tonight == nil {
                hourStepper("Night starts", settings.afterDarkStart, start: true)
                hourStepper("Night ends", settings.afterDarkEnd, start: false)
            }
            Button(settings.useLocationForAfterDark ? "Use fixed hours instead" : "Use sunset and sunrise") {
                viewModel.setUsesSun(!settings.useLocationForAfterDark)
            }
            .font(.system(size: 13))
            .foregroundColor(theme.ink2)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Capsule().strokeBorder(theme.hair, lineWidth: 1).frame(height: 32))
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityIdentifier("display_afterDarkSource")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func afterDarkNote(_ settings: Settings, hasSun: Bool, denied: Bool) -> String {
        if hasSun { return "Worked out on this iPhone from your rough location and the date. Nothing leaves the phone." }
        if settings.useLocationForAfterDark && denied {
            return "Location is off for PureSudoku in iOS Settings, so fixed hours are used."
        }
        return "No location, so fixed hours are used. Use − and + to change a time."
    }

    private func hourStepper(_ title: String, _ time: ClockTime, start: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 15)).foregroundColor(theme.ink2)
            Spacer()
            stepButton("minus", label: "Earlier") { viewModel.shiftAfterDark(start: start, by: -15) }
            Text(time.formatted)
                .font(.system(size: 15).monospacedDigit())
                .foregroundColor(theme.ink)
                .frame(minWidth: 76)
            stepButton("plus", label: "Later") { viewModel.shiftAfterDark(start: start, by: 15) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.ink2)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(theme.hair, lineWidth: 1).frame(width: 32, height: 32))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
