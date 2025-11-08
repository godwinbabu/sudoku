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
        let palette = ThemePalette.palette(for: controller.settings)
        VStack(spacing: 16) {
            topBar
            SudokuGridView(cells: viewModel.state.cells, selectedCellID: viewModel.selectedCellID, palette: palette) { cell in
                viewModel.select(cell: cell)
            }
            modeToggle
            NumberPadView(onDigit: { viewModel.setDigit($0) }, onClear: { viewModel.clearSelectedCell() })
            actionButtons
        }
        .padding()
        .background(palette.background.ignoresSafeArea())
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

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(difficulty.displayName)
                    .font(.headline)
                if viewModel.showTimer {
                    Text(timeString(seconds: viewModel.state.elapsedSeconds))
                        .font(.subheadline.monospacedDigit())
                        .accessibilityIdentifier("timerLabel")
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(viewModel.inputMode == .normal ? "Normal" : "Notes")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text(viewModel.state.isCompleted ? "Solved" : "In progress")
                    .font(.footnote.bold())
                    .foregroundColor(viewModel.state.isCompleted ? .green : .secondary)
            }
        }
    }

    private var modeToggle: some View {
        HStack {
            Text("Mode")
            Spacer()
            Picker("Input Mode", selection: $viewModel.inputMode) {
                Text("Normal").tag(InputMode.normal)
                Text("Notes").tag(InputMode.candidate)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .accessibilityIdentifier("modeToggle")
        }
    }

    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                GameActionButton(title: "Hint") {
                    viewModel.revealCell()
                }
                GameActionButton(title: "Check Cell") {
                    viewModel.checkCell()
                }
                GameActionButton(title: "Check Puzzle") {
                    viewModel.checkPuzzle()
                }
                GameActionButton(title: "Reveal Puzzle", style: .destructive) {
                    pendingAction = .revealPuzzle
                }
                GameActionButton(title: "Reset", style: .destructive) {
                    pendingAction = .reset
                }
                GameActionButton(title: "New Puzzle") {
                    pendingAction = .newPuzzle
                }
            }
        }
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

    let title: String
    var style: Style = .normal
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("action_\(title.replacingOccurrences(of: " ", with: ""))")
    }

    private var background: Color {
        switch style {
        case .normal: return Color.accentColor.opacity(0.1)
        case .destructive: return Color.red.opacity(0.2)
        }
    }
}
