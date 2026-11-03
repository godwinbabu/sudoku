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

    /// The keypad count drops as a digit is placed; at zero its key is disabled.
    func testCompletedDigitKeyIsDisabled() {
        let viewModel = makeViewModel()
        let solution = Array(viewModel.state.puzzle.solutionGrid).map { Int(String($0)) ?? 0 }
        let digit = 5
        let missing = viewModel.state.cells.filter { !$0.given && solution[$0.index] == digit }
        XCTAssertEqual(viewModel.remaining[digit], missing.count)
        for cell in missing {
            viewModel.select(cell: cell)
            viewModel.setDigit(digit)
        }
        XCTAssertEqual(viewModel.remaining[digit], 0)
    }

    func testFillAllNotesIsOneUndo() {
        let viewModel = makeViewModel()
        viewModel.fillAllNotes()
        let solution = Array(viewModel.state.puzzle.solutionGrid).map { Int(String($0)) ?? 0 }
        for cell in viewModel.state.cells where cell.value == nil {
            XCTAssertTrue(cell.candidates.contains(solution[cell.index]), "notes keep the answer")
            let peerValues = Set(Board.peers[cell.index].compactMap { viewModel.state.cells[$0].value })
            XCTAssertTrue(cell.candidates.isDisjoint(with: peerValues), "notes skip digits a peer holds")
        }
        viewModel.undo()
        XCTAssertTrue(viewModel.state.cells.allSatisfy { $0.candidates.isEmpty })
    }

    func testTechniqueCountsCoverTheGrid() async {
        let counts = await makeViewModel().techniqueCounts()
        XCTAssertFalse(counts.isEmpty)
        XCTAssertEqual(counts.map(\.count), counts.map(\.count).sorted(by: >), "most used first")
        // Hidden Single (box) and Hidden Single (line) share one name; it must show once.
        XCTAssertEqual(Set(counts.map(\.name)).count, counts.count, "no name repeats")
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

    func testTidyNotes() {
        var settings = Settings()
        settings.tidyNotes = true
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
        settings.mistakes = .onCheck
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

    func testOverlappingNewPuzzleRequestsRunOnce() async {
        let viewModel = makeViewModel()
        var calls = 0
        let loaded = expectation(description: "new game loaded")
        viewModel.onNewGame = {
            calls += 1
            try? await Task.sleep(nanoseconds: 50_000_000)
            return TestData.newGameState()
        }
        viewModel.handle(pendingAction: .newPuzzle)
        viewModel.handle(pendingAction: .newPuzzle)
        XCTAssertTrue(viewModel.isPreparingNewPuzzle)
        Task { @MainActor in
            while viewModel.isPreparingNewPuzzle { try? await Task.sleep(nanoseconds: 10_000_000) }
            loaded.fulfill()
        }
        await fulfillment(of: [loaded], timeout: 2)
        XCTAssertEqual(calls, 1)
    }

    func testUndoRestoresCheckResult() {
        var settings = Settings()
        settings.mistakes = .onCheck
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
        settings.mistakes = .onCheck
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
