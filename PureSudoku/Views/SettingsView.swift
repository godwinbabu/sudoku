import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: Binding(get: { viewModel.settings.theme }, set: { viewModel.setTheme($0) })) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .disabled(viewModel.settings.bedtimeMode)
                }
                Section("Gameplay") {
                    Toggle("Show timer", isOn: Binding(get: { viewModel.settings.showTimer }, set: { viewModel.setShowTimer($0) }))
                    Toggle("Auto remove candidates", isOn: Binding(get: { viewModel.settings.autoRemoveCandidates }, set: { viewModel.setAutoRemoveCandidates($0) }))
                    Toggle("Auto-check mistakes", isOn: Binding(get: { viewModel.settings.autoCheckMistakes }, set: { viewModel.setAutoCheckMistakes($0) }))
                }
                Section("Bedtime") {
                    Toggle("Bedtime Mode", isOn: Binding(get: { viewModel.settings.bedtimeMode }, set: { viewModel.setBedtimeMode($0) }))
                    Picker("Sleep brightness", selection: Binding(get: { viewModel.settings.sleepBrightness }, set: { viewModel.setSleepBrightness($0) })) {
                        ForEach(SleepBrightness.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .disabled(!viewModel.settings.bedtimeMode && viewModel.settings.theme != .sleep)
                    Text("Bedtime Mode forces Sleep theme, mutes sound/haptics, and adds an extra dimming overlay.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
