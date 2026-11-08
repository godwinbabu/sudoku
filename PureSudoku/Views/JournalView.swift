import SwiftUI

/// The Journal tab (CODESPEC 3.3, Design/v2/README.md "Journal"): streak and week, the solved table,
/// Settings → Display & Night, Assists, Imports and Privacy. Every control is drawn from the palette.
struct JournalView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @StateObject private var viewModel: StatsViewModel
    @StateObject private var settingsModel: SettingsViewModel
    @State private var confirmsClear = false

    init(viewModel: StatsViewModel, settings: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _settingsModel = StateObject(wrappedValue: settings)
    }

    var body: some View {
        let settings = settingsModel.settings
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHead(title: "Journal")
                streak
                SectionLabel(theme: theme, title: "Solved")
                solved.padding(.bottom, 26)
                SectionLabel(theme: theme, title: "Settings")
                PSCard(theme: theme) {
                    NavigationLink {
                        DisplaySettingsView(viewModel: SettingsViewModel(controller: controller))
                    } label: {
                        SettingRow(theme: theme, label: "Display & Night", sub: "Day, Night, glow, warmth, clarity, quiet", last: true) {
                            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(theme.ink3)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings_display")
                }
                .padding(.bottom, 26)
                SectionLabel(theme: theme, title: "Assists")
                assists(settings).padding(.bottom, 26)
                SectionLabel(theme: theme, title: "Imports")
                imports(settings).padding(.bottom, 26)
                SectionLabel(theme: theme, title: "Privacy")
                Text("Everything stays on this iPhone. No account, no network, no analytics. "
                     + "Silent by design — no sounds or vibration unless you turn them on.")
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundColor(theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
            }
            .padding(.bottom, 24)
        }
        .overlay {
            if confirmsClear {
                ConfirmPanel(theme: theme, title: "Clear all import photos?",
                             message: "Your imported puzzles stay; only their photos are removed from this iPhone.",
                             cancel: "Cancel", confirm: "Clear", onCancel: { confirmsClear = false }, onDismiss: { confirmsClear = false }, onConfirm: {
                    settingsModel.clearImportedImages()
                    confirmsClear = false
                })
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journalView")
    }

    private var streak: some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.streak())")
                    .font(.system(size: 56, weight: .medium, design: .serif).monospacedDigit())
                    .foregroundColor(theme.ink)
                Text("nights in a row").font(.system(size: 14)).foregroundColor(theme.ink3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journal_streak")
            HStack(spacing: 4) {
                ForEach(Array(viewModel.week().enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 6) {
                        // Solved: a filled dot; not solved: a ring. Shape, not hue, carries it.
                        Circle()
                            .fill(item.solved ? theme.accent : .clear)
                            .overlay(Circle().strokeBorder(item.solved ? .clear : theme.ink3, lineWidth: 1.5))
                            .frame(width: 10, height: 10)
                        Text(item.day).font(.system(size: 11)).foregroundColor(theme.ink3)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.name), \(item.solved ? "solved" : "not solved")")
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 26)
    }

    private var solved: some View {
        PSCard(theme: theme) {
            tableRow("", "Solved", "Best", "Typical", header: true)
            ForEach(Difficulty.allCases) { level in
                tableRow(level.displayName, viewModel.solvedText(for: level),
                         viewModel.formattedBestTime(for: level), viewModel.formattedTypicalTime(for: level))
                    .accessibilityLabel(viewModel.rowLabel(for: level))
                    .accessibilityIdentifier("journal_row_\(level.rawValue)")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.assistedLine).accessibilityIdentifier("journal_assisted")
                Text(viewModel.totalsLine)
            }
            .font(.system(size: 13))
            .foregroundColor(theme.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func tableRow(_ level: String, _ count: String, _ best: String, _ typical: String, header: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(level).foregroundColor(theme.ink).frame(maxWidth: .infinity, alignment: .leading)
            Text(count).frame(width: 60, alignment: .trailing)
            Text(best).frame(width: 70, alignment: .trailing)
            Text(typical).frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: header ? 12 : 15).monospacedDigit())
        .foregroundColor(header ? theme.ink3 : theme.ink2)
        .padding(.horizontal, 16)
        .padding(.vertical, header ? 10 : 12)
        .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private func assists(_ settings: Settings) -> some View {
        PSCard(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Show mistakes").font(.system(size: 16)).foregroundColor(theme.ink)
                PSSegmented(theme: theme, options: MistakeMode.allCases.map { ($0, $0.displayName) }, selection: settings.mistakes,
                            idPrefix: "journal_mistakes_", onSelect: settingsModel.setMistakes)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
            SettingRow(theme: theme, label: "Tidy notes", sub: "Placing a digit removes it from notes in the same row, column and box.") {
                PSToggle(theme: theme, isOn: settings.tidyNotes, label: "Tidy notes", onChange: settingsModel.setTidyNotes)
                    .accessibilityIdentifier("journal_tidyNotes")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Cell names in hints").font(.system(size: 16)).foregroundColor(theme.ink)
                PSSegmented(theme: theme, options: CellNotation.allCases.map { ($0, $0.displayName) }, selection: settings.notation,
                            idPrefix: "journal_notation_", onSelect: settingsModel.setNotation)
                Text(settings.notation == .grid ? "Short grid codes: R for row, C for column, B for box." : "Written out in words.")
                    .font(.system(size: 13)).foregroundColor(theme.ink3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { theme.hair.frame(height: 1) }
            SettingRow(theme: theme, label: "Coach when I'm stuck",
                       sub: "After two minutes without a new digit, Hint walks you through the patterns on your board.") {
                PSToggle(theme: theme, isOn: settings.coachWhenStuck, label: "Coach when I'm stuck",
                         onChange: settingsModel.setCoachWhenStuck)
                    .accessibilityIdentifier("journal_coachWhenStuck")
            }
            SettingRow(theme: theme, label: "Show timer", last: true) {
                PSToggle(theme: theme, isOn: settings.showTimer, label: "Show timer", onChange: settingsModel.setShowTimer)
                    .accessibilityIdentifier("journal_showTimer")
            }
        }
    }

    /// Kept from the old Settings screen, which had no other home for them.
    private func imports(_ settings: Settings) -> some View {
        PSCard(theme: theme) {
            SettingRow(theme: theme, label: "Keep import photos", sub: "Saved on this iPhone with the puzzle.") {
                PSToggle(theme: theme, isOn: settings.keepImportImages, label: "Keep import photos",
                         onChange: settingsModel.setKeepImportImages)
                .accessibilityIdentifier("journal_keepImages")
            }
            SettingRow(theme: theme, label: "Imported photos", last: true) {
                LinkButton(theme: theme, title: "Clear") { confirmsClear = true }
                    .accessibilityIdentifier("journal_clearImages")
            }
        }
    }
}
