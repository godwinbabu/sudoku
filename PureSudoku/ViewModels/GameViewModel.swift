import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    /// Every change (a move, an undo, a tick) also refreshes `isStuck`.
    @Published private(set) var state: GameState { didSet { updateStuck() } }
    @Published var selectedCellID: UUID?
    @Published var inputMode: InputMode
    @Published var showTimer: Bool
    /// The open hint, if any (CODESPEC 6.3.1).
    @Published private(set) var hint: HintSession?
    /// What the last Check found, shown in the hint slot until the next move or hint (QA #49).
    @Published private(set) var checkMessage: String?
    /// The open coach, if any (CODESPEC 6.3.3). Never open at the same time as `hint`.
    @Published private(set) var coach: CoachSession?
    /// No correct placement for `stuckAfterSeconds` of play: the Hint tool offers the coach.
    @Published private(set) var isStuck = false
    static let stuckAfterSeconds = 120
    /// Play time at the last correct placement (or when the coach last opened).
    private var progressSeconds = 0
    private var correctCount = 0
    private var progressPuzzleID: String?

    var onCompletion: ((GameState) -> Void)?
    var onNewGame: (() async -> GameState?)?
    var onSave: ((GameState) -> Void)?
    /// Restart threw away this many seconds of an unfinished game; the played total keeps them.
    var onTimeDiscarded: ((Int) -> Void)?
    /// Learning (CODESPEC 13.4): the player found a technique without a hint (technique, puzzle id).
    /// The move comes along so progress can credit each move of each puzzle once, across sessions.
    var onTechniqueFound: (@MainActor (Technique, String, MasteryJudge.Move) -> Void)?
    /// A hint opened (technique if it shows one, the cells and digits it shows, puzzle id). The
    /// learning ledger records it at once, so no later edit can take it back (CODESPEC 13.4).
    var onHintShown: ((Technique?, [CellDigit], String) -> Void)?
    /// Practice game from a lesson: not saved, no stats, no New Puzzle (CODESPEC 13.5).
    var isPractice = false

    @Published var pendingAction: PendingAction?
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var isTimerRunning: Bool = false
    @Published private(set) var isPaused: Bool = false
    /// True while a new puzzle is being generated; further New Puzzle requests are ignored.
    @Published private(set) var isPreparingNewPuzzle = false

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
            case .reset: return "Restart puzzle?"
            case .revealPuzzle: return "Reveal entire puzzle?"
            case .newPuzzle: return "Start a new puzzle?"
            }
        }

        var confirmLabel: String {
            switch self {
            case .reset: return "Restart"
            case .revealPuzzle: return "Reveal"
            case .newPuzzle: return "New puzzle"
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
    /// False while the game screen is off screen (a pushed lesson): the timer never runs then.
    private var isSceneVisible = true
    private var saveTask: Task<Void, Never>?
    /// Delay before an edit is saved (CODESPEC 8: autosave every few seconds, debounced).
    var autosaveDelayNanoseconds: UInt64 = 2_000_000_000
    private let autosaveIntervalSeconds = 10
    private var settings: Settings
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider
    private let hintService: SudokuGeneratorService
    private var undoStack: [GameState] = []

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
        if newValue.mistakes != .immediate {
            var newState = self.state
            let checkedWrong = newState.checkedWrong
            newState.cells = newState.cells.map { cell in
                var mutable = cell
                if !mutable.given {
                    mutable.isError = newValue.mistakes == .onCheck && checkedWrong.contains(cell.id) && cell.value != nil
                }
                return mutable
            }
            self.state = newState
        } else {
            updateAutoCheckHighlights()
        }
    }

    func handleSceneDidAppear() {
        isSceneVisible = true
        startTimerIfNeeded()
    }

    func handleSceneDidDisappear() {
        isSceneVisible = false
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
        guard !state.isCompleted, timer == nil, !isManuallyPaused, !isBackgroundPaused, isSceneVisible else { return }
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

    /// Fills every empty cell's notes with the digits its row, column and box still allow. One Undo reverts it.
    func fillAllNotes() {
        guard !state.isCompleted else { return }
        recordUndoPoint()
        var newState = state
        let valueAt = Dictionary(uniqueKeysWithValues: newState.cells.map { ($0.index, $0.value) })
        for idx in newState.cells.indices where newState.cells[idx].value == nil {
            let seen = Set(Board.peers[newState.cells[idx].index].compactMap { valueAt[$0] ?? nil })
            newState.cells[idx].candidates = Set(1...9).subtracting(seen)
        }
        state = newState
        endHint()
        updateCanUndo()
        scheduleSave()
    }

    /// Tapping a cell closes an open hint: the card hides the selection, so typing must not go
    /// into a cell the player cannot see.
    func select(cell: SudokuCell) {
        endHint()
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
        newState.checkedWrong.remove(cellID)
        newState.cells[index].isVerifiedCorrect = false
        self.state = newState
        endHint()
        
        updateAutoCheckHighlights()
        scheduleSave()
    }

    func setDigit(_ digit: Int) {
        guard (1...9).contains(digit), let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        guard !state.cells[index].given, !state.cells[index].isRevealed else { return }
        let before = SolverBoard(cells: state.cells)
        let cellIndex = state.cells[index].index
        let removesNote = inputMode == .candidate && state.cells[index].candidates.contains(digit)
        recordUndoPoint()
        defer {
            if inputMode == .normal {
                judgeMove(.placed(cell: cellIndex, digit: digit), before: before)
            } else if removesNote {
                judgeMove(.removedCandidate(cell: cellIndex, digit: digit), before: before)
            }
        }

        var newState = self.state
        switch inputMode {
        case .normal:
            newState.cells[index].value = digit
            newState.cells[index].candidates.removeAll()
            newState.cells[index].isError = false
            newState.checkedWrong.remove(cellID)
            newState.cells[index].isVerifiedCorrect = false
            if settings.tidyNotes {
                newState.cells = removeCandidate(digit, relatedTo: newState.cells[index], from: newState.cells)
            }
            self.state = newState
            endHint()
            updateAutoCheckHighlights()
            checkIfSolved()
            updateCanUndo()
                scheduleSave()
        case .candidate:
            if newState.cells[index].candidates.contains(digit) {
                newState.cells[index].candidates.remove(digit)
            } else {
                newState.cells[index].candidates.insert(digit)
            }
            self.state = newState
            endHint()
            updateAutoCheckHighlights()
            updateCanUndo()
                scheduleSave()
        }
    }

    func toggleMode() {
        inputMode.toggle()
    }

    /// Check marks nothing when mistakes are set to Never (CODESPEC 7.3); the hint still finds them.
    func checkCell() {
        guard settings.mistakes != .never,
              let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
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
            newState.checkedWrong.remove(cell.id)
        } else {
            newState.cells[index].isError = true
            newState.cells[index].isVerifiedCorrect = false
            newState.checkedWrong.insert(cell.id)
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
    }

    func checkPuzzle() {
        guard settings.mistakes != .never else { return }
        endHint() // the result shows in the hint slot, so an open hint closes first
        var newState = self.state
        // A second tap with nothing new to check hides the green "correct" marks. Any unchecked entry
        // is checked instead, so new mistakes are never skipped. Wrong values stay flagged (CODESPEC 6.2).
        let filled = newState.cells.filter { !$0.given && $0.value != nil }
        let allChecked = !filled.isEmpty && filled.allSatisfy { $0.isVerifiedCorrect || newState.checkedWrong.contains($0.id) }
        if allChecked && newState.cells.contains(where: { $0.isVerifiedCorrect }) {
            for idx in newState.cells.indices {
                newState.cells[idx].isVerifiedCorrect = false
            }
            self.state = newState
            showCheckResult()
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
                newState.checkedWrong.remove(cell.id)
            } else {
                newState.cells[idx].isError = true
                newState.cells[idx].isVerifiedCorrect = false
                newState.checkedWrong.insert(cell.id)
            }
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
        showCheckResult()
    }

    /// The hint slot's one-line Check result (CODESPEC 6.2).
    private func showCheckResult() {
        let wrong = state.cells.filter { !$0.given && $0.value != nil && $0.isError }.count
        checkMessage = wrong == 0 ? "No mistakes so far." : "\(wrong) wrong digit\(wrong == 1 ? "" : "s"), marked with a bar."
    }

    func revealCell() {
        endHint()
        guard let cellID = selectedCellID, let index = state.cells.firstIndex(where: { $0.id == cellID }) else { return }
        revealCell(at: index, markUsedReveal: true)
    }

    private func revealCell(at index: Int, markUsedReveal: Bool) {
        guard index < state.cells.count else { return }
        guard !state.cells[index].given && !state.cells[index].isRevealed else { return }
        recordUndoPoint()

        var newState = self.state
        alignImportedSolution(&newState)
        if let value = validator.solutionValue(row: newState.cells[index].row, col: newState.cells[index].col, solution: newState.puzzle.solutionGrid) {
            newState.cells[index].value = value
            newState.cells[index].isRevealed = true
            newState.checkedWrong.remove(newState.cells[index].id)
            newState.cells[index].candidates.removeAll()
            if markUsedReveal {
                newState.usedReveal = true
            }
            newState.cells[index].isVerifiedCorrect = false
            self.state = newState
            
            updateAutoCheckHighlights()
            checkIfSolved()
            updateCanUndo()
                scheduleSave()
        }
    }

    func revealPuzzle() {
        endHint()
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
        reportCompletion(newState)
    }

    func resetPuzzle() {
        let discarded = state.elapsedSeconds + calculateAndStopTimer()
        if !state.isCompleted, discarded > 0 { onTimeDiscarded?(discarded) }
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
        hint = nil // the old board's hint no longer applies
        checkMessage = nil
        coach = nil
        undoStack.removeAll()
        updateCanUndo()
        startTimerIfNeeded()
        saveNow()
    }

    /// Digits still to place, 9 minus those on the board (the keypad counts).
    var remaining: [Int: Int] {
        var left = Dictionary(uniqueKeysWithValues: (1...9).map { ($0, 9) })
        for case let value? in state.cells.map(\.value) where left[value] != nil { left[value]! -= 1 }
        return left
    }

    func load(state newState: GameState) {
        _ = calculateAndStopTimer()

        var finalState = newState
        finalState.checkedWrong = []
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
        hint = nil // the old board's hint no longer applies
        checkMessage = nil
        coach = nil
        undoStack.removeAll()
        isTimerRunning = false
        isManuallyPaused = false
        isBackgroundPaused = false
        isPaused = false
        updateCanUndo()
        updateAutoCheckHighlights()
        
        if !finalState.isCompleted {
            startTimerIfNeeded()
        }
    }

    func handle(pendingAction: PendingAction) {
        let action = pendingAction
        self.pendingAction = nil

        if case .newPuzzle = action {
            guard !isPreparingNewPuzzle else { return }
            isPreparingNewPuzzle = true
        }
        Task { @MainActor in
            switch action {
            case .newPuzzle:
                if let newState = await self.onNewGame?() {
                    self.load(state: newState)
                }
                self.hint = nil
                self.coach = nil
                self.isPreparingNewPuzzle = false
            case .reset:
                self.resetPuzzle()
            case .revealPuzzle:
                self.revealPuzzle()
            }
        }
    }

    func undo() {
        guard canUndo else { return }
        var previous = undoStack.removeLast()
        // Undo restores the board, not the clock or the fact that a reveal happened.
        previous.elapsedSeconds = state.elapsedSeconds
        previous.usedReveal = previous.usedReveal || state.usedReveal
        previous.assisted = previous.assisted || state.assisted
        previous.hintLog = state.hintLog
        state = previous
        selectedCellID = nil
        endHint()
        pendingAction = nil
        updateAutoCheckHighlights()
        updateCanUndo()
        scheduleSave()
    }

    // MARK: - Undo tracking

    private func recordUndoPoint() {
        guard !state.isCompleted else { return }
        undoStack.append(state)
        updateCanUndo()
    }

    private func updateCanUndo() {
        canUndo = !undoStack.isEmpty && !state.isCompleted
    }

    private func removeCandidate(_ digit: Int, relatedTo cell: SudokuCell, from cells: [SudokuCell]) -> [SudokuCell] {
        var newCells = cells
        for idx in newCells.indices where Board.peers[cell.index].contains(newCells[idx].index) {
            newCells[idx].candidates.remove(digit)
        }
        return newCells
    }

    private func updateAutoCheckHighlights() {
        var newState = self.state
        let conflicts = validator.conflictingIndices(in: newState.cells, autoCheckMistakes: settings.mistakes == .immediate)
        for idx in newState.cells.indices {
            if conflicts.contains(newState.cells[idx].id) {
                newState.cells[idx].isError = true
                newState.cells[idx].isVerifiedCorrect = false
            } else if !newState.cells[idx].given {
                let cell = newState.cells[idx]
                newState.cells[idx].isError = settings.mistakes != .never && newState.checkedWrong.contains(cell.id) && cell.value != nil
            }
        }
        updateContradictionFlag(on: &newState)
        self.state = newState
        updateCanUndo()
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
        reportCompletion(newState)
    }
    }

    /// Reports completion right away, so stats get this exact state and a later reset or new game
    /// is saved after it (a delayed report could overwrite newer progress).
    /// The app records stats unless `completed.counted` (a restarted solve); then it is counted.
    private func reportCompletion(_ completed: GameState) {
        saveTask?.cancel()
        onCompletion?(completed)
        if !completed.usedReveal { state.counted = true } // a revealed solve never reached the stats
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
        state.hasContradiction = Board.hasContradiction(Board.from(cells: state.cells))
    }

    private func markContradictionDetected() {
        var newState = state
        newState.hasContradiction = true
        state = newState
    }

    /// One timer tick. Internal for tests.
    func tick() async {
        guard let start = lastTickDate else { return }
        let now = timeProvider.now()
        var newState = self.state
        newState.elapsedSeconds += max(1, Int(now.timeIntervalSince(start)))
        lastTickDate = now // before publishing: `state`'s observer counts time since the last tick
        self.state = newState
        if newState.elapsedSeconds % autosaveIntervalSeconds == 0 {
            onSave?(state)
        }
    }

    /// The Solved summary's technique counts (`LogicalSolver.techniquesNeeded`), off the main thread.
    func techniquesNeeded() async -> [(name: String, count: Int)] {
        let puzzle = state.puzzle
        return await Task.detached(priority: .userInitiated) { LogicalSolver.techniquesNeeded(for: puzzle) }.value
    }
}

