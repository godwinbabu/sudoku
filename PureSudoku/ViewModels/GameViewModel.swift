import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published var selectedCellID: UUID?
    @Published var inputMode: InputMode
    @Published var showTimer: Bool
    @Published var hintMessage: String?

    var onCompletion: ((GameState) -> Void)?
    var onNewGame: (() async -> GameState?)?
    var onSave: ((GameState) -> Void)?

    @Published var pendingAction: PendingAction?
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var isTimerRunning: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var showAllCandidates: Bool = false
    @Published private(set) var candidateOverlay: [UUID: Set<Int>] = [:]

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
    private var isManuallyPaused = false
    private var isBackgroundPaused = false
    /// Cells that Check Cell / Check Puzzle found wrong. Kept apart from duplicate (auto-check) errors
    /// so later moves do not erase them; cleared when the cell is edited.
    private var checkedWrongIDs: Set<UUID> = []
    private var saveTask: Task<Void, Never>?
    /// Delay before an edit is saved (CODESPEC 8: autosave every few seconds, debounced).
    var autosaveDelayNanoseconds: UInt64 = 2_000_000_000
    private let autosaveIntervalSeconds = 10
    private var settings: Settings
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider
    private let hintService: SudokuGeneratorService
    private var undoStack: [(state: GameState, checkedWrong: Set<UUID>)] = []

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
                if !mutable.given {
                    mutable.isError = checkedWrongIDs.contains(cell.id) && cell.value != nil
                }
                return mutable
            }
            self.state = newState
        } else {
            updateAutoCheckHighlights()
        }
    }

    func handleSceneDidAppear() {
        startTimerIfNeeded()
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

    func pauseTimer() {
        guard !state.isCompleted else { return }
        isManuallyPaused = true
        isPaused = true
        let elapsed = calculateAndStopTimer()
        if elapsed > 0 {
            var newState = self.state
            newState.elapsedSeconds += elapsed
            updateContradictionFlag(on: &newState)
            self.state = newState
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.onSave?(self.state)
        }
    }

    func resumeTimer() {
        isManuallyPaused = false
        isPaused = false
        startTimerIfNeeded()
    }

    /// Pauses quietly when the app leaves the foreground. Unlike a manual pause, no overlay is shown
    /// and the timer resumes on its own when the app is active again (CODESPEC 4, 12).
    func pauseForBackground() {
        guard !state.isCompleted, !isPaused, !isBackgroundPaused else { return }
        isBackgroundPaused = true
        let elapsed = calculateAndStopTimer()
        var newState = self.state
        newState.elapsedSeconds += elapsed
        self.state = newState
        saveNow()
    }

    func resumeFromBackground() {
        guard isBackgroundPaused else { return }
        isBackgroundPaused = false
        startTimerIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard !state.isCompleted, timer == nil, !isManuallyPaused, !isBackgroundPaused else { return }
        lastTickDate = timeProvider.now()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { await self?.tick() }
        }
        self.timer = timer
        isTimerRunning = true
        isPaused = false
        RunLoop.main.add(timer, forMode: .common)
    }

    private func calculateAndStopTimer() -> Int {
        guard let start = lastTickDate else {
            timer?.invalidate()
            timer = nil
            isTimerRunning = false
            lastTickDate = nil
            return 0
        }
        let now = timeProvider.now()
        let elapsed = Int(now.timeIntervalSince(start))
        lastTickDate = nil
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        return elapsed
    }

    func toggleAllCandidates() {
        showAllCandidates.toggle()
        candidateOverlay = showAllCandidates ? computeCandidateOverlay() : [:]
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
        recordUndoPoint()
        
        var newState = self.state
        newState.cells[index].value = nil
        newState.cells[index].candidates.removeAll()
        newState.cells[index].isError = false
        checkedWrongIDs.remove(cellID)
        newState.cells[index].isVerifiedCorrect = false
        self.state = newState
        self.hintMessage = nil
        
        updateAutoCheckHighlights()
        refreshCandidateOverlayIfNeeded()
        scheduleSave()
    }

    func setDigit(_ digit: Int) {
        guard (1...9).contains(digit), let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        guard !state.cells[index].given, !state.cells[index].isRevealed else { return }
        recordUndoPoint()

        var newState = self.state
        switch inputMode {
        case .normal:
            newState.cells[index].value = digit
            newState.cells[index].candidates.removeAll()
            newState.cells[index].isError = false
            checkedWrongIDs.remove(cellID)
            newState.cells[index].isVerifiedCorrect = false
            if settings.autoRemoveCandidates {
                newState.cells = removeCandidate(digit, relatedTo: newState.cells[index], from: newState.cells)
            }
            self.state = newState
            self.hintMessage = nil
            updateAutoCheckHighlights()
            checkIfSolved()
            updateCanUndo()
            refreshCandidateOverlayIfNeeded()
            scheduleSave()
        case .candidate:
            if newState.cells[index].candidates.contains(digit) {
                newState.cells[index].candidates.remove(digit)
            } else {
                newState.cells[index].candidates.insert(digit)
            }
            self.state = newState
            self.hintMessage = nil
            updateAutoCheckHighlights()
            updateCanUndo()
            refreshCandidateOverlayIfNeeded()
            scheduleSave()
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
        // Toggle off a green "correct" mark. A wrong value is never un-flagged by Check (CODESPEC 6.1).
        if newState.cells[index].isVerifiedCorrect {
            newState.cells[index].isVerifiedCorrect = false
            self.state = newState
            return
        }
        alignImportedSolution(&newState)

        let cell = newState.cells[index]
        if validator.isCorrect(value: value, row: cell.row, col: cell.col, solution: newState.puzzle.solutionGrid) {
            newState.cells[index].isError = false
            newState.cells[index].isVerifiedCorrect = true
            checkedWrongIDs.remove(cell.id)
        } else {
            newState.cells[index].isError = true
            newState.cells[index].isVerifiedCorrect = false
            checkedWrongIDs.insert(cell.id)
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
    }

    func checkPuzzle() {
        var newState = self.state
        // A second tap with nothing new to check hides the green "correct" marks. Any unchecked entry
        // is checked instead, so new mistakes are never skipped. Wrong values stay flagged (CODESPEC 6.2).
        let filled = newState.cells.filter { !$0.given && $0.value != nil }
        let allChecked = !filled.isEmpty && filled.allSatisfy { $0.isVerifiedCorrect || checkedWrongIDs.contains($0.id) }
        if allChecked && newState.cells.contains(where: { $0.isVerifiedCorrect }) {
            for idx in newState.cells.indices {
                newState.cells[idx].isVerifiedCorrect = false
            }
            self.state = newState
            return
        }
        alignImportedSolution(&newState)

        // Otherwise, perform check across all non-given cells with values
        for idx in newState.cells.indices {
            guard !newState.cells[idx].given, let value = newState.cells[idx].value else { continue }
            let cell = newState.cells[idx]
            if validator.isCorrect(value: value, row: cell.row, col: cell.col, solution: newState.puzzle.solutionGrid) {
                newState.cells[idx].isError = false
                newState.cells[idx].isVerifiedCorrect = true
                checkedWrongIDs.remove(cell.id)
            } else {
                newState.cells[idx].isError = true
                newState.cells[idx].isVerifiedCorrect = false
                checkedWrongIDs.insert(cell.id)
            }
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
    }

    func requestHint() {
        var aligned = state
        let entriesFit = alignImportedSolution(&aligned)
        state = aligned
        if state.puzzle.source == .imported {
            guard entriesFit else {
                hintMessage = "Some of your entries don't fit together. Try undoing recent moves."
                return
            }
        } else if let wrong = state.cells.first(where: { cell in
            !cell.given && cell.value != nil && !validator.isCorrect(value: cell.value!, row: cell.row, col: cell.col, solution: state.puzzle.solutionGrid)
        }) {
            selectedCellID = wrong.id
            hintMessage = "r\(wrong.row + 1)c\(wrong.col + 1) is not right. Fix it first."
            return
        }
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
        if settings.autoFillHints {
            revealCell(at: index, markUsedReveal: true, force: true)
        }
    }

    func revealCell() {
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        revealCell(at: index, markUsedReveal: true)
    }

    private func revealCell(at index: Int, markUsedReveal: Bool, force: Bool = false) {
        guard index < state.cells.count else { return }
        guard force || (!state.cells[index].given && !state.cells[index].isRevealed) else { return }
        recordUndoPoint()

        var newState = self.state
        alignImportedSolution(&newState)
        if let value = validator.solutionValue(row: newState.cells[index].row, col: newState.cells[index].col, solution: newState.puzzle.solutionGrid) {
            newState.cells[index].value = value
            newState.cells[index].isRevealed = true
            checkedWrongIDs.remove(newState.cells[index].id)
            newState.cells[index].candidates.removeAll()
            if markUsedReveal {
                newState.usedReveal = true
            }
            newState.cells[index].isVerifiedCorrect = false
            self.state = newState
            
            updateAutoCheckHighlights()
            checkIfSolved()
            updateCanUndo()
            refreshCandidateOverlayIfNeeded()
            scheduleSave()
        }
    }

    func revealPuzzle() {
        guard !state.isCompleted else { return }
        recordUndoPoint()
        var newState = self.state
        alignImportedSolution(&newState)
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
        updateCanUndo()
        candidateOverlay = [:]
        showAllCandidates = false
        reportCompletion(newState)
    }

    func resetPuzzle() {
        _ = calculateAndStopTimer()
        checkedWrongIDs.removeAll()
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
        undoStack.removeAll()
        updateCanUndo()
        candidateOverlay = [:]
        showAllCandidates = false
        startTimerIfNeeded()
        saveNow()
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
        checkedWrongIDs.removeAll()

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
        undoStack.removeAll()
        isTimerRunning = false
        isManuallyPaused = false
        isBackgroundPaused = false
        isPaused = false
        updateCanUndo()
        updateAutoCheckHighlights()
        candidateOverlay = [:]
        showAllCandidates = false
        
        if !finalState.isCompleted {
            startTimerIfNeeded()
        }
    }

    func handle(pendingAction: PendingAction) {
        let action = pendingAction
        self.pendingAction = nil

        Task { @MainActor in
            switch action {
            case .newPuzzle:
                if let newState = await self.onNewGame?() {
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

    func undo() {
        guard canUndo else { return }
        let snapshot = undoStack.removeLast()
        var previous = snapshot.state
        checkedWrongIDs = snapshot.checkedWrong
        // Undo restores the board, not the clock or the fact that a reveal happened.
        previous.elapsedSeconds = state.elapsedSeconds
        previous.usedReveal = previous.usedReveal || state.usedReveal
        state = previous
        selectedCellID = nil
        hintMessage = nil
        pendingAction = nil
        updateAutoCheckHighlights()
        updateCanUndo()
        refreshCandidateOverlayIfNeeded()
        scheduleSave()
    }

    // MARK: - Undo tracking

    private func recordUndoPoint() {
        guard !state.isCompleted else { return }
        undoStack.append((state, checkedWrongIDs))
        updateCanUndo()
    }

    private func updateCanUndo() {
        canUndo = !undoStack.isEmpty && !state.isCompleted
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
                let cell = newState.cells[idx]
                newState.cells[idx].isError = checkedWrongIDs.contains(cell.id) && cell.value != nil
            }
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
        updateCanUndo()
        refreshCandidateOverlayIfNeeded()
    }

    private func checkIfSolved() {
        guard state.cells.allSatisfy({ $0.value != nil || $0.given }) else { return }
        var newState = self.state
        alignImportedSolution(&newState)
        if validator.isSolved(cells: newState.cells, solution: newState.puzzle.solutionGrid) {
        newState.isCompleted = true
        let elapsed = calculateAndStopTimer()
        newState.elapsedSeconds += elapsed

        isPaused = false
        isManuallyPaused = false
        
        self.state = newState
        updateCanUndo()
        candidateOverlay = [:]
        showAllCandidates = false
        reportCompletion(newState)
    }
    }

    /// Reports completion right away, so stats get this exact state and a later reset or new game
    /// is saved after it (a delayed report could overwrite newer progress).
    private func reportCompletion(_ completed: GameState) {
        saveTask?.cancel()
        onCompletion?(completed)
    }

    /// Imported puzzles may have several solutions (BYOS.md). If the player's entries differ from the
    /// stored answer but still lead to a solution, adopt that solution. Returns false if they cannot.
    @discardableResult
    private func alignImportedSolution(_ state: inout GameState) -> Bool {
        guard state.puzzle.source == .imported else { return true }
        let answer = Array(state.puzzle.solutionGrid)
        let differs = state.cells.contains { cell in
            guard let value = cell.value, !cell.given else { return false }
            return answer.count == 81 && Int(String(answer[cell.row * 9 + cell.col])) != value
        }
        guard differs else { return true }
        let grid = state.cells.map { String($0.value ?? 0) }.joined()
        guard let solution = hintService.solve(initialGrid: grid) else { return false }
        state.puzzle = state.puzzle.withSolution(solution)
        return true
    }

    // MARK: - Autosave

    private func scheduleSave() {
        saveTask?.cancel()
        let delay = autosaveDelayNanoseconds
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        onSave?(state)
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
        if newState.elapsedSeconds % autosaveIntervalSeconds == 0 {
            onSave?(state)
        }
    }

    private func refreshCandidateOverlayIfNeeded() {
        guard showAllCandidates else { return }
        candidateOverlay = computeCandidateOverlay()
    }

    private func computeCandidateOverlay() -> [UUID: Set<Int>] {
        var overlay: [UUID: Set<Int>] = [:]
        for cell in state.cells where cell.value == nil {
            let rowValues = Set(state.cells.filter { $0.row == cell.row }.compactMap(\.value))
            let colValues = Set(state.cells.filter { $0.col == cell.col }.compactMap(\.value))
            let boxValues = Set(state.cells.filter { $0.row / 3 == cell.row / 3 && $0.col / 3 == cell.col / 3 }.compactMap(\.value))
            let existing = cell.candidates
            let possible = Set(1...9).subtracting(rowValues).subtracting(colValues).subtracting(boxValues)
            let merged = existing.union(possible)
            overlay[cell.id] = merged
        }
        return overlay
    }
}
