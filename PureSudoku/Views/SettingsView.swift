import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

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
                    Picker("Bedtime brightness", selection: Binding(get: { viewModel.settings.sleepBrightness }, set: { viewModel.setSleepBrightness($0) })) {
                        ForEach(SleepBrightness.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .disabled(!viewModel.settings.bedtimeMode && viewModel.settings.theme != .sleep)
                    Text("Bedtime Mode forces the Bedtime theme, mutes sound/haptics, and adds an extra dimming overlay.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
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
        }
    }
}
