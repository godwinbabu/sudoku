import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var selectedCellID: UUID?
    @Published var inputMode: InputMode
    @Published var showTimer: Bool

    var onStateChange: ((GameState) -> Void)?
    var onCompletion: ((GameState) -> Void)?

    private var timer: Timer?
    private var lastTickDate: Date?
    private var settings: Settings
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider

    init(state: GameState, settings: Settings, validator: SudokuValidator, timeProvider: TimeProvider) {
        self.state = state
        self.settings = settings
        self.validator = validator
        self.timeProvider = timeProvider
        self.inputMode = .normal
        self.showTimer = settings.showTimer
    }

    deinit {
        timer?.invalidate()
    }

    func apply(settings newValue: Settings) {
        settings = newValue
        showTimer = newValue.showTimer
        if !newValue.autoCheckMistakes {
            // Clear previous auto error flags
            state.cells = state.cells.map { cell in
                var mutable = cell
                if mutable.isError && !mutable.given {
                    mutable.isError = false
                }
                return mutable
            }
            syncState()
        } else {
            updateAutoCheckHighlights()
        }
    }

    func handleSceneDidAppear() {
        guard !state.isCompleted else { return }
        guard timer == nil else { return }
        lastTickDate = timeProvider.now()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { await self?.tick() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func handleSceneDidDisappear() {
        pauseTimer()
    }

    func pauseTimer() {
        guard let start = lastTickDate else {
            timer?.invalidate()
            timer = nil
            return
        }
        let now = timeProvider.now()
        state.elapsedSeconds += Int(now.timeIntervalSince(start))
        lastTickDate = nil
        timer?.invalidate()
        timer = nil
        syncState()
    }

    func select(cell: SudokuCell) {
        guard !cell.given else {
            selectedCellID = cell.id
            return
        }
        selectedCellID = cell.id
    }

    func clearSelectedCell() {
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        guard !state.cells[index].given, !state.cells[index].isRevealed else { return }
        state.cells[index].value = nil
        state.cells[index].candidates.removeAll()
        state.cells[index].isError = false
        updateAutoCheckHighlights()
        syncState()
    }

    func setDigit(_ digit: Int) {
        guard (1...9).contains(digit), let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        guard !state.cells[index].given, !state.cells[index].isRevealed else { return }

        switch inputMode {
        case .normal:
            state.cells[index].value = digit
            state.cells[index].candidates.removeAll()
            state.cells[index].isError = false
            if settings.autoRemoveCandidates {
                removeCandidate(digit, relatedTo: state.cells[index])
            }
            updateAutoCheckHighlights()
            checkIfSolved()
        case .candidate:
            if state.cells[index].candidates.contains(digit) {
                state.cells[index].candidates.remove(digit)
            } else {
                state.cells[index].candidates.insert(digit)
            }
        }

        syncState()
    }

    func toggleMode() {
        inputMode.toggle()
    }

    func checkCell() {
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }), let value = state.cells[index].value else { return }
        let cell = state.cells[index]
        state.cells[index].isError = !validator.isCorrect(value: value, row: cell.row, col: cell.col, solution: state.puzzle.solutionGrid)
        syncState()
    }

    func checkPuzzle() {
        for idx in state.cells.indices {
            guard let value = state.cells[idx].value else { continue }
            let cell = state.cells[idx]
            state.cells[idx].isError = !validator.isCorrect(value: value, row: cell.row, col: cell.col, solution: state.puzzle.solutionGrid)
        }
        syncState()
    }

    func revealCell() {
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        guard !state.cells[index].given else { return }
        if let value = validator.solutionValue(row: state.cells[index].row, col: state.cells[index].col, solution: state.puzzle.solutionGrid) {
            state.cells[index].value = value
            state.cells[index].isRevealed = true
            state.cells[index].candidates.removeAll()
            state.usedReveal = true
            updateAutoCheckHighlights()
            checkIfSolved()
            syncState()
        }
    }

    func revealPuzzle() {
        for idx in state.cells.indices {
            if let value = validator.solutionValue(row: state.cells[idx].row, col: state.cells[idx].col, solution: state.puzzle.solutionGrid) {
                state.cells[idx].value = value
                state.cells[idx].isRevealed = true
                state.cells[idx].candidates.removeAll()
                state.cells[idx].isError = false
            }
        }
        state.usedReveal = true
        state.isCompleted = true
        pauseTimer()
        syncState()
        onCompletion?(state)
    }

    func resetPuzzle() {
        state.resetToInitial(now: timeProvider.now())
        state.elapsedSeconds = 0
        inputMode = .normal
        selectedCellID = nil
        state.usedReveal = false
        state.isCompleted = false
        state.cells = state.cells.map { cell in
            var mutable = cell
            mutable.isError = false
            mutable.candidates.removeAll()
            return mutable
        }
        syncState()
    }

    func load(state newState: GameState) {
        pauseTimer()
        state = newState
        selectedCellID = nil
        inputMode = .normal
        showTimer = settings.showTimer
        if newState.isCompleted {
            timer?.invalidate()
            timer = nil
        }
        syncState()
    }

    private func removeCandidate(_ digit: Int, relatedTo cell: SudokuCell) {
        for idx in state.cells.indices {
            guard state.cells[idx].id != cell.id else { continue }
            if state.cells[idx].row == cell.row || state.cells[idx].col == cell.col || (state.cells[idx].row / 3 == cell.row / 3 && state.cells[idx].col / 3 == cell.col / 3) {
                state.cells[idx].candidates.remove(digit)
            }
        }
    }

    private func updateAutoCheckHighlights() {
        let conflicts = validator.conflictingIndices(in: state.cells, autoCheckMistakes: settings.autoCheckMistakes)
        for idx in state.cells.indices {
            if conflicts.contains(state.cells[idx].id) {
                state.cells[idx].isError = true
            } else if !state.cells[idx].given {
                state.cells[idx].isError = false
            }
        }
    }

    private func checkIfSolved() {
        guard state.cells.allSatisfy({ $0.value != nil || $0.given }) else { return }
        if validator.isSolved(cells: state.cells, solution: state.puzzle.solutionGrid) {
            state.isCompleted = true
            pauseTimer()
            syncState()
            onCompletion?(state)
        }
    }

    private func syncState() {
        state.lastUpdated = timeProvider.now()
        onStateChange?(state)
    }

    private func tick() async {
        guard let start = lastTickDate else { return }
        let now = timeProvider.now()
        state.elapsedSeconds += max(1, Int(now.timeIntervalSince(start)))
        lastTickDate = now
        syncState()
    }
}
