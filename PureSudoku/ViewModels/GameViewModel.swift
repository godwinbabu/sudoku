import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var selectedCellID: UUID?
    @Published var inputMode: InputMode
    @Published var showTimer: Bool
    @Published var hintMessage: String?

    var onCompletion: ((GameState) -> Void)?
    var onNewGame: (() -> GameState?)?
    var onSave: ((GameState) -> Void)?

    @Published var pendingAction: PendingAction?

    enum PendingAction: Identifiable {
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

    private var timer: Timer?
    private var lastTickDate: Date?
    private var settings: Settings
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider
    private let hintService: SudokuGeneratorService

    init(state: GameState, settings: Settings, validator: SudokuValidator, timeProvider: TimeProvider, hintService: SudokuGeneratorService = SudokuGeneratorService()) {
        self.state = state
        self.settings = settings
        self.validator = validator
        self.timeProvider = timeProvider
        self.hintService = hintService
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
            var newState = self.state
            newState.cells = newState.cells.map { cell in
                var mutable = cell
                if mutable.isError && !mutable.given {
                    mutable.isError = false
                }
                return mutable
            }
            self.state = newState
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
        let elapsed = calculateAndStopTimer()
        var newState = self.state
        newState.elapsedSeconds += elapsed
        updateContradictionFlag(on: &newState)
        self.state = newState
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onSave?(self.state)
        }
    }

    private func calculateAndStopTimer() -> Int {
        guard let start = lastTickDate else {
            timer?.invalidate()
            timer = nil
            return 0
        }
        let now = timeProvider.now()
        let elapsed = Int(now.timeIntervalSince(start))
        lastTickDate = nil
        timer?.invalidate()
        timer = nil
        return elapsed
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
        
        var newState = self.state
        newState.cells[index].value = nil
        newState.cells[index].candidates.removeAll()
        newState.cells[index].isError = false
        newState.cells[index].isVerifiedCorrect = false
        self.state = newState
        self.hintMessage = nil
        
        updateAutoCheckHighlights()
    }

    func setDigit(_ digit: Int) {
        guard (1...9).contains(digit), let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        guard !state.cells[index].given, !state.cells[index].isRevealed else { return }

        var newState = self.state
        switch inputMode {
        case .normal:
            newState.cells[index].value = digit
            newState.cells[index].candidates.removeAll()
            newState.cells[index].isError = false
            newState.cells[index].isVerifiedCorrect = false
            if settings.autoRemoveCandidates {
                newState.cells = removeCandidate(digit, relatedTo: newState.cells[index], from: newState.cells)
            }
            self.state = newState
            self.hintMessage = nil
            updateAutoCheckHighlights()
            checkIfSolved()
        case .candidate:
            if newState.cells[index].candidates.contains(digit) {
                newState.cells[index].candidates.remove(digit)
            } else {
                newState.cells[index].candidates.insert(digit)
            }
            self.state = newState
            self.hintMessage = nil
            updateAutoCheckHighlights()
        }
    }

    func toggleMode() {
        inputMode.toggle()
    }

    func checkCell() {
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        // Ignore givens and empty cells
        guard !state.cells[index].given, let value = state.cells[index].value else { return }

        var newState = self.state
        // Toggle off if already highlighted
        if newState.cells[index].isError || newState.cells[index].isVerifiedCorrect {
            newState.cells[index].isError = false
            newState.cells[index].isVerifiedCorrect = false
            self.state = newState
            return
        }

        let cell = newState.cells[index]
        if validator.isCorrect(value: value, row: cell.row, col: cell.col, solution: newState.puzzle.solutionGrid) {
            newState.cells[index].isError = false
            newState.cells[index].isVerifiedCorrect = true
        } else {
            newState.cells[index].isError = true
            newState.cells[index].isVerifiedCorrect = false
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
    }

    func checkPuzzle() {
        var newState = self.state
        // If any non-given cell is currently highlighted from a previous check, toggle (clear) all highlights
        let hasAnyHighlight = newState.cells.contains { !$0.given && ($0.isError || $0.isVerifiedCorrect) }
        if hasAnyHighlight {
            for idx in newState.cells.indices where !newState.cells[idx].given {
                newState.cells[idx].isError = false
                newState.cells[idx].isVerifiedCorrect = false
            }
            self.state = newState
            return
        }

        // Otherwise, perform check across all non-given cells with values
        for idx in newState.cells.indices {
            guard !newState.cells[idx].given, let value = newState.cells[idx].value else { continue }
            let cell = newState.cells[idx]
            if validator.isCorrect(value: value, row: cell.row, col: cell.col, solution: newState.puzzle.solutionGrid) {
                newState.cells[idx].isError = false
                newState.cells[idx].isVerifiedCorrect = true
            } else {
                newState.cells[idx].isError = true
                newState.cells[idx].isVerifiedCorrect = false
            }
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
    }

    func requestHint() {
        let hint = hintService.hint(for: state.cells)
        hintMessage = hint?.message

        guard let hint else { return }
        if hint.technique == .invalid {
            markContradictionDetected()
            return
        }
        guard let position = hint.positions.first else { return }
        let row = position / 9
        let col = position % 9
        guard let index = state.cells.firstIndex(where: { $0.row == row && $0.col == col }) else { return }
        selectedCellID = state.cells[index].id
        revealCell(at: index, markUsedReveal: true, force: true)
    }

    func revealCell() {
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        revealCell(at: index, markUsedReveal: true)
    }

    private func revealCell(at index: Int, markUsedReveal: Bool, force: Bool = false) {
        guard index < state.cells.count else { return }
        guard force || (!state.cells[index].given && !state.cells[index].isRevealed) else { return }

        var newState = self.state
        if let value = validator.solutionValue(row: newState.cells[index].row, col: newState.cells[index].col, solution: newState.puzzle.solutionGrid) {
            newState.cells[index].value = value
            newState.cells[index].isRevealed = true
            newState.cells[index].candidates.removeAll()
            if markUsedReveal {
                newState.usedReveal = true
            }
            newState.cells[index].isVerifiedCorrect = false
            self.state = newState
            
            updateAutoCheckHighlights()
            checkIfSolved()
        }
    }

    func revealPuzzle() {
        var newState = self.state
        for idx in newState.cells.indices {
            if let value = validator.solutionValue(row: newState.cells[idx].row, col: newState.cells[idx].col, solution: newState.puzzle.solutionGrid) {
                newState.cells[idx].value = value
                newState.cells[idx].isRevealed = true
                newState.cells[idx].candidates.removeAll()
                newState.cells[idx].isError = false
                newState.cells[idx].isVerifiedCorrect = false
            }
        }
        newState.usedReveal = true
        newState.hasContradiction = false
        
        // Handle completion
        newState.isCompleted = true
        let elapsed = calculateAndStopTimer()
        newState.elapsedSeconds += elapsed
        
        self.state = newState
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onCompletion?(self.state)
        }
    }

    func resetPuzzle() {
        var newState = self.state
        newState.resetToInitial(now: timeProvider.now())
        newState.elapsedSeconds = 0
        newState.usedReveal = false
        newState.isCompleted = false
        newState.hasContradiction = false
        newState.cells = newState.cells.map { cell in
            var mutable = cell
            mutable.isError = false
            mutable.candidates.removeAll()
            mutable.isVerifiedCorrect = false
            return mutable
        }
        
        self.state = newState
        self.inputMode = .normal
        self.selectedCellID = nil
        self.hintMessage = nil
    }

    var disabledDigits: Set<Int> {
        var counts: [Int: Int] = [:]
        for cell in state.cells {
            if let value = cell.value, (1...9).contains(value) {
                counts[value, default: 0] += 1
            }
        }
        return Set(counts.filter { $0.value >= 9 }.map(\.key))
    }

    func load(state newState: GameState) {
        _ = calculateAndStopTimer()
        
        var finalState = newState
        finalState.cells = finalState.cells.map { cell in
            var mutable = cell
            if !mutable.given {
                mutable.isVerifiedCorrect = false
                mutable.isError = false
            }
            return mutable
        }
        
        self.state = finalState
        self.selectedCellID = nil
        self.inputMode = .normal
        self.showTimer = settings.showTimer
        self.hintMessage = nil
        updateAutoCheckHighlights()
        
        if finalState.isCompleted {
            timer?.invalidate()
            timer = nil
        }
    }

    func handle(pendingAction: PendingAction) {
        let action = pendingAction
        self.pendingAction = nil

        Task { @MainActor in
            switch action {
            case .newPuzzle:
                if let newState = self.onNewGame?() {
                    self.load(state: newState)
                }
                self.hintMessage = nil
            case .reset:
                self.resetPuzzle()
            case .revealPuzzle:
                self.revealPuzzle()
            }
        }
    }

    private func removeCandidate(_ digit: Int, relatedTo cell: SudokuCell, from cells: [SudokuCell]) -> [SudokuCell] {
        var newCells = cells
        for idx in newCells.indices {
            guard newCells[idx].id != cell.id else { continue }
            if newCells[idx].row == cell.row || newCells[idx].col == cell.col || (newCells[idx].row / 3 == cell.row / 3 && newCells[idx].col / 3 == cell.col / 3) {
                newCells[idx].candidates.remove(digit)
            }
        }
        return newCells
    }

    private func updateAutoCheckHighlights() {
        var newState = self.state
        let conflicts = validator.conflictingIndices(in: newState.cells, autoCheckMistakes: settings.autoCheckMistakes)
        for idx in newState.cells.indices {
            if conflicts.contains(newState.cells[idx].id) {
                newState.cells[idx].isError = true
                newState.cells[idx].isVerifiedCorrect = false
            } else if !newState.cells[idx].given {
                newState.cells[idx].isError = false
            }
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
    }

    private func checkIfSolved() {
        guard state.cells.allSatisfy({ $0.value != nil || $0.given }) else { return }
        if validator.isSolved(cells: state.cells, solution: state.puzzle.solutionGrid) {
            var newState = self.state
            newState.isCompleted = true
            let elapsed = calculateAndStopTimer()
            newState.elapsedSeconds += elapsed
            
            self.state = newState
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onCompletion?(self.state)
            }
        }
    }

    private func updateContradictionFlag(on state: inout GameState) {
        let board = generatorBoard(from: state.cells)
        state.hasContradiction = PureSudoku.hasContradiction(board)
    }

    private func generatorBoard(from cells: [SudokuCell]) -> GeneratorBoard {
        cells.map { cell in
            guard let value = cell.value, value > 0 else { return nil }
            return value - 1
        }
    }

    private func markContradictionDetected() {
        var newState = state
        newState.hasContradiction = true
        state = newState
    }

    private func tick() async {
        guard let start = lastTickDate else { return }
        let now = timeProvider.now()
        
        var newState = self.state
        newState.elapsedSeconds += max(1, Int(now.timeIntervalSince(start)))
        self.state = newState
        
        lastTickDate = now
    }
}
