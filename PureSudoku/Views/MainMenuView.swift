import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var controller: AppController
    @StateObject private var viewModel: MainMenuViewModel
    @State private var activeSheet: Sheet?
    @State private var navigationPath = NavigationPath()
    private let taglineOptions = [
        "Simple, unobtrusive. Just Sudoku.",
        "Calm focus. Just you, the grid, and a steady mind.",
        "Quiet puzzles for clear thinking and relaxed focus."
    ]
    private let displayedTaglineIndex = 0

    init(viewModel: MainMenuViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private enum Sheet: Identifiable {
        case settings
        case stats

        var id: Int {
            switch self {
            case .settings: return 0
            case .stats: return 1
            }
        }
    }

    var body: some View {
        let theme = controller.settings.themeColors
        return NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                ZStack {
                    theme.background.ignoresSafeArea()
                    ScrollView {
                        VStack(spacing: 20) {
                            topSection(theme: theme)
                            difficultyButtons(theme: theme)
                            statsSummary(theme: theme)
                            bedtimeToggle(theme: theme)
                        }
                        .frame(maxWidth: 340)
                        .padding(.vertical, 28)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { activeSheet = .settings }) {
                        Image(systemName: "gearshape")
                    }
                    .foregroundColor(theme.accent)
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { activeSheet = .stats }) {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                    .foregroundColor(theme.accent)
                    .accessibilityIdentifier("statsButton")
                }
            }
            .navigationDestination(for: Difficulty.self) { difficulty in
                GameView(viewModel: controller.makeGameViewModel(for: difficulty), difficulty: difficulty)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(viewModel: SettingsViewModel(controller: controller))
                case .stats:
                    StatsView(viewModel: StatsViewModel(controller: controller))
                }
            }
        }
    }

    private func topSection(theme: ThemeColors) -> some View {
        VStack(spacing: 10) {
            Image("LandingIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
            Text("PureSudoku")
                .font(.title.bold())
                .foregroundColor(theme.primaryText)
            Text(taglineOptions[displayedTaglineIndex])
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func statsSummary(theme: ThemeColors) -> some View {
        let streak = viewModel.stats.streakDays
        let total = viewModel.stats.totalPuzzlesSolved
        return VStack(spacing: 8) {
            Text("Progress")
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            HStack {
                statColumn(title: "Day Streak", value: "\(streak)", theme: theme)
                Spacer()
                statColumn(title: "Solved Total", value: "\(total)", theme: theme)
            }
            .padding()
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        }
        .frame(maxWidth: .infinity)
    }

    private func statColumn(title: String, value: String, theme: ThemeColors) -> some View {
        VStack {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(theme.primaryText)
            Text(title)
                .font(.footnote)
                .foregroundColor(theme.secondaryText)
        }
    }

    private func difficultyButtons(theme: ThemeColors) -> some View {
        VStack(spacing: 12) {
            ForEach(Difficulty.allCases) { difficulty in
                let hasActive = controller.activeGames[difficulty]?.isCompleted == false
                DifficultyCard(
                    theme: theme,
                    difficulty: difficulty,
                    hasActive: hasActive,
                    continueAction: { openGame(difficulty, preferNew: false) },
                    newAction: { openGame(difficulty, preferNew: true) }
                )
                .accessibilityIdentifier("difficulty_\(difficulty.rawValue)")
            }
        }
    }

    private func bedtimeToggle(theme: ThemeColors) -> some View {
        Button {
            viewModel.toggleBedtimeMode()
        } label: {
            HStack(spacing: 12) {
                BedtimeIcon(color: theme.accent)
                    .frame(width: 18, height: 18)
                Text(controller.settings.bedtimeMode ? "Bedtime Mode On" : "Enable Bedtime Mode")
                    .foregroundColor(theme.primaryText)
                    .font(.footnote.bold())
                Spacer()
                Toggle(isOn: .constant(controller.settings.bedtimeMode)) {
                    EmptyView()
                }
                .labelsHidden()
                .disabled(true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accent)
        .accessibilityIdentifier("bedtimeToggle")
    }

    private func openGame(_ difficulty: Difficulty, preferNew: Bool) {
        if preferNew || controller.activeGames[difficulty]?.isCompleted != false {
            controller.startNewGame(for: difficulty)
        }
        navigationPath.append(difficulty)
    }
}

private struct DifficultyCard: View {
    let theme: ThemeColors
    let difficulty: Difficulty
    let hasActive: Bool
    let continueAction: () -> Void
    let newAction: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(difficulty.displayName)
                .font(.headline.bold())
                .foregroundColor(theme.primaryText)
            HStack(spacing: 12) {
                ActionButton(
                    title: "Continue",
                    enabled: hasActive,
                    theme: theme,
                    action: continueAction
                )
                ActionButton(
                    title: "New",
                    enabled: true,
                    theme: theme,
                    action: newAction
                )
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private struct ActionButton: View {
        let title: String
        let enabled: Bool
        let theme: ThemeColors
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(enabled ? theme.accent : theme.numberPadDisabledText)
                    .background(
                        Capsule()
                            .fill(enabled ? theme.accent.opacity(0.15) : theme.numberPadDisabledBackground)
                    )
            }
            .disabled(!enabled)
        }
    }
}
