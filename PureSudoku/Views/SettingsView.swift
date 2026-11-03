import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let settings = viewModel.settings
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        DisplaySettingsView(viewModel: viewModel)
                    } label: {
                        Text("Display & Night")
                    }
                    .accessibilityIdentifier("settings_display")
                }
                .paletteRowBackground()
                Section("Gameplay") {
                    Toggle("Show timer", isOn: Binding(get: { settings.showTimer }, set: { viewModel.setShowTimer($0) }))
                    Toggle("Tidy notes", isOn: Binding(get: { settings.tidyNotes }, set: { viewModel.setTidyNotes($0) }))
                    Picker("Show mistakes", selection: Binding(get: { settings.mistakes }, set: { viewModel.setMistakes($0) })) {
                        ForEach(MistakeMode.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                .paletteRowBackground()
                Section("Hints") {
                    Picker("Cell names", selection: Binding(get: { settings.notation }, set: { viewModel.setNotation($0) })) {
                        ForEach(CellNotation.allCases) { Text($0.displayName).tag($0) }
                    }
                    .accessibilityIdentifier("settings_notation")
                }
                .paletteRowBackground()
                Section("Imports") {
                    Toggle("Keep import images", isOn: Binding(
                        get: { settings.keepImportImages }, set: { viewModel.setKeepImportImages($0) }))
                    Button("Clear imported images", role: .destructive) {
                        viewModel.clearImportedImages()
                    }
                }
                .paletteRowBackground()
            }
            .themedTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings_done")
                }
            }
        }
    }
}
