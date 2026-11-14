import SwiftUI

/// The three tabs (CODESPEC 3.1): Play, Learn and Journal, each with its own navigation stack.
/// The tab bar is drawn by the app, not the system, so it stays dark at night. It belongs to each
/// tab's root screen, so anything pushed (a game, a lesson, Display & Night) covers it.
struct MainMenuView: View {
    @EnvironmentObject private var controller: AppController
    @StateObject private var viewModel: MainMenuViewModel
    @State private var tab = AppTab.play

    init(viewModel: MainMenuViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        switch tab {
        case .play: PlayTab(viewModel: viewModel, tab: $tab)
        case .learn: RootStack(tab: $tab) { LearnView().tabBar($tab) }
        case .journal: RootStack(tab: $tab) { JournalView(viewModel: StatsViewModel(controller: controller),
                                                            settings: SettingsViewModel(controller: controller)).tabBar($tab) }
        }
    }
}

enum AppTab: String, CaseIterable {
    case play, learn, journal

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .play: return "square.grid.3x3"
        case .learn: return "book"
        case .journal: return "chart.bar"
        }
    }
}

/// A tab's navigation stack. Goodnight from a game pushed here (a practice puzzle) goes Home.
private struct RootStack<Root: View>: View {
    @Binding var tab: AppTab
    @ViewBuilder let root: Root

    var body: some View {
        NavigationStack { root }
            .environment(\.popToRoot) { tab = .play }
    }
}

/// Play: Home, games and the import flow.
private struct PlayTab: View {
    @EnvironmentObject private var controller: AppController
    @ObservedObject var viewModel: MainMenuViewModel
    @Binding var tab: AppTab
    @State private var path = NavigationPath()
    @State private var routeViewModels: [UUID: GameViewModel] = [:]
    @State private var isOpeningGame = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(viewModel: viewModel, onContinue: continueGame, onNew: startGame,
                     onImport: { path.append(ImportRoute()) }, onOpenImport: openImportedGame)
                .tabBar($tab)
                .navigationDestination(for: GameRoute.self) { route in
                    if let viewModel = routeViewModels[route.id] ?? makeViewModel(for: route) {
                        GameView(viewModel: viewModel, difficulty: route.difficulty)
                            .onDisappear { routeViewModels.removeValue(forKey: route.id) }
                    } else {
                        // The game is gone (e.g. a pruned import): drop the route instead of opening another game.
                        Color.clear.onAppear { if !path.isEmpty { path.removeLast() } }
                    }
                }
                .navigationDestination(for: ImportRoute.self) { _ in
                    ImportPuzzleView(viewModel: ImportPuzzleViewModel(controller: controller)) { imported in
                        if !path.isEmpty { path.removeLast() }
                        openImportedGame(imported)
                    }
                }
        }
        .environment(\.popToRoot) { path = NavigationPath() }
    }

    /// Tapping a level always starts a new puzzle at that level (Design/v2/README.md, Home).
    private func startGame(_ difficulty: Difficulty) {
        open(difficulty) { await viewModel.startNewGame(for: difficulty) }
    }

    private func continueGame(_ difficulty: Difficulty) {
        open(difficulty) { viewModel.continueGame(for: difficulty) }
    }

    private func open(_ difficulty: Difficulty, _ make: @escaping () async -> GameViewModel?) {
        guard !isOpeningGame else { return }
        isOpeningGame = true
        Task {
            defer { isOpeningGame = false }
            guard let gameViewModel = await make() else { return }
            let route = GameRoute(kind: .difficulty(difficulty))
            routeViewModels[route.id] = gameViewModel
            path.append(route)
        }
    }

    private func openImportedGame(_ imported: ImportedGame) {
        let route = GameRoute(kind: .imported(id: imported.id, difficulty: imported.gameState.puzzle.difficulty))
        if let gameViewModel = controller.makeImportedGameViewModel(id: imported.id) {
            routeViewModels[route.id] = gameViewModel
        }
        path.append(route)
    }

    private func makeViewModel(for route: GameRoute) -> GameViewModel? {
        switch route.kind {
        case let .difficulty(difficulty):
            return controller.makeGameViewModel(for: difficulty)
        case let .imported(id, _):
            return controller.makeImportedGameViewModel(id: id)
        }
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
        case let .difficulty(value): return value
        case let .imported(_, value): return value
        }
    }
}

private struct ImportRoute: Hashable, Identifiable {
    let id = UUID()
}

// MARK: - Shared chrome for the tab screens

/// The tab bar: Play, Learn, Journal. `bg` fill and a 1 pt `hair` top border; the active tab is
/// `accent` with a semibold label, the others `ink2`, readable at night (Design/v2/README.md, QA #29).
struct PSTabBar: View {
    @Environment(\.psPalette) private var theme
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                let on = item == selection
                Button { selection = item } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.symbol).font(.system(size: 21, weight: on ? .semibold : .regular))
                            .accessibilityHidden(true) // the label names the tab once
                        Text(item.title).font(.system(size: 11, weight: on ? .semibold : .medium))
                    }
                    .foregroundColor(on ? theme.accent : theme.ink2)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityShowsLargeContentViewer { Label(item.title, systemImage: item.symbol) }
                .accessibilityIdentifier("tab_\(item.rawValue)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .background(theme.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { theme.hair.frame(height: 1) }
    }
}

/// A tab screen's header: the serif title and the moon, which opens the Night sheet (CODESPEC 12.7).
struct ScreenHead: View {
    @Environment(\.psPalette) private var theme
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .psFont(30, weight: .medium, design: .serif)
                .tracking(-0.3)
                .foregroundColor(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            NightButton()
        }
        .padding(.leading, 22)
        .padding(.trailing, 12)
        .frame(minHeight: 52)
    }
}

/// The moon: opens the Night sheet from any screen.
struct NightButton: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme

    var body: some View {
        HeaderIconButton(theme: theme, symbol: theme.isNight ? "moon.fill" : "moon", label: "Night") {
            controller.showsNightSheet = true
        }
        .accessibilityIdentifier("nightButton")
    }
}

private struct TabBarModifier: ViewModifier {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Binding var tab: AppTab

    func body(content: Content) -> some View {
        content
            .statusBackdrop(theme.bg)
            .safeAreaInset(edge: .bottom, spacing: 0) { PSTabBar(selection: $tab) }
            .background(theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // The system status bar is white in dark mode, brighter than any ink (CODESPEC 12.7).
            .statusBarHidden(controller.isNight)
    }
}

extension View {
    /// A tab's root screen: the tab bar below it, no system navigation bar, no status bar at night.
    func tabBar(_ tab: Binding<AppTab>) -> some View {
        modifier(TabBarModifier(tab: tab))
    }

    /// An opaque strip behind the status bar, so scrolled content never sits under the clock.
    func statusBackdrop(_ color: Color) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(color, ignoresSafeAreaEdges: .top)
        }
    }
}