// MARK: - Hint ladder (CODESPEC 6.3.1)

extension GameViewModel {
    var hintHighlight: HintHighlight { coach?.highlight ?? hint?.highlight ?? HintHighlight() }

    /// Opens a hint: a mistake check first, then the simplest technique on the player's board.
    func requestHint() {
        guard !state.isCompleted else { return }
        endHint()
        let target = revealTarget() // read before the selection clears: a no-step hint fills the selected cell
        selectedCellID = nil // the card hides the selection; the keypad must not type into it
        var aligned = state
        let entriesFit = alignImportedSolution(&aligned)
        state = aligned
        if !entriesFit {
            // TODO(phase 4): with hasUniqueSolution, a unique import can point at the wrong digit like a generated puzzle.
            hint = HintSession(content: .mistake(cell: nil, kind: .entriesConflict))
        } else if let mistake = firstMistake() {
            hint = HintSession(content: .mistake(cell: mistake.cell, kind: mistake.kind))
        } else {
            let board = SolverBoard(cells: state.cells)
            if let step = LogicalSolver(allowsUniqueness: state.puzzle.isUnique).nextHintStep(board) {
                hint = HintSession(content: .step(step, board: board))
                onHintShown?(step.technique, step.placements + step.eliminations, state.puzzle.id)
            } else {
                let cell = target
                if let cell, let digit = solutionDigit(at: cell) {
                    onHintShown?(nil, [CellDigit(cell: cell, digit: digit)], state.puzzle.id)
                }
                hint = HintSession(content: .noStep(cell: cell, digit: cell.flatMap { solutionDigit(at: $0) }))
            }
        }
    }

