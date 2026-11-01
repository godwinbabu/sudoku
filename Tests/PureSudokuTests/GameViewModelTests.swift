import XCTest
@testable import PureSudoku

@MainActor
final class GameViewModelTests: XCTestCase {
    private func makeViewModel(settings: Settings = Settings()) -> GameViewModel {
        GameViewModel(state: TestData.newGameState(), settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
    }

    func testNormalModeSetsValueAndClearsCandidates() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else {
            return XCTFail("No editable cell")
        }
        viewModel.select(cell: cell)
        viewModel.setDigit(5)
        XCTAssertEqual(viewModel.state.cells.first(where: { $0.id == cell.id })?.value, 5)
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.isEmpty ?? false)
    }

    func testCandidateModeToggles() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.toggleMode()
        viewModel.setDigit(4)
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.contains(4) ?? false)
        viewModel.setDigit(4)
        XCTAssertFalse(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.contains(4) ?? true)
    }

    func testAutoRemoveCandidates() {
        var settings = Settings()
        settings.autoRemoveCandidates = true
        let viewModel = makeViewModel(settings: settings)
        guard let editable = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: editable)
        viewModel.toggleMode()
        viewModel.setDigit(3)
        // ensure peer candidate exists
        guard let peer = viewModel.state.cells.first(where: { $0.row == editable.row && !$0.given && $0.id != editable.id }) else { return XCTFail("Missing peer") }
        viewModel.select(cell: peer)
        viewModel.toggleMode()
        viewModel.setDigit(3)
        viewModel.toggleMode() // back to normal
        viewModel.select(cell: editable)
        viewModel.setDigit(3)
        let updatedPeer = viewModel.state.cells.first(where: { $0.id == peer.id })
        XCTAssertFalse(updatedPeer?.candidates.contains(3) ?? true)
    }

    func testCheckCellSetsErrorFlag() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.setDigit(1) // wrong on purpose
        viewModel.checkCell()
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.isError ?? false)
    }

    func testRevealCellFillsCorrectValue() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.revealCell()
        let updated = viewModel.state.cells.first(where: { $0.id == cell.id })
        XCTAssertNotNil(updated?.value)
        XCTAssertTrue(updated?.isRevealed ?? false)
        XCTAssertTrue(viewModel.state.usedReveal)
    }

    func testResetClearsInputs() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.setDigit(5)
        viewModel.resetPuzzle()
        XCTAssertNil(viewModel.state.cells.first(where: { $0.id == cell.id })?.value)
        XCTAssertFalse(viewModel.state.usedReveal)
        XCTAssertEqual(viewModel.state.elapsedSeconds, 0)
    }

    func testRequestHintFillsValueAndSetsMessage() {
        var state = TestData.newGameState()
        let solution = Array(TestData.puzzle.solutionGrid)
        guard let targetIndex = state.cells.firstIndex(where: { !$0.given }) else { return XCTFail("Missing editable cell") }

        // Fill other editable cells with correct values to create a naked/hidden single at target.
        for idx in state.cells.indices where idx != targetIndex && !state.cells[idx].given {
            let valueChar = solution[state.cells[idx].row * 9 + state.cells[idx].col]
            state.cells[idx].value = Int(String(valueChar))
        }

        let viewModel = GameViewModel(state: state, settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider(), hintService: SudokuGeneratorService())
        viewModel.requestHint()

        let updated = viewModel.state.cells[targetIndex]
        XCTAssertNotNil(updated.value)
        XCTAssertTrue(viewModel.state.usedReveal)
        XCTAssertNotNil(viewModel.hintMessage)
    }

    func testRequestHintRespectsManualModeWhenAutoFillDisabled() {
        var state = TestData.newGameState()
        let solution = Array(TestData.puzzle.solutionGrid)
        guard let targetIndex = state.cells.firstIndex(where: { !$0.given }) else { return XCTFail("Missing editable cell") }

        for idx in state.cells.indices where idx != targetIndex && !state.cells[idx].given {
            let valueChar = solution[state.cells[idx].row * 9 + state.cells[idx].col]
            state.cells[idx].value = Int(String(valueChar))
        }

        var settings = Settings()
        settings.autoFillHints = false

        let viewModel = GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider(), hintService: SudokuGeneratorService())
        viewModel.requestHint()

        let updated = viewModel.state.cells[targetIndex]
        XCTAssertNil(updated.value)
        XCTAssertFalse(viewModel.state.usedReveal)
        XCTAssertEqual(viewModel.selectedCellID, updated.id)
        XCTAssertNotNil(viewModel.hintMessage)
    }

    func testRevealPuzzleTwiceReportsCompletionOnce() async {
        let viewModel = makeViewModel()
        let completed = expectation(description: "completion reported")
        completed.assertForOverFulfill = true
        viewModel.onCompletion = { state in
            XCTAssertTrue(state.isCompleted)
            completed.fulfill()
        }
        viewModel.revealPuzzle()
        viewModel.revealPuzzle()
        await fulfillment(of: [completed], timeout: 1)
        let extra = expectation(description: "no second completion")
        extra.isInverted = true
        viewModel.onCompletion = { _ in extra.fulfill() }
        await fulfillment(of: [extra], timeout: 0.3)
    }

    func testCompletionReportsStateCapturedAtCompletion() async {
        let viewModel = makeViewModel()
        let completed = expectation(description: "completion reported")
        viewModel.onCompletion = { state in
            XCTAssertTrue(state.isCompleted)
            XCTAssertTrue(state.usedReveal)
            completed.fulfill()
        }
        viewModel.revealPuzzle()
        viewModel.resetPuzzle()
        await fulfillment(of: [completed], timeout: 1)
    }

    func testCheckCellNeverClearsAWrongValue() {
        var settings = Settings()
        settings.autoCheckMistakes = false
        let viewModel = makeViewModel(settings: settings)
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        let answer = Int(String(Array(TestData.puzzle.solutionGrid)[cell.index]))!
        viewModel.select(cell: cell)
        viewModel.setDigit(answer == 9 ? 1 : answer + 1)
        viewModel.checkCell()
        XCTAssertTrue(viewModel.state.cells[cell.index].isError)
        viewModel.checkCell()
        XCTAssertTrue(viewModel.state.cells[cell.index].isError)
        viewModel.checkPuzzle()
        viewModel.checkPuzzle()
        XCTAssertTrue(viewModel.state.cells[cell.index].isError)
        // A later, unrelated move must not erase the check result.
        let other = viewModel.state.cells.first(where: { !$0.given && $0.id != cell.id })!
        viewModel.select(cell: other)
        viewModel.toggleMode()
        viewModel.setDigit(3)
        XCTAssertTrue(viewModel.state.cells[cell.index].isError)
    }

    func testUndoRestoresCheckResult() {
        var settings = Settings()
        settings.autoCheckMistakes = false
        let viewModel = makeViewModel(settings: settings)
        let cell = viewModel.state.cells[2] // r1c3, answer 4
        viewModel.select(cell: cell)
        viewModel.setDigit(1)
        viewModel.checkCell()
        XCTAssertTrue(viewModel.state.cells[2].isError)
        viewModel.setDigit(4)
        viewModel.undo()
        XCTAssertEqual(viewModel.state.cells[2].value, 1)
        XCTAssertTrue(viewModel.state.cells[2].isError)
    }

    func testSecondCheckPuzzleStillChecksNewEntries() {
        var settings = Settings()
        settings.autoCheckMistakes = false
        let viewModel = makeViewModel(settings: settings)
        viewModel.select(cell: viewModel.state.cells[2]) // r1c3, answer 4
        viewModel.setDigit(4)
        viewModel.checkPuzzle()
        XCTAssertTrue(viewModel.state.cells[2].isVerifiedCorrect)
        viewModel.select(cell: viewModel.state.cells[3]) // r1c4, answer 6
        viewModel.setDigit(2)
        viewModel.checkPuzzle()
        XCTAssertTrue(viewModel.state.cells[3].isError)
        viewModel.checkPuzzle() // nothing new: hides green marks only
        XCTAssertFalse(viewModel.state.cells[2].isVerifiedCorrect)
        XCTAssertTrue(viewModel.state.cells[3].isError)
    }

    func testBackgroundPauseResumesWithoutOverlay() {
        let clock = AdvancingTimeProvider()
        let viewModel = GameViewModel(state: TestData.newGameState(), settings: Settings(), validator: SudokuValidator(), timeProvider: clock)
        viewModel.handleSceneDidAppear()
        clock.advance(5)
        viewModel.pauseForBackground()
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertFalse(viewModel.isTimerRunning)
        XCTAssertEqual(viewModel.state.elapsedSeconds, 5)
        clock.advance(100) // time in background does not count
        viewModel.resumeFromBackground()
        XCTAssertTrue(viewModel.isTimerRunning)
        clock.advance(3)
        viewModel.pauseTimer()
        XCTAssertEqual(viewModel.state.elapsedSeconds, 8)
    }

    func testResetRestartsTimerFromZero() {
        let clock = AdvancingTimeProvider()
        let viewModel = GameViewModel(state: TestData.newGameState(), settings: Settings(), validator: SudokuValidator(), timeProvider: clock)
        viewModel.handleSceneDidAppear()
        clock.advance(30)
        viewModel.resetPuzzle()
        XCTAssertTrue(viewModel.isTimerRunning)
        clock.advance(2)
        viewModel.pauseTimer()
        XCTAssertEqual(viewModel.state.elapsedSeconds, 2)
    }

    func testEditIsAutosavedAfterDelay() async {
        let viewModel = makeViewModel()
        viewModel.autosaveDelayNanoseconds = 10_000_000
        let saved = expectation(description: "autosave")
        viewModel.onSave = { _ in saved.fulfill() }
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.select(cell: cell)
        viewModel.setDigit(1)
        await fulfillment(of: [saved], timeout: 1)
    }

    func testHintPointsAtWrongEntryInGeneratedPuzzle() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        let answer = Int(String(Array(TestData.puzzle.solutionGrid)[cell.index]))!
        let other = viewModel.state.cells.first(where: { !$0.given && $0.id != cell.id })!
        viewModel.select(cell: cell)
        viewModel.setDigit(answer == 9 ? 1 : answer + 1)
        viewModel.select(cell: other)
        viewModel.requestHint()
        XCTAssertEqual(viewModel.selectedCellID, cell.id)
        XCTAssertFalse(viewModel.state.usedReveal)
        XCTAssertNotNil(viewModel.hintMessage)
    }

    func testImportedPuzzleAcceptsAnyValidSolution() async {
        // An empty-ish imported grid has many solutions; solve it one way, store a different answer.
        let service = SudokuGeneratorService()
        let givens = String(TestData.puzzle.solutionGrid.prefix(9)) + String(repeating: "0", count: 72)
        let answerA = service.solve(initialGrid: givens)!
        var other: String?
        for _ in 0..<20 {
            let candidate = service.solve(initialGrid: givens)!
            if candidate != answerA { other = candidate; break }
        }
        guard let answerB = other else { return XCTFail("Solver returned the same solution 20 times") }
        let puzzle = SudokuPuzzle(id: "imp", difficulty: .easy, initialGrid: givens, solutionGrid: answerA, source: .imported)
        let viewModel = GameViewModel(state: GameState.newGame(for: puzzle), settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider())
        let completed = expectation(description: "completed")
        viewModel.onCompletion = { _ in completed.fulfill() }
        let digitsB = Array(answerB)
        for cell in viewModel.state.cells where !cell.given {
            viewModel.select(cell: cell)
            viewModel.setDigit(Int(String(digitsB[cell.index]))!)
        }
        await fulfillment(of: [completed], timeout: 1)
        XCTAssertTrue(viewModel.state.isCompleted)
        XCTAssertFalse(viewModel.state.cells.contains { $0.isError })
    }

    func testUndoKeepsElapsedTime() {
        let clock = AdvancingTimeProvider()
        let viewModel = GameViewModel(state: TestData.newGameState(), settings: Settings(), validator: SudokuValidator(), timeProvider: clock)
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }
        viewModel.handleSceneDidAppear()
        viewModel.select(cell: cell)
        viewModel.setDigit(1)
        clock.advance(60)
        viewModel.pauseTimer()
        XCTAssertEqual(viewModel.state.elapsedSeconds, 60)
        viewModel.undo()
        XCTAssertEqual(viewModel.state.elapsedSeconds, 60)
    }

    func testPauseIgnoredAfterCompletion() {
        let viewModel = makeViewModel()
        viewModel.revealPuzzle() // marks puzzle as completed
        viewModel.pauseForBackground()
        XCTAssertTrue(viewModel.state.isCompleted)
        XCTAssertFalse(viewModel.isPaused)
    }

    func testUndoRevertsSequentialChanges() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }

        viewModel.select(cell: cell)
        viewModel.setDigit(1)
        viewModel.setDigit(2)
        XCTAssertEqual(viewModel.state.cells.first(where: { $0.id == cell.id })?.value, 2)
        XCTAssertTrue(viewModel.canUndo)

        viewModel.undo()
        XCTAssertEqual(viewModel.state.cells.first(where: { $0.id == cell.id })?.value, 1)
        XCTAssertTrue(viewModel.canUndo)

        viewModel.undo()
        XCTAssertNil(viewModel.state.cells.first(where: { $0.id == cell.id })?.value)
        XCTAssertFalse(viewModel.canUndo)
    }

    func testUndoRestoresCandidateNotes() {
        let viewModel = makeViewModel()
        guard let cell = viewModel.state.cells.first(where: { !$0.given }) else { return XCTFail("No editable cell") }

        viewModel.select(cell: cell)
        viewModel.toggleMode()
        viewModel.setDigit(4)
        XCTAssertTrue(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.contains(4) ?? false)
        XCTAssertTrue(viewModel.canUndo)

        viewModel.undo()
        XCTAssertFalse(viewModel.state.cells.first(where: { $0.id == cell.id })?.candidates.contains(4) ?? true)
        XCTAssertFalse(viewModel.canUndo)
    }
}
