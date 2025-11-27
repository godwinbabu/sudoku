import SwiftUI

struct GameView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GameViewModel
    @State private var activeSheet: Sheet?
    @State private var showCelebration: Bool = false
    private let difficulty: Difficulty
    init(viewModel: GameViewModel, difficulty: Difficulty) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.difficulty = difficulty
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
        ZStack {
            theme.background.ignoresSafeArea()
            if theme.isSleep {
                Color.black.opacity(theme.dimOverlayOpacity).ignoresSafeArea()
            }
            ScrollView {
                VStack(spacing: 16) {
                    topBar(theme: theme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SudokuGridView(cells: viewModel.state.cells, selectedCellID: viewModel.selectedCellID, theme: theme) { cell in
                        viewModel.select(cell: cell)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.vertical, 4)
                    .allowsHitTesting(!viewModel.state.isCompleted)
                    modeToggle(theme: theme)
                        .disabled(viewModel.state.isCompleted)
                    NumberPadView(
                        theme: theme,
                        disabledDigits: viewModel.disabledDigits,
                        onDigit: { viewModel.setDigit($0) },
                        onClear: { viewModel.clearSelectedCell() }
                    )
                    .disabled(viewModel.state.isCompleted)
                    actionButtons(theme: theme)
                    hintBanner(theme: theme)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            // Subtle solved overlay celebration
            if showCelebration {
                celebrationOverlay(theme: theme)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                }
                .accessibilityIdentifier("backButton")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { activeSheet = .stats }) {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .foregroundColor(theme.accent)
                .accessibilityIdentifier("statsButton")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { activeSheet = .settings }) {
                    Image(systemName: "gearshape")
                }
                .foregroundColor(theme.accent)
                .accessibilityIdentifier("settingsButton")
            }
        }
        .onAppear {
            viewModel.apply(settings: controller.settings)
            viewModel.handleSceneDidAppear()
        }
        .onDisappear {
            viewModel.handleSceneDidDisappear()
        }
        .onChange(of: controller.settings) { newSettings in
            viewModel.apply(settings: newSettings)
        }
        .onChange(of: viewModel.state.isCompleted) { isCompleted in
            guard isCompleted else { return }
            withAnimation(.easeInOut(duration: 0.25)) { showCelebration = true }
            // Auto-hide after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.25)) { showCelebration = false }
            }
        }
        .confirmationDialog(
            viewModel.pendingAction?.title ?? "",
            isPresented: Binding(
                get: { viewModel.pendingAction != nil },
                set: { newValue in
                    if !newValue {
                        Task { @MainActor in
                            viewModel.pendingAction = nil
                        }
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let action = viewModel.pendingAction {
                Button("Confirm", role: .destructive) {
                    viewModel.handle(pendingAction: action)
                }
                Button("Cancel", role: .cancel) {
                    Task { @MainActor in
                        viewModel.pendingAction = nil
                    }
                }
            }
        } message: {
            if let action = viewModel.pendingAction {
                Text(action.message)
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
        .accessibilityIdentifier("gameView")
    }

    private func topBar(theme: ThemeColors) -> some View {
        let statusText = viewModel.state.isCompleted ? "Solved" : "In progress"
        return HStack(alignment: .center, spacing: 12) {
            Text(difficulty.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)
            if viewModel.showTimer {
                Text(timeString(seconds: viewModel.state.elapsedSeconds))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("timerLabel")
            } else {
                Spacer()
            }
            Text(statusText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.headline.bold())
        .foregroundColor(theme.primaryText)
    }

    private func modeToggle(theme: ThemeColors) -> some View {
        HStack(spacing: 12) {
            ModeChip(title: "Normal", active: viewModel.inputMode == .normal, theme: theme) {
                viewModel.inputMode = .normal
            }
            ModeChip(title: "Notes", active: viewModel.inputMode == .candidate, theme: theme) {
                viewModel.inputMode = .candidate
            }
            Spacer()
        }
        .accessibilityIdentifier("modeToggle")
    }

    private func actionButtons(theme: ThemeColors) -> some View {
        let items: [ActionItem] = [
            ActionItem(title: "Hint") { viewModel.requestHint() },
            ActionItem(title: "Check Cell") { viewModel.checkCell() },
            ActionItem(title: "Check Puzzle") { viewModel.checkPuzzle() },
            ActionItem(title: "Reveal Puzzle", style: .destructive) { viewModel.pendingAction = .revealPuzzle },
            ActionItem(title: "Reset", style: .destructive) { viewModel.pendingAction = .reset },
            ActionItem(title: "New Puzzle") { viewModel.pendingAction = .newPuzzle }
        ]
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                let shouldDisable = viewModel.state.isCompleted && ["Hint", "Check Cell", "Check Puzzle", "Reveal Puzzle"].contains(item.title)
                GameActionButton(theme: theme, title: item.title, style: item.style, action: item.action)
                    .disabled(shouldDisable)
            }
        }
    }

    private struct ActionItem: Identifiable {
        let id = UUID()
        let title: String
        var style: GameActionButton.Style = .normal
        let action: () -> Void
    }

    @ViewBuilder
    private func hintBanner(theme: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if viewModel.state.hasContradiction {
                Text("Board has a contradiction. Check duplicates or reset.")
                    .font(.footnote)
                    .foregroundColor(theme.error)
                    .accessibilityIdentifier("contradictionWarning")
            }
            if let hint = viewModel.hintMessage {
                Text(hint)
                    .font(.footnote)
                    .foregroundColor(theme.secondaryText)
                    .accessibilityIdentifier("hintMessage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func timeString(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    @ViewBuilder
    private func celebrationOverlay(theme: ThemeColors) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(theme.success)
            Text("Solved")
                .font(.title2.bold())
                .foregroundColor(theme.primaryText)
            Text(timeString(seconds: viewModel.state.elapsedSeconds))
                .font(.headline)
                .foregroundColor(theme.secondaryText)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(theme.cardBackground.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.success.opacity(0.55), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(theme.isSleep ? 0.18 : 0.22), radius: 10, x: 0, y: 3)
    }
}

struct GameActionButton: View {
    enum Style {
        case normal
        case destructive
    }

    let theme: ThemeColors
    let title: String
    var style: Style = .normal
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundColor(style == .destructive ? theme.error : theme.primaryText)
                .frame(maxWidth: .infinity)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("action_\(title.replacingOccurrences(of: " ", with: ""))")
    }

    private var background: Color {
        switch style {
        case .normal: return theme.accent.opacity(0.15)
        case .destructive: return theme.error.opacity(0.15)
        }
    }
}

private struct ModeChip: View {
    let title: String
    let active: Bool
    let theme: ThemeColors
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(active ? theme.accent.opacity(0.2) : theme.cardBackground)
                .foregroundColor(active ? theme.accent : theme.secondaryText)
                .clipShape(Capsule())
        }
    }
}
