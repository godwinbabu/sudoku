import SwiftUI

/// The Journal tab (CODESPEC 3.3, HANDOFF 6.4): the streak and week, the Solved table, Assists, More
/// (the settings the design does not place) and About. Every control is drawn from the palette.
struct JournalView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: StatsViewModel
    @StateObject private var settingsModel: SettingsViewModel
    @State private var confirmsClear = false

    /// The model is an autoclosure: StateObject builds it once, not on every parent redraw (issue 70).
    init(viewModel: @autoclosure @escaping () -> StatsViewModel, settings: @autoclosure @escaping () -> SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _settingsModel = StateObject(wrappedValue: settings())
    }

    var body: some View {
        let settings = settingsModel.settings
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHead(title: "Journal", line: "Nothing here leaves this iPhone")
                Group {
                    streak
                    groupLabel("Solved")
                    solved
                    groupLabel("Assists")
                    assists(settings)
                    groupLabel("More")
                    more(settings)
                    groupLabel("About")
                    about
                }
                .padding(.horizontal, 16)
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

    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .psFont(15, weight: .semibold)
            .foregroundStyle(theme.ink2)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 4)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    /// The count (Bricolage 40), "days in a row", and the week: filled circles by day, a ring with a dot
    /// at night; a plain ring for a day without a solve. Shape, not hue, carries it.
    private var streak: some View {
        PSAdaptiveStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.streak())")
                    .font(PSFont.fixed(40, weight: .heavy).monospacedDigit())
                    .foregroundStyle(theme.ink)
                Text("days in a row").psFont(15).foregroundStyle(theme.ink2).fixedSize()
                if let line = viewModel.lastSolvedLine() {
                    Text(line).psFont(13).foregroundStyle(theme.ink2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journal_streak")
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(Array(viewModel.week().enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 6) {
                        dayMarker(solved: item.solved)
                        Text(item.day).psFont(11, weight: .semibold).foregroundStyle(theme.ink2)
                    }
                    .frame(minWidth: 28)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.name), \(item.solved ? "solved" : "not solved")")
                }
            }
        }
        .padding(16)
        .psCard(theme, radius: 26)
        .padding(.bottom, 0)
    }

    @ViewBuilder
    private func dayMarker(solved: Bool) -> some View {
        if solved && !theme.isNight {
            Circle().fill(theme.accent).frame(width: 22, height: 22)
        } else {
            Circle()
                .strokeBorder(solved ? theme.accent : theme.line, lineWidth: 2)
                .overlay { if solved { Circle().fill(theme.accent).frame(width: 8, height: 8) } }
                .frame(width: 22, height: 22)
        }
    }

    private var solved: some View {
        VStack(spacing: 0) {
            tableRow("Level", "Solved", "Best", "Typical", header: true)
            ForEach(Difficulty.allCases) { level in
                tableRow(level.displayName, viewModel.solvedText(for: level),
                         viewModel.formattedBestTime(for: level), viewModel.formattedTypicalTime(for: level))
                    .overlay(alignment: .top) { theme.line.frame(height: 1) }
                    .accessibilityLabel(viewModel.rowLabel(for: level))
                    .accessibilityIdentifier("journal_row_\(level.rawValue)")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.assistedLine).accessibilityIdentifier("journal_assisted")
                Text(viewModel.totalsLine)
            }
            .psFont(13)
            .foregroundStyle(theme.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(alignment: .top) { theme.line.frame(height: 1) }
        }
        .psCard(theme, radius: 26)
    }

    @ViewBuilder
    private func tableRow(_ level: String, _ count: String, _ best: String, _ typical: String, header: Bool = false) -> some View {
        let name = Text(level)
            .font(header ? nil : PSFont.fixed(19, weight: .heavy))
            .foregroundStyle(header ? theme.ink2 : theme.ink)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Too wide for one line: the level above, its three numbers in equal columns below.
                VStack(alignment: .leading, spacing: 2) {
                    name
                    HStack(spacing: 8) {
                        ForEach(Array([count, best, typical].enumerated()), id: \.offset) {
                            Text($0.element).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    name.frame(maxWidth: .infinity, alignment: .leading)
                    Text(count).frame(width: 64, alignment: .trailing)
                    Text(best).frame(width: 74, alignment: .trailing)
                    Text(typical).frame(width: 84, alignment: .trailing)
                }
            }
        }
        .psFont(header ? 13 : 15, weight: header ? .medium : .regular, monospacedDigit: true)
        .foregroundStyle(header ? theme.ink2 : theme.ink)
        .padding(.horizontal, 16)
        .frame(minHeight: header ? 34 : 40)
        .padding(.vertical, header ? 2 : 0)
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: String, sub: String? = nil, divider: Bool = true, @ViewBuilder control: () -> some View) -> some View {
        PSAdaptiveStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).psFont(16, weight: .semibold).foregroundStyle(theme.ink)
                if let sub {
                    Text(sub).psFont(13).foregroundStyle(theme.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .overlay(alignment: .top) { if divider { theme.line.frame(height: 1) } }
    }

    /// A title over a segmented choice, for settings with more than two values.
    private func choice<Value: Hashable>(_ title: String, options: [(Value, String)], selection: Value, id: String,
                                         divider: Bool = true, onSelect: @escaping (Value) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).psFont(16, weight: .semibold).foregroundStyle(theme.ink)
            PSSegmented(theme: theme, options: options, selection: selection, idPrefix: id, onSelect: onSelect)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { if divider { theme.line.frame(height: 1) } }
    }

    /// Show mistakes, Tidy notes, Show timer, Cell names in hints (HANDOFF 6.4).
    private func assists(_ settings: Settings) -> some View {
        VStack(spacing: 0) {
            choice("Show mistakes", options: MistakeMode.allCases.map { ($0, $0.displayName) }, selection: settings.mistakes,
                   id: "journal_mistakes_", divider: false, onSelect: settingsModel.setMistakes)
            row("Tidy notes") {
                PSToggle(theme: theme, isOn: settings.tidyNotes, label: "Tidy notes", onChange: settingsModel.setTidyNotes)
                    .accessibilityIdentifier("journal_tidyNotes")
            }
            row("Show timer") {
                PSToggle(theme: theme, isOn: settings.showTimer, label: "Show timer", onChange: settingsModel.setShowTimer)
                    .accessibilityIdentifier("journal_showTimer")
            }
            choice("Cell names in hints", options: CellNotation.allCases.map { ($0, $0.displayName) }, selection: settings.notation,
                   id: "journal_notation_", onSelect: settingsModel.setNotation)
        }
        .psCard(theme, radius: 26)
    }

    /// Settings v3 does not place (owner's choice): the coach, quiet and status bar, imports, build number.
    private func more(_ settings: Settings) -> some View {
        VStack(spacing: 0) {
            row("Coach when I'm stuck", sub: "After two minutes without a new digit, Hint walks you through the patterns on your board.",
                divider: false) {
                PSToggle(theme: theme, isOn: settings.coachWhenStuck, label: "Coach when I'm stuck",
                         onChange: settingsModel.setCoachWhenStuck)
                    .accessibilityIdentifier("journal_coachWhenStuck")
            }
            row("Hide status bar in games", sub: "Clock and battery give off light too.") {
                PSToggle(theme: theme, isOn: settings.hideStatusBarInGames, label: "Hide status bar in games",
                         onChange: settingsModel.setHideStatusBar)
                    .accessibilityIdentifier("journal_hideStatusBar")
            }
            row("Sounds") {
                PSToggle(theme: theme, isOn: settings.soundsEnabled, label: "Sounds", onChange: settingsModel.setSounds)
                    .accessibilityIdentifier("journal_sounds")
            }
            row("Vibration", sub: "Night always keeps sound and vibration off.") {
                PSToggle(theme: theme, isOn: settings.hapticsEnabled, label: "Vibration", onChange: settingsModel.setHaptics)
                    .accessibilityIdentifier("journal_haptics")
            }
            row("Keep import photos", sub: "Saved on this iPhone with the puzzle.") {
                PSToggle(theme: theme, isOn: settings.keepImportImages, label: "Keep import photos",
                         onChange: settingsModel.setKeepImportImages)
                    .accessibilityIdentifier("journal_keepImages")
            }
            row("Imported photos") {
                LinkButton(theme: theme, title: "Clear") { confirmsClear = true }
                    .accessibilityIdentifier("journal_clearImages")
            }
            row("Show build number") {
                PSToggle(theme: theme, isOn: settings.showBuildNumber, label: "Show build number",
                         onChange: settingsModel.setShowBuildNumber)
                    .accessibilityIdentifier("journal_showBuildNumber")
            }
        }
        .psCard(theme, radius: 26)
    }

    /// The privacy promise, the font licences and the version.
    private var about: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Everything stays on this iPhone. No account, no network, no analytics. "
                 + "Silent by design — no sounds or vibration unless you turn them on.")
                .psFont(15)
                .foregroundStyle(theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
            NavigationLink { LicencesView() } label: {
                HStack {
                    Text("Licences").psFont(16, weight: .semibold).foregroundStyle(theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink2)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
                .overlay(alignment: .top) { theme.line.frame(height: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("journal_licences")
            Text(SettingsViewModel.appVersionLine)
                .psFont(13, monospacedDigit: true)
                .foregroundStyle(theme.ink2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay(alignment: .top) { theme.line.frame(height: 1) }
                .accessibilityIdentifier("journal_version")
        }
        .psCard(theme, radius: 26)
    }
}

/// The SIL Open Font License texts the bundled fonts require (Resources/Fonts), read from the app bundle.
struct LicencesView: View {
    @Environment(\.psPalette) private var theme
    @Environment(\.dismiss) private var dismiss

    /// The licence files shipped with the fonts, in display order.
    static let files = [("Bricolage Grotesque", "OFL-BricolageGrotesque"), ("DM Sans", "OFL-DMSans")]

    static func text(_ file: String) -> String? {
        Bundle.main.url(forResource: file, withExtension: "txt", subdirectory: "Fonts")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HeaderIconButton(theme: theme, symbol: "chevron.left", label: "Back", round: true) { dismiss() }
                    .accessibilityIdentifier("licences_back")
                Text("Licences")
                    .psFont(33, weight: .heavy, design: .serif)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                ForEach(Self.files, id: \.1) { name, file in
                    Text(name).psFont(19, weight: .heavy, design: .serif).foregroundStyle(theme.ink).padding(.top, 8)
                    Text(Self.text(file) ?? "")
                        .psFont(13)
                        .foregroundStyle(theme.ink2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .statusBackdrop(theme.bg)
        .background(theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("licencesView")
    }
}
