import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let settings = viewModel.settings
        NavigationStack {
            Form {
                // Interim Display & Night controls until the Night sheet (CODESPEC 12.2).
                Section("Appearance") {
                    Picker("Appearance", selection: Binding(get: { settings.appearance }, set: { viewModel.setAppearance($0) })) {
                        ForEach(Appearance.allCases) { Text($0.displayName).tag($0) }
                    }
                    .accessibilityIdentifier("settings_appearance")
                }
                .paletteRowBackground()
                Section("Night screen") {
                    let preset = Binding(get: { viewModel.currentPreset }, set: { (new: NightPreset?) in new.map(viewModel.applyPreset) })
                    Picker("Preset", selection: preset) {
                        ForEach(NightPreset.allCases) { Text($0.title).tag(Optional($0)) }
                        if viewModel.currentPreset == nil { Text("Custom").tag(NightPreset?.none) }
                    }
                    .accessibilityIdentifier("settings_preset")
                    VStack(alignment: .leading) {
                        Text("Glow \(Int(settings.glow))%")
                        Slider(value: Binding(get: { settings.glow }, set: { viewModel.setGlow($0) }), in: 0...100, step: 1)
                            .accessibilityIdentifier("settings_glow")
                    }
                    VStack(alignment: .leading) {
                        Text("Warmth \(Int(Blackbody.kelvin(forWarmth: settings.warmth)).formatted()) K")
                        Slider(value: Binding(get: { settings.warmth }, set: { viewModel.setWarmth($0) }), in: 0...100, step: 1)
                    }
                    Picker("Clarity", selection: Binding(get: { settings.clarity }, set: { viewModel.setClarity($0) })) {
                        ForEach(Clarity.allCases) { Text($0.displayName).tag($0) }
                    }
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
