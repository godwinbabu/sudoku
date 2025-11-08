import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var controller: AppController
    @StateObject private var viewModel: MainMenuViewModel
    @State private var activeSheet: Sheet?
    @State private var navigationPath = NavigationPath()

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
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 24) {
                header
                statsSummary
                difficultyButtons
                Spacer()
                bedtimeToggle
            }
            .padding()
            .background(ThemePalette.palette(for: controller.settings).background.ignoresSafeArea())
            .navigationTitle("PureSudoku")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { activeSheet = .settings }) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { activeSheet = .stats }) {
                        Image(systemName: "chart.bar")
                    }
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

    private var header: some View {
        VStack(spacing: 8) {
            Text("PureSudoku")
                .font(.largeTitle.bold())
            Text("Fast, calm, bedtime-friendly Sudoku")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsSummary: some View {
        let streak = viewModel.stats.streakDays
        let total = viewModel.stats.totalPuzzlesSolved
        return HStack {
            VStack(alignment: .leading) {
                Text("Streak")
                    .font(.caption)
                Text("\(streak) days")
                    .font(.headline)
            }
            Spacer()
            VStack(alignment: .leading) {
                Text("Solved")
                    .font(.caption)
                Text("\(total)")
                    .font(.headline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var difficultyButtons: some View {
        VStack(spacing: 16) {
            ForEach(Difficulty.allCases) { difficulty in
                Button(action: { navigationPath.append(difficulty) }) {
                    HStack {
                        Text(difficulty.displayName)
                            .font(.title3.bold())
                        Spacer()
                        if controller.activeGames[difficulty]?.isCompleted == false {
                            Text("Continue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("New")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .background(ThemePalette.palette(for: controller.settings).tile, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("difficulty_\(difficulty.rawValue)")
            }
        }
    }

    private var bedtimeToggle: some View {
        Button {
            viewModel.toggleBedtimeMode()
        } label: {
            HStack {
                Image(systemName: "moon.stars")
                Text(controller.settings.bedtimeMode ? "Bedtime Mode On" : "Enable Bedtime Mode")
                Spacer()
                Toggle(isOn: .constant(controller.settings.bedtimeMode)) {
                    EmptyView()
                }
                .labelsHidden()
                .disabled(true)
            }
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .accessibilityIdentifier("bedtimeToggle")
    }
}