    /// Steps 1 → 2 → 3. Free: nothing on the board or in stats changes.
    func hintNext() {
        hint?.next()
    }

    /// The Hint tool: opens a hint, then reads "Next step" and does what the card's button does.
    /// A card with no action (no step, or clashing entries with nothing to undo) just closes.
    func hintTool() {
        if coach != nil { return coachTool() }
        guard let session = hint else { return isStuck ? openCoach() : requestHint() }
        if session.canGoNext {
            hintNext()
        } else if session.canApply {
            applyHint()
        } else if session.offersUndo && canUndo {
            undo()
        } else {
            endHint()
        }
    }

    /// Step 3's action, as one undoable edit. Placing or removing marks the solve assisted; clearing a
    /// mistake does not. Eliminations in cells without notes write the cell's candidates first, so the
    /// deduction is kept and the next hint moves on.
    func applyHint() {
        guard let session = hint, session.canApply else { return }
        recordUndoPoint()
        var newState = state
        let indexOf = Dictionary(uniqueKeysWithValues: newState.cells.indices.map { (newState.cells[$0].index, $0) })
        var placements: [CellDigit] = []
        var focusCell: Int?
        switch session.content {
        case let .step(step, board):
            Self.remove(step.eliminations, from: &newState, indexOf: indexOf, board: board)
            placements = step.placements
            focusCell = step.target?.cell
            newState.assisted = true
        case let .noStep(cell?, digit?):
            placements = [CellDigit(cell: cell, digit: digit)]
            focusCell = cell
            newState.assisted = true
        case let .mistake(cell?, kind):
            guard let index = indexOf[cell] else { break }
            if case .wrongDigit = kind { newState.cells[index].value = nil }
            newState.cells[index].candidates.removeAll()
            clearMarks(at: index, in: &newState)
            focusCell = cell
        default:
            break
        }
        place(placements, in: &newState, indexOf: indexOf)
        state = newState
        endHint(applied: true)
        if let focusCell { selectedCellID = cellID(at: focusCell) }
        updateAutoCheckHighlights()
        checkIfSolved()
        updateCanUndo()
        scheduleSave()
    }

