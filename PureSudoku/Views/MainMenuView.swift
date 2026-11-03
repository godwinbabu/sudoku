import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var palette
    @StateObject private var viewModel: MainMenuViewModel
    @State private var activeSheet: Sheet?
    @State private var navigationPath = NavigationPath()
    @State private var routeViewModels: [UUID: GameViewModel] = [:]
    @State private var isOpeningGame = false
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
        let theme = palette
        return NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                ZStack {
                    theme.bg.ignoresSafeArea()
                    VStack(spacing: 12) {
                        ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        topSection(theme: theme)
                        difficultyButtons(theme: theme)
                        importButton(theme: theme)
                        learnButton(theme: theme)
                        savedImports(theme: theme)
                        statsSummary(theme: theme)
                    }
                    .frame(maxWidth: 420)
                    .padding(.top, 24)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 48)
                }
                bedtimeToggle(theme: theme)
                    .padding(.horizontal, 18)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 8, 16))
            }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { controller.showsNightSheet = true } label: {
                        Image(systemName: theme.isNight ? "moon.fill" : "moon")
                    }
                    .foregroundColor(theme.accent)
                    .accessibilityLabel("Night")
                    .accessibilityIdentifier("nightButton")
                }
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
                let viewModel = routeViewModels[route.id] ?? makeViewModel(for: route)
                GameView(viewModel: viewModel, difficulty: route.difficulty)
                    .onDisappear {
                        routeViewModels.removeValue(forKey: route.id)
                    }
            }
            .navigationDestination(for: LearnRoute.self) { _ in
                LearnView()
            }
            .navigationDestination(for: ImportRoute.self) { _ in
                ImportPuzzleView(viewModel: ImportPuzzleViewModel(controller: controller)) { imported in
                    if !navigationPath.isEmpty {
                        navigationPath.removeLast()
                    }
                    openImportedGame(imported)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(viewModel: SettingsViewModel(controller: controller))
                    .environmentObject(controller)
                    .sheetTheme(controller)
                case .stats:
                    StatsView(viewModel: StatsViewModel(controller: controller))
                    .sheetTheme(controller)
                }
            }
        }
        .environment(\.popToRoot) { navigationPath = NavigationPath() }
    }

    private func topSection(theme: PSPalette) -> some View {
        VStack(spacing: 8) {
            Text("Pure Sudoku")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundColor(theme.ink)
            Text(taglineOptions[displayedTaglineIndex])
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.ink2)
        }
        .frame(maxWidth: .infinity)
    }

    private func statsSummary(theme: PSPalette) -> some View {
        let streak = viewModel.stats.streakDays
        let total = viewModel.stats.totalPuzzlesSolved
        return VStack(spacing: 20) {
            HStack {
                statColumn(title: "Day Streak", value: "\(streak)", theme: theme)
                Divider()
                    .frame(height: 48)
                    .background(theme.lineMajor.opacity(0.3))
                statColumn(title: "Solved Total", value: "\(total)", theme: theme)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 26)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 22))
        }
        .frame(maxWidth: .infinity)
    }

    private func statColumn(title: String, value: String, theme: PSPalette) -> some View {
        VStack {
            Text(value)
                .font(.largeTitle.bold())
                .foregroundColor(theme.ink)
            Text(title)
                .font(.callout)
                .foregroundColor(theme.ink2)
        }
    }

    private func difficultyButtons(theme: PSPalette) -> some View {
        // Night: outline only, no fill behind text (CODESPEC 12.4).
        let fillColor: Color = theme.isNight ? .clear : theme.ink
        let textColor: Color = theme.isNight ? theme.accent : theme.bg
        return VStack(spacing: 16) {
            ForEach(Difficulty.allCases) { difficulty in
                let hasActive = controller.activeGames[difficulty]?.isCompleted == false
                Button {
                    openGame(difficulty)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(difficulty.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(fillColor)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(theme.isNight ? theme.accentDim : .clear, lineWidth: 1.5)
                            )
                        if hasActive {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 10, height: 10)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 200)
                .accessibilityIdentifier("difficulty_\(difficulty.rawValue)")
                Text(difficulty.techniqueSummary)
                    .font(.caption)
                    .foregroundColor(theme.ink2)
                    .padding(.top, -10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func bedtimeToggle(theme: PSPalette) -> some View {
        Button {
            viewModel.toggleNight()
        } label: {
            HStack(spacing: 12) {
                BedtimeIcon(color: theme.accent)
                    .frame(width: 18, height: 18)
                Text(controller.isNight ? "Night On" : "Turn On Night")
                    .foregroundColor(theme.ink)
                    .font(.body.bold())
                Spacer()
                BedtimeSwitch(isOn: controller.isNight, theme: theme)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .overlay(Capsule().stroke(theme.accentDim, lineWidth: 1.5))
        .accessibilityIdentifier("bedtimeToggle")
    }

    private func openGame(_ difficulty: Difficulty) {
        guard !isOpeningGame else { return }
        isOpeningGame = true
        Task {
            let gameViewModel = await viewModel.continueOrStartGame(for: difficulty)
            let route = GameRoute(kind: .difficulty(difficulty))
            routeViewModels[route.id] = gameViewModel
            navigationPath.append(route)
            isOpeningGame = false
        }
    }

    private func openImportedGame(_ imported: ImportedGame) {
        let route = GameRoute(kind: .imported(id: imported.id, difficulty: imported.gameState.puzzle.difficulty))
        if let gameViewModel = controller.makeImportedGameViewModel(id: imported.id) {
            routeViewModels[route.id] = gameViewModel
        }
        navigationPath.append(route)
    }

    private func makeViewModel(for route: GameRoute) -> GameViewModel {
        switch route.kind {
        case let .difficulty(difficulty):
            return controller.makeGameViewModel(for: difficulty)
        case let .imported(id, _):
            return controller.makeImportedGameViewModel(id: id) ?? controller.makeGameViewModel(for: .easy)
        }
    }

    /// Unfinished imported puzzles, so the player can return to them (BYOS: "return to them later").
    @ViewBuilder
    private func savedImports(theme: PSPalette) -> some View {
        let saved = controller.savedImports
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Saved imports")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.ink2)
                ForEach(saved) { imported in
                    Button {
                        openImportedGame(imported)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(imported.gameState.puzzle.difficulty.displayName)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(theme.ink)
                                Text(imported.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundColor(theme.ink2)
                            }
                            Spacer()
                            Text("\(imported.gameState.cells.filter { $0.value != nil }.count)/81")
                                .font(.footnote.monospacedDigit())
                                .foregroundColor(theme.ink2)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.surface)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            controller.deleteImportedGame(id: imported.id)
                        }
                    }
                    .accessibilityIdentifier("savedImport_\(imported.id)")
                }
            }
            .frame(maxWidth: 320)
        }
    }

    /// Opens the technique curriculum (CODESPEC 13.5).
    private func learnButton(theme: PSPalette) -> some View {
        Button {
            navigationPath.append(LearnRoute())
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap")
                    .font(.headline)
                Text("Learn techniques")
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(theme.ink)
            .padding(.vertical, 12)
            .frame(maxWidth: 220)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.lineMajor.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learnButton")
    }

    private func importButton(theme: PSPalette) -> some View {
        Button {
            navigationPath.append(ImportRoute())
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.headline)
                Text("Import Puzzle")
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(theme.ink)
            .padding(.vertical, 12)
            .frame(maxWidth: 220)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.lineMajor.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("importPuzzleButton")
    }
}

private struct GameRoute: Hashable, Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind: Hashable {
        case difficulty(Difficulty)
        case imported(id: String, difficulty: Difficulty)
    }

    var difficulty: Difficulty {
        switch kind {
        case let .difficulty(value):
            return value
        case let .imported(_, value):
            return value
        }
    }
}

private struct ImportRoute: Hashable, Identifiable {
    let id = UUID()
}

private struct LearnRoute: Hashable {}

// A non-interactive switch indicator for the Night state
private struct BedtimeSwitch: View {
    let isOn: Bool
    let theme: PSPalette

    var body: some View {
        let trackColor = theme.surface
        let knobColor = isOn ? theme.accent : theme.ink2
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(trackColor)
                .overlay(
                    Capsule()
                        .stroke(theme.lineMajor.opacity(0.6), lineWidth: 1)
                )
            Circle()
                .fill(knobColor)
                .frame(width: 22, height: 22)
                .padding(.horizontal, 3)
        }
        .frame(width: 50, height: 28)
        .accessibilityLabel(isOn ? "Night On" : "Night Off")
        .accessibilityAddTraits(.isStaticText)
    }
}
