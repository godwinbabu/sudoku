import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var controller: AppController
    @StateObject private var viewModel: MainMenuViewModel
    @State private var activeSheet: Sheet?
    @State private var navigationPath = NavigationPath()
    @State private var routeViewModels: [UUID: GameViewModel] = [:]
    private let taglineOptions = [
        "Simple, unobtrusive, Just Sudoku!",
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
                    VStack(spacing: 12) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 24) {
                                topSection(theme: theme)
                                difficultyButtons(theme: theme)
                                statsSummary(theme: theme)
                            }
                            .frame(maxWidth: 420)
                            .padding(.top, 24)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                        }
                        bedtimeToggle(theme: theme)
                            .padding(.horizontal, 18)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom + 8, 16))
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
            .navigationDestination(for: GameRoute.self) { route in
                let viewModel = routeViewModels[route.id] ?? controller.makeGameViewModel(for: route.difficulty)
                GameView(viewModel: viewModel, difficulty: route.difficulty)
                    .onDisappear {
                        routeViewModels.removeValue(forKey: route.id)
                    }
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
        VStack(spacing: 8) {
            Image("LandingIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 115, height: 115)
            Text("Pure Sudoku")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundColor(theme.primaryText)
            Text(taglineOptions[displayedTaglineIndex])
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func statsSummary(theme: ThemeColors) -> some View {
        let streak = viewModel.stats.streakDays
        let total = viewModel.stats.totalPuzzlesSolved
        return VStack(spacing: 20) {
            Text("Progress")
                .font(.headline.bold())
                .foregroundColor(theme.secondaryText)
            HStack {
                statColumn(title: "Day Streak", value: "\(streak)", theme: theme)
                Divider()
                    .frame(height: 48)
                    .background(theme.gridLine.opacity(0.3))
                statColumn(title: "Solved Total", value: "\(total)", theme: theme)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 26)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 22))
        }
        .frame(maxWidth: .infinity)
    }

    private func statColumn(title: String, value: String, theme: ThemeColors) -> some View {
        VStack {
            Text(value)
                .font(.largeTitle.bold())
                .foregroundColor(theme.primaryText)
            Text(title)
                .font(.callout)
                .foregroundColor(theme.secondaryText)
        }
    }

    private func difficultyButtons(theme: ThemeColors) -> some View {
        VStack(spacing: 14) {
            ForEach(Difficulty.allCases) { difficulty in
                let hasActive = controller.activeGames[difficulty]?.isCompleted == false
                Button {
                    openGame(difficulty)
                } label: {
                    VStack(spacing: 6) {
                        Text(difficulty.displayName)
                            .font(.title2.bold())
                            .foregroundColor(theme.primaryText)
                        if hasActive {
                            Text("Continue your game")
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("difficulty_\(difficulty.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
                    .font(.body.bold())
                Spacer()
                BedtimeSwitch(isOn: controller.settings.bedtimeMode, theme: theme)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accent)
        .accessibilityIdentifier("bedtimeToggle")
    }

    private func openGame(_ difficulty: Difficulty) {
        let gameViewModel = viewModel.continueOrStartGame(for: difficulty)
        let route = GameRoute(difficulty: difficulty)
        routeViewModels[route.id] = gameViewModel
        navigationPath.append(route)
    }
}

private struct GameRoute: Hashable, Identifiable {
    let id = UUID()
    let difficulty: Difficulty
}

// A non-interactive, high-contrast switch indicator for Bedtime Mode state
private struct BedtimeSwitch: View {
    let isOn: Bool
    let theme: ThemeColors

    var body: some View {
        let trackColor = theme.cardBackground
        let knobColor = isOn ? theme.accent : theme.secondaryText
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(trackColor)
                .overlay(
                    Capsule()
                        .stroke(theme.gridLine.opacity(0.6), lineWidth: 1)
                )
            Circle()
                .fill(knobColor)
                .frame(width: 22, height: 22)
                .padding(.horizontal, 3)
        }
        .frame(width: 50, height: 28)
        .accessibilityLabel(isOn ? "Bedtime Mode On" : "Bedtime Mode Off")
        .accessibilityAddTraits(.isStaticText)
    }
}