    /// Removes candidates. A cell without notes gets the board's candidates first, so the removal is kept.
    private static func remove(_ eliminations: [CellDigit], from state: inout GameState, indexOf: [Int: Int], board: SolverBoard) {
        for elimination in eliminations {
            guard let index = indexOf[elimination.cell], state.cells[index].value == nil else { continue }
            if state.cells[index].candidates.isEmpty {
                state.cells[index].candidates = Set(SolverBoard.digits(in: board.candidates[elimination.cell]))
            }
            state.cells[index].candidates.remove(elimination.digit)
        }
    }

    private func place(_ placements: [CellDigit], in state: inout GameState, indexOf: [Int: Int]) {
        for placement in placements {
            guard let index = indexOf[placement.cell], state.cells[index].value == nil else { continue }
            state.cells[index].value = placement.digit
            state.cells[index].candidates.removeAll()
            clearMarks(at: index, in: &state)
            if settings.tidyNotes {
                state.cells = removeCandidate(placement.digit, relatedTo: state.cells[index], from: state.cells)
            }
        }
    }

    private func clearMarks(at index: Int, in state: inout GameState) {
        state.cells[index].isError = false
        state.cells[index].isVerifiedCorrect = false
        state.checkedWrong.remove(state.cells[index].id)
    }

