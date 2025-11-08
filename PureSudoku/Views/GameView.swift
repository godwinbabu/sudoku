import SwiftUI

struct GameView: View {
    @EnvironmentObject private var controller: AppController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GameViewModel
    private let difficulty: Difficulty
    @State private var pendingAction: PendingAction?

    private enum PendingAction: Identifiable {
        case reset
        case revealPuzzle
        case newPuzzle

        var id: Int {
            switch self {
            case .reset: return 0
            case .revealPuzzle: return 1
            case .newPuzzle: return 2
            }
        }

        var title: String {
            switch self {
            case .reset: return "Reset puzzle?"
            case .revealPuzzle: return "Reveal entire puzzle?"
            case .newPuzzle: return "Start a new puzzle?"
            }
        }

        var message: String {
            switch self {
            case .reset:
                return "This clears your progress and timer for this puzzle."
            case .revealPuzzle:
                return "Revealing marks the puzzle as completed with reveals."
            case .newPuzzle:
                return "Current progress will be lost."
            }
        }
    }

    init(viewModel: GameViewModel, difficulty: Difficulty) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.difficulty = difficulty
    }

    var body: some View {
        let theme = controller.settings.themeColors
        ZStack {
            theme.background.ignoresSafeArea()
            if theme.isSleep {
                Color.black.opacity(theme.dimOverlayOpacity).ignoresSafeArea()
            }
            VStack(spacing: 16) {
                topBar(theme: theme)
                SudokuGridView(cells: viewModel.state.cells, selectedCellID: viewModel.selectedCellID, theme: theme) { cell in
                    viewModel.select(cell: cell)
                }
                modeToggle(theme: theme)
                NumberPadView(theme: theme, disabledDigits: viewModel.disabledDigits, onDigit: { viewModel.setDigit($0) }, onClear: { viewModel.clearSelectedCell() })
                actionButtons(theme: theme)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityIdentifier("backButton")
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
        .confirmationDialog(pendingAction?.title ?? "", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }), titleVisibility: .visible) {
            if let action = pendingAction {
                Button("Confirm", role: .destructive) {
                    handle(action: action)
                }
                Button("Cancel", role: .cancel) {
                    pendingAction = nil
                }
            }
        } message: {
            if let action = pendingAction {
                Text(action.message)
            }
        }
        .accessibilityIdentifier("gameView")
    }

    private func topBar(theme: ThemeColors) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(difficulty.displayName)
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                if viewModel.showTimer {
                    Text(timeString(seconds: viewModel.state.elapsedSeconds))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(theme.secondaryText)
                        .accessibilityIdentifier("timerLabel")
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(viewModel.inputMode == .normal ? "Normal" : "Notes")
                    .font(.footnote)
                    .foregroundColor(theme.secondaryText)
                Text(viewModel.state.isCompleted ? "Solved" : "In progress")
                    .font(.footnote.bold())
                    .foregroundColor(viewModel.state.isCompleted ? theme.accent : theme.secondaryText)
            }
        }
    }

    private func modeToggle(theme: ThemeColors) -> some View {
        HStack {
            Text("Mode")
                .foregroundColor(theme.primaryText)
            Spacer()
            Picker("Input Mode", selection: $viewModel.inputMode) {
                Text("Normal").tag(InputMode.normal)
                Text("Notes").tag(InputMode.candidate)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .accessibilityIdentifier("modeToggle")
            .tint(theme.accent)
        }
    }

    private func actionButtons(theme: ThemeColors) -> some View {
        let items: [ActionItem] = [
            ActionItem(title: "Hint") { viewModel.revealCell() },
            ActionItem(title: "Check Cell") { viewModel.checkCell() },
            ActionItem(title: "Check Puzzle") { viewModel.checkPuzzle() },
            ActionItem(title: "Reveal Puzzle", style: .destructive) { pendingAction = .revealPuzzle },
            ActionItem(title: "Reset", style: .destructive) { pendingAction = .reset },
            ActionItem(title: "New Puzzle") { pendingAction = .newPuzzle }
        ]
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                GameActionButton(theme: theme, title: item.title, style: item.style, action: item.action)
            }
        }
    }

    private struct ActionItem: Identifiable {
        let id = UUID()
        let title: String
        var style: GameActionButton.Style = .normal
        let action: () -> Void
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

    private func handle(action: PendingAction) {
        switch action {
        case .reset:
            viewModel.resetPuzzle()
        case .revealPuzzle:
            viewModel.revealPuzzle()
        case .newPuzzle:
            if let newState = controller.startNewGame(for: difficulty) {
                viewModel.load(state: newState)
            }
        }
        pendingAction = nil
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
