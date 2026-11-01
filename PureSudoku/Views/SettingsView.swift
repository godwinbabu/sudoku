import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: Binding(get: { viewModel.settings.theme }, set: { viewModel.setTheme($0) })) {
                        ForEach(AppTheme.allCases.filter { $0 != .sleep }) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }
                .sleepRowBackground()
                Section("Gameplay") {
                    Toggle("Show timer", isOn: Binding(get: { viewModel.settings.showTimer }, set: { viewModel.setShowTimer($0) }))
                    Toggle("Auto remove candidates", isOn: Binding(get: { viewModel.settings.autoRemoveCandidates }, set: { viewModel.setAutoRemoveCandidates($0) }))
                    Toggle("Auto-check mistakes", isOn: Binding(get: { viewModel.settings.autoCheckMistakes }, set: { viewModel.setAutoCheckMistakes($0) }))
                }
                .sleepRowBackground()
                Section("Hints") {
                    Toggle("Ask before showing the answer", isOn: Binding(get: { viewModel.settings.askBeforeHintResult }, set: { viewModel.setAskBeforeHintResult($0) }))
                    Toggle("Short cell names (r3c5)", isOn: Binding(get: { viewModel.settings.cellNameStyle == .short }, set: { viewModel.setShortCellNames($0) }))
                }
                .sleepRowBackground()
                Section("Bedtime") {
                    Toggle("Bedtime Mode", isOn: Binding(get: { viewModel.settings.bedtimeMode }, set: { viewModel.setBedtimeMode($0) }))
                    Text("Bedtime Mode forces the Bedtime theme, mutes sound and haptics, and uses your bedtime display.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .sleepRowBackground()
                displaySection
                    .sleepRowBackground()
                Section("Imports") {
                    Toggle("Keep import images", isOn: Binding(get: { viewModel.settings.keepImportImages }, set: { viewModel.setKeepImportImages($0) }))
                    Button("Clear imported images", role: .destructive) {
                        viewModel.clearImportedImages()
                    }
                }
                .sleepRowBackground()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings_done")
                }
            }
            .sheet(item: $calibrating) { profile in
                NavigationStack {
                    DisplayCalibrationView(profile: profile, onSave: { saved in
                        viewModel.saveDisplayProfile(saved)
                        calibrating = nil
                    }, onCancel: { calibrating = nil })
                }
            }
        }
    }

    @State private var calibrating: DisplayProfile?

    /// Bedtime display profiles (CODESPEC 12.3).
    private var displaySection: some View {
        let settings = viewModel.settings
        let current = settings.displayProfiles.first { $0.id == settings.activeDisplayProfileID } ?? settings.displayProfiles[0]
        return Section("Bedtime display") {
            Picker("Display", selection: Binding(get: { settings.activeDisplayProfileID }, set: { viewModel.setActiveDisplayProfile($0) })) {
                ForEach(settings.displayProfiles) { Text($0.name).tag($0.id) }
            }
            .accessibilityIdentifier("settings_displayProfile")
            Picker("Bedtime Mode uses", selection: Binding(get: { settings.bedtimeDisplayProfileID }, set: { viewModel.setBedtimeDisplayProfile($0) })) {
                Text("Same as above").tag(UUID?.none)
                ForEach(settings.displayProfiles) { Text($0.name).tag(Optional($0.id)) }
            }
            Button("Adjust “\(current.name)”") { calibrating = current }
                .accessibilityIdentifier("settings_adjustDisplay")
            Button("Calibrate a new display") {
                calibrating = DisplayProfile(
                    name: "Profile \(settings.displayProfiles.count + 1)",
                    dimness: current.dimness, contrast: current.contrast, warmth: current.warmth, textSize: current.textSize
                )
            }
            .disabled(!viewModel.canAddDisplayProfile)
            if settings.displayProfiles.count > 1 {
                Button("Delete “\(current.name)”", role: .destructive) { viewModel.deleteDisplayProfile(current.id) }
            }
        }
    }
}