    /// Reports the technique a correct manual move shows (CODESPEC 13.4). Runs the detectors off the
    /// main thread. Moves from the hint card never get here (`applyHint`). The learning ledger then
    /// drops hinted and already-credited moves.
    private func judgeMove(_ move: MasteryJudge.Move, before board: SolverBoard) {
        // No credit while the board has a mistake: a wrong digit can make a "single" that only looks found.
        guard let onTechniqueFound else { return }
        let solution = Array(state.puzzle.solutionGrid).map { Int(String($0)) ?? 0 }
        guard solution.count == 81 else { return }
        // Cheap check first: the move itself must be right.
        switch move {
        case let .placed(cell, digit):
            guard solution[cell] == digit else { return }
        case let .removedCandidate(cell, digit):
            guard solution[cell] != digit else { return }
        }
        guard firstMistake() == nil else { return }
        let unique = state.puzzle.isUnique
        let puzzleID = state.puzzle.id
        Task.detached(priority: .utility) {
            guard let technique = MasteryJudge.technique(for: move, on: board, allowsUniqueness: unique) else { return }
            // The puzzle id was taken with the move, so a credit never lands on a puzzle loaded since.
            await MainActor.run { onTechniqueFound(technique, puzzleID, move) }
        }
    }

    /// Closes the open hint or coach and records it in the hint log. A coach counts as a hint only
    /// once its move was shown.
    func endHint(applied: Bool = false) {
        checkMessage = nil // any move, selection or hint ends the Check message
        if let coach {
            self.coach = nil
            logRevealed(coach.revealedSteps)
        }
        guard let session = hint else { return }
        hint = nil
        let name: String
        switch session.content {
        case .mistake: name = "mistake"
        case .step(let step, _): name = step.technique.rawValue
        case .noStep: name = "noStep"
        }
        state.hintLog.append(HintLogEntry(technique: name, deepestRung: session.deepestLevel, applied: applied))
    }

