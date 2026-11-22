import SwiftUI

/// The three tabs (CODESPEC 3.1): Play, Learn and Journal, each with its own navigation stack.
/// The tab bar is drawn by the app, not the system, so it stays dark at night. It belongs to each
/// tab's root screen, so anything pushed (a game, a lesson, Display & Night) covers it.
struct MainMenuView: View {
    @EnvironmentObject private var controller: AppController
    @StateObject private var viewModel: MainMenuViewModel
    @State private var tab = AppTab.play
    /// Set by the tab bar's import button on Learn or Journal: Play opens the import flow when it shows.
    @State private var wantsImport = false

    /// The model is an autoclosure: StateObject builds it once, not on every parent redraw (issue 70).
    init(viewModel: @autoclosure @escaping () -> MainMenuViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        switch tab {
        case .play: PlayTab(viewModel: viewModel, tab: $tab, wantsImport: $wantsImport)
        case .learn: RootStack(tab: $tab) { LearnView().tabBar($tab, onImport: importFromAnotherTab) }
        case .journal: RootStack(tab: $tab) { JournalView(viewModel: StatsViewModel(controller: controller),
                                                            settings: SettingsViewModel(controller: controller))
                .tabBar($tab, onImport: importFromAnotherTab) }
        }
    }
}

extension MainMenuView {
    /// Import lives in Play's navigation stack.
    private func importFromAnotherTab() {
        wantsImport = true
        tab = .play
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
    @Binding var wantsImport: Bool
    @State private var path = NavigationPath()
    @State private var routeViewModels: [UUID: GameViewModel] = [:]
    /// Each game route's depth in `path`. Its model is kept until the path is shorter than that, so a
    /// lesson pushed over the game (which hides it) doesn't drop it (issue 70).
    @State private var routeDepths: [UUID: Int] = [:]
    @State private var isOpeningGame = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(viewModel: viewModel, onContinue: continueGame, onNew: startGame,
                     onOpenImport: openImportedGame)
                .tabBar($tab) { path.append(ImportRoute()) }
                .navigationDestination(for: GameRoute.self) { route in
                    if let viewModel = routeViewModels[route.id] ?? makeViewModel(for: route) {
                        GameView(viewModel: viewModel, difficulty: route.difficulty)
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
        .onChangeOf(path.count) { dropRoutes(deeperThan: $0) }
        .onAppear {
            guard wantsImport else { return }
            wantsImport = false
            path.append(ImportRoute())
        }
    }

    private func push(_ route: GameRoute) {
        path.append(route)
        dropRoutes(deeperThan: path.count - 1) // a pop and a push in one update leave the count unchanged
        routeDepths[route.id] = path.count
    }

    private func dropRoutes(deeperThan count: Int) {
        for (id, depth) in routeDepths where depth > count {
            routeDepths[id] = nil
            routeViewModels[id] = nil
        }
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
            push(route)
        }
    }

    private func openImportedGame(_ imported: ImportedGame) {
        let route = GameRoute(kind: .imported(id: imported.id, difficulty: imported.gameState.puzzle.difficulty))
        if let gameViewModel = controller.makeImportedGameViewModel(id: imported.id) {
            routeViewModels[route.id] = gameViewModel
        }
        push(route)
    }

    private func makeViewModel(for route: GameRoute) -> GameViewModel? {
        switch route.kind {
        case let .difficulty(difficulty):
            return viewModel.routeGame(importID: nil, difficulty: difficulty)
        case let .imported(id, difficulty):
            return viewModel.routeGame(importID: id, difficulty: difficulty)
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

/// The tab bar (HANDOFF 6.1): a floating glass capsule with Play, Learn and Journal, and a round glass
/// import button beside it. The selected tab is `accent` and heavier on a `pill` (clear at night).
struct PSTabBar: View {
    @Environment(\.psPalette) private var theme
    @Binding var selection: AppTab
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { item in
                    let on = item == selection
                    Button { selection = item } label: {
                        VStack(spacing: 2) {
                            Image(systemName: item.symbol).font(.system(size: 20, weight: on ? .semibold : .regular))
                                .frame(height: 24)
                                .accessibilityHidden(true) // the label names the tab once
                            Text(item.title).font(PSFont.fixed(11, weight: on ? .bold : .medium, display: false))
                        }
                        .foregroundStyle(on ? theme.accent : theme.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Capsule().fill(on ? theme.pill : .clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityShowsLargeContentViewer { Label(item.title, systemImage: item.symbol) }
                    .accessibilityIdentifier("tab_\(item.rawValue)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(4)
            .frame(height: 62)
            .psGlass(theme, in: Capsule())
            Button(action: onImport) {
                Image(systemName: "camera")
                    .font(.system(size: 21))
                    .foregroundStyle(theme.ink)
                    .frame(width: 62, height: 62)
                    .psGlass(theme, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Import a puzzle from a photo")
            .accessibilityShowsLargeContentViewer { Label("Import", systemImage: "camera") }
            .accessibilityIdentifier("importPuzzleButton")
        }
        .padding(.horizontal, 21)
    }
}

/// A tab screen's header (HANDOFF 6.1): a 44 pt row with an optional line on the left and the round glass
/// moon (opens the Night sheet) on the right, then the large title.
struct ScreenHead: View {
    @Environment(\.psPalette) private var theme
    let title: String
    var line: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let line {
                    Text(line).psFont(15, weight: .medium).foregroundStyle(theme.ink2)
                }
                Spacer(minLength: 8)
                NightButton()
            }
            .frame(minHeight: 44)
            Text(title)
                .psFont(33, weight: .heavy, design: .serif)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
    }
}

/// The moon on round glass: opens the Night sheet from any screen.
struct NightButton: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme

    var body: some View {
        HeaderIconButton(theme: theme, symbol: "moon", label: "Night", round: true) {
            controller.showsNightSheet = true
        }
        .accessibilityIdentifier("nightButton")
    }
}

private struct TabBarModifier: ViewModifier {
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Binding var tab: AppTab
    let onImport: () -> Void

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .statusBackdrop(theme.bg)
                // Content scrolls under the floating bar, which sits 21 pt above the screen's bottom edge
                // (above the build number's strip when it shows).
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    PSTabBar(selection: $tab, onImport: onImport)
                        .padding(.bottom, controller.settings.showBuildNumber ? max(0, 21 - proxy.safeAreaInsets.bottom)
                                 : 21 - proxy.safeAreaInsets.bottom)
                }
        }
        .background(theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // The system status bar is white in dark mode, brighter than any ink (CODESPEC 12.7).
        .statusBarHidden(controller.isNight)
    }
}

extension View {
    /// A tab's root screen: the tab bar below it, no system navigation bar, no status bar at night.
    func tabBar(_ tab: Binding<AppTab>, onImport: @escaping () -> Void) -> some View {
        modifier(TabBarModifier(tab: tab, onImport: onImport))
    }

    /// An opaque strip behind the status bar, so scrolled content never sits under the clock.
    func statusBackdrop(_ color: Color) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(color, ignoresSafeAreaEdges: .top)
        }
    }
}