    /// Checked before any technique: a wrong digit, or notes that leave out the cell's digit. Empty cells without notes
    /// and stale notes (digits already placed in a peer) are never mistakes.
    private func firstMistake() -> (cell: Int, kind: HintSession.MistakeKind)? {
        let solution = Array(state.puzzle.solutionGrid).map { Int(String($0)) ?? 0 }
        guard solution.count == 81 else { return nil }
        let cells = state.cells.sorted { $0.index < $1.index }
        if let wrong = cells.first(where: { !$0.given && $0.value != nil && $0.value != solution[$0.index] }) {
            let digit = wrong.value ?? 0
            // Prefer a clash whose digit is right, so the step-3 text never vouches for another mistake.
            let clashes = SolverBoard.peers[wrong.index].filter { cells[$0].value == digit }
            let clash = clashes.first { solution[$0] == digit } ?? clashes.first
            return (wrong.index, .wrongDigit(digit, clash: clash))
        }
        let suspects = cells.filter { $0.value == nil && !$0.candidates.isEmpty && !$0.candidates.contains(solution[$0.index]) }
        // An import may have several solutions: a note is only wrong if none of its digits can work.
        let missing = state.puzzle.source == .imported ? suspects.first { !anyNoteCanWork(in: $0) } : suspects.first
        return missing.map { ($0.index, .missingNote) }
    }

    private func anyNoteCanWork(in cell: SudokuCell) -> Bool {
        var grid = state.cells.sorted { $0.index < $1.index }.map { $0.value ?? 0 }
        return cell.candidates.contains { digit in
            grid[cell.index] = digit
            return hintService.solve(initialGrid: grid.map(String.init).joined()) != nil
        }
    }

    /// The cell Reveal would fill: the selected empty cell, else the first empty cell.
    private func revealTarget() -> Int? {
        if let id = selectedCellID, let cell = state.cells.first(where: { $0.id == id }), cell.value == nil { return cell.index }
        return state.cells.filter { $0.value == nil }.map(\.index).min()
    }

    private func solutionDigit(at cell: Int) -> Int? {
        let solution = Array(state.puzzle.solutionGrid)
        return solution.count == 81 ? Int(String(solution[cell])) : nil
    }

    private func cellID(at index: Int) -> UUID? {
        state.cells.first { $0.index == index }?.id
    }
}

// MARK: - Coach (CODESPEC 6.3.3)

extension GameViewModel {
    /// Opens the coach on the player's board. Mistakes come first, as with a hint, since patterns on a
    /// wrong board would mislead; with nothing to teach it falls back to the hint.
    func openCoach() {
        guard !state.isCompleted else { return }
        endHint()
        resetStuck()
        var aligned = state
        let entriesFit = alignImportedSolution(&aligned)
        state = aligned
        let board = SolverBoard(cells: state.cells)
        let patterns = LogicalSolver(allowsUniqueness: state.puzzle.isUnique).patterns(board)
        guard entriesFit, firstMistake() == nil, let session = CoachSession(board: board, patterns: patterns) else {
            return requestHint()
        }
        selectedCellID = nil // the card hides the selection; the keypad must not type into it
        coach = session
    }

    func coachForward() { coach?.forward() }
    func coachBack() { coach?.back() }
    func coachToggleDefinition() { coach?.toggleDefinition() }

    /// "Show me": the move appears on the board. From here the player didn't find it alone, so the
    /// learning ledger hears about it like a hint.
    func coachReveal() {
        guard let session = coach, !session.revealed else { return }
        coach?.reveal()
        let step = session.current
        onHintShown?(step.technique, step.placements + step.eliminations, state.puzzle.id)
    }

    /// Applies the revealed move, as the hint's step 3 does (assisted).
    func applyCoach() {
        guard let session = coach, session.revealed else { return }
        coach = nil
        logRevealed(session.revealedSteps.filter { $0 != session.current }) // the applied one logs itself
        hint = session.hint
        applyHint()
    }

    /// One hint per pattern the player revealed (CODESPEC 6.3.3), even if they paged away from it.
    private func logRevealed(_ steps: [TechniqueStep]) {
        for step in steps {
            state.hintLog.append(HintLogEntry(technique: step.technique.rawValue, deepestRung: HintSession.stepCount, applied: false))
        }
    }

    /// The Hint tool while the coach is open: Show me, then Apply.
    private func coachTool() {
        guard let session = coach else { return }
        session.revealed ? applyCoach() : coachReveal()
    }

    /// Stuck: no new correct digit for `stuckAfterSeconds` of play (pauses don't count). Runs on every
    /// state change, so a move between timer ticks counts at once.
    func updateStuck() {
        let correct = state.cells.filter { cell in
            guard !cell.given, let value = cell.value else { return false }
            return solutionDigit(at: cell.index).map { $0 == value } ?? true
        }.count
        // Play time now: the saved seconds plus the stretch the timer is running (a move can land between ticks).
        let played = state.elapsedSeconds + (lastTickDate.map { max(0, Int(timeProvider.now().timeIntervalSince($0))) } ?? 0)
        // A new correct digit (also after an undo or erase), another puzzle, or a restart (the clock went
        // back) starts the count again.
        if correct > correctCount || state.puzzle.id != progressPuzzleID || played < progressSeconds {
            progressSeconds = played
            progressPuzzleID = state.puzzle.id
        }
        correctCount = correct
        let stuck = settings.coachWhenStuck && !state.isCompleted && played - progressSeconds >= Self.stuckAfterSeconds
        if stuck != isStuck { isStuck = stuck }
    }

    private func resetStuck() {
        progressSeconds = state.elapsedSeconds
        if isStuck { isStuck = false }
    }
}

