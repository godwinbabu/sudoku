import XCTest
@testable import PureSudoku

/// Hint ladder (CODESPEC 6.3.1).
@MainActor
final class HintLadderTests: XCTestCase {
    private let solution = Array(TestData.puzzle.solutionGrid).map { Int(String($0))! }

    private func makeViewModel(state: GameState = TestData.newGameState(), askFirst: Bool = true, autoRemove: Bool = true) -> GameViewModel {
        var settings = Settings()
        settings.askBeforeHintResult = askFirst
        settings.autoRemoveCandidates = autoRemove
        return GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
    }

    private func values(_ viewModel: GameViewModel) -> [Int?] { viewModel.state.cells.map(\.value) }

    private func emptyCell(_ viewModel: GameViewModel, after skip: Int = 0) -> SudokuCell {
        viewModel.state.cells.filter { $0.value == nil }[skip]
    }

    // MARK: - Rung 0

    func testWrongDigitIsReportedBeforeAnyTechnique() {
        let viewModel = makeViewModel()
        let cell = emptyCell(viewModel)
        viewModel.select(cell: cell)
        viewModel.setDigit(solution[cell.index] % 9 + 1) // wrong on purpose
        let before = values(viewModel)

        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.content, .mistake(cell: cell.index, kind: .wrongDigit))
        XCTAssertEqual(viewModel.hint?.rung, 0)
        viewModel.hintNext()
        XCTAssertEqual(viewModel.hintHighlight.areaCells, Set(House(kind: .box, index: SolverBoard.box(of: cell.index)).cells))
        viewModel.hintNext()
        XCTAssertEqual(viewModel.selectedCellID, cell.id)
        XCTAssertEqual(viewModel.hintHighlight.patternCells, [cell.index])
        XCTAssertFalse(viewModel.hint?.canGoNext ?? true)
        XCTAssertEqual(values(viewModel), before, "rung 0 never changes the board")
        XCTAssertFalse(viewModel.state.usedHint)
    }

    func testNoNotesAnywhereGivesATechnique() {
        let viewModel = makeViewModel()
        viewModel.requestHint()
        XCTAssertNotNil(viewModel.hint?.step)
    }

    func testStaleNotesAreIgnoredButMissingDigitIsAMistake() {
        let viewModel = makeViewModel(autoRemove: false)
        let cell = emptyCell(viewModel)
        let placedInRow = viewModel.state.cells.first { $0.row == cell.row && $0.value != nil }!.value!
        viewModel.select(cell: cell)
        viewModel.toggleMode()
        viewModel.setDigit(solution[cell.index])
        viewModel.setDigit(placedInRow) // stale: already placed in the row
        viewModel.requestHint()
        XCTAssertNotNil(viewModel.hint?.step, "a stale note is not a mistake")

        let other = emptyCell(viewModel, after: 1)
        viewModel.select(cell: other)
        viewModel.setDigit(solution[other.index] % 9 + 1) // notes without the right digit
        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.content, .mistake(cell: other.index, kind: .missingNote))
    }

    // MARK: - Rungs 1-4

    func testRungsOneToThreeNeverChangeTheBoardOrStats() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.rung, 1)
        viewModel.hintNext()
        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.rung, 3)
        XCTAssertEqual(values(viewModel), before)
        XCTAssertFalse(viewModel.state.usedHint)
    }

    func testShowingTheResultSetsUsedHintAndApplyIsOneUndo() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        viewModel.hintNext()
        viewModel.hintNext()
        viewModel.hintNext()
        XCTAssertTrue(viewModel.hint?.isAskingBeforeResult ?? false, "asks \"Try it yourself first?\"")
        XCTAssertFalse(viewModel.state.usedHint)
        viewModel.hintShowResult()
        XCTAssertEqual(viewModel.hint?.rung, 4)
        XCTAssertTrue(viewModel.state.usedHint)

        viewModel.applyHint()
        XCTAssertNil(viewModel.hint)
        XCTAssertNotEqual(values(viewModel), before)
        XCTAssertEqual(viewModel.state.hintLog.last, HintLogEntry(technique: viewModel.state.hintLog.last!.technique, deepestRung: 4, applied: true))

        viewModel.undo()
        XCTAssertEqual(values(viewModel), before)
        XCTAssertTrue(viewModel.state.usedHint, "Undo never clears usedHint")
    }

    func testAskFirstOffGoesStraightToTheResult() {
        let viewModel = makeViewModel(askFirst: false)
        viewModel.requestHint()
        for _ in 0..<3 { viewModel.hintNext() }
        XCTAssertEqual(viewModel.hint?.rung, 4)
        XCTAssertTrue(viewModel.state.usedHint)
    }

    func testSameBoardGivesTheSameHint() {
        let viewModel = makeViewModel()
        viewModel.requestHint()
        let first = viewModel.hint?.step
        viewModel.endHint()
        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.step, first)
    }

    func testDoneClosesWithoutChangingAndLogsTheRung() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        viewModel.hintNext()
        viewModel.endHint()
        XCTAssertNil(viewModel.hint)
        XCTAssertEqual(values(viewModel), before)
        XCTAssertEqual(viewModel.state.hintLog.last?.deepestRung, 2)
        XCTAssertEqual(viewModel.state.hintLog.last?.applied, false)
    }

    /// For singles the pattern cell is the answer, so rung 3 must not outline or ring it.
    func testSinglesKeepTheAnswerHiddenUntilTheResult() {
        let viewModel = makeViewModel()
        viewModel.requestHint()
        guard let step = viewModel.hint?.step, !step.placements.isEmpty else { return XCTFail("expected a single") }
        viewModel.hintNext()
        viewModel.hintNext()
        XCTAssertTrue(viewModel.hintHighlight.patternCells.isEmpty)
        XCTAssertTrue(viewModel.hintHighlight.ghostDigits.isEmpty)
    }

    /// Eliminations in cells without notes must be kept (as notes), so the next hint moves on.
    func testAppliedEliminationIsKeptAndTheNextHintMovesOn() throws {
        let state = try XCTUnwrap(Self.stateNeedingAnElimination())
        let viewModel = makeViewModel(state: state, askFirst: false)
        for _ in 0..<120 {
            viewModel.requestHint()
            guard let step = viewModel.hint?.step else { return XCTFail("solver stopped before an elimination") }
            for _ in 0..<3 { viewModel.hintNext() }
            viewModel.applyHint()
            guard step.placements.isEmpty else { continue }
            for elimination in step.eliminations {
                let cell = viewModel.state.cells.first { $0.index == elimination.cell }!
                XCTAssertFalse(cell.candidates.isEmpty)
                XCTAssertFalse(cell.candidates.contains(elimination.digit))
            }
            viewModel.requestHint()
            XCTAssertNotEqual(viewModel.hint?.step, step, "the same elimination must not come back")
            return
        }
        XCTFail("no elimination step within 120 hints")
    }

    func testNoStepOffersRevealInsteadOfNothing() throws {
        let state = try XCTUnwrap(Self.stuckState())
        let viewModel = makeViewModel(state: state)
        viewModel.requestHint()
        guard case .noStep(let cell?) = viewModel.hint?.content else { return XCTFail("expected no-step hint") }
        viewModel.hintRevealCell()
        XCTAssertNotNil(viewModel.state.cells.first { $0.index == cell }?.value)
        XCTAssertTrue(viewModel.state.usedReveal)
    }

    func testShowAfterHidesEliminatedDigitsEvenInCellsWithNotes() throws {
        var state = try XCTUnwrap(Self.stateNeedingAnElimination())
        // Every empty cell carries the player's own notes (the full candidate list).
        let board = SolverBoard(cells: state.cells)
        for index in state.cells.indices where state.cells[index].value == nil {
            state.cells[index].candidates = Set(SolverBoard.digits(in: board.candidates[state.cells[index].index]))
        }
        let viewModel = makeViewModel(state: state, askFirst: false)
        for _ in 0..<120 {
            viewModel.requestHint()
            guard let step = viewModel.hint?.step else { return XCTFail("solver stopped before an elimination") }
            for _ in 0..<3 { viewModel.hintNext() }
            guard let elimination = step.eliminations.first, step.placements.isEmpty else { viewModel.applyHint(); continue }
            let notes = viewModel.state.cells.first { $0.index == elimination.cell }!.candidates
            XCTAssertTrue(notes.contains(elimination.digit), "the eliminated cell has player notes")
            XCTAssertEqual(viewModel.hintHighlight.struckDigits[elimination.cell]?.contains(elimination.digit), true)
            viewModel.hintToggleAfter()
            XCTAssertEqual(viewModel.hintHighlight.hiddenDigits[elimination.cell]?.contains(elimination.digit), true)
            XCTAssertNil(viewModel.hintHighlight.struckDigits[elimination.cell])
            return
        }
        XCTFail("no elimination step within 120 hints")
    }

    func testImportedPuzzleAcceptsANoteFromAnotherValidSolution() throws {
        // Only the first row is given, so the puzzle has many solutions.
        let givens = String(TestData.puzzle.solutionGrid.prefix(9)) + String(repeating: "0", count: 72)
        let service = SudokuGeneratorService()
        let stored = Array(try XCTUnwrap(service.solve(initialGrid: givens))).map { Int(String($0))! }
        let puzzle = SudokuPuzzle(id: "import", difficulty: .hard, initialGrid: givens, solutionGrid: stored.map(String.init).joined(), source: .imported)
        let viewModel = makeViewModel(state: GameState.newGame(for: puzzle))
        // r2c1 can hold another digit in a different valid solution.
        let cell = 9
        let other = try XCTUnwrap((1...9).first { digit in
            digit != stored[cell] && service.solve(initialGrid: String(givens.prefix(cell)) + String(digit) + String(givens.dropFirst(cell + 1))) != nil
        })
        viewModel.select(cell: viewModel.state.cells.first { $0.index == cell }!)
        viewModel.toggleMode()
        viewModel.setDigit(other)
        viewModel.requestHint()
        XCTAssertNotNil(viewModel.hint)
        if case .mistake = viewModel.hint?.content { XCTFail("a note that fits another solution is not a mistake") }
    }

    func testEditingTheBoardClosesTheHint() {
        let viewModel = makeViewModel(askFirst: false)
        viewModel.requestHint()
        for _ in 0..<3 { viewModel.hintNext() }
        let cell = viewModel.state.cells.first { $0.value == nil && !(viewModel.hint?.step?.placements.map(\.cell).contains($0.index) ?? false) }!
        viewModel.select(cell: cell)
        viewModel.setDigit(solution[cell.index])
        XCTAssertNil(viewModel.hint)
        let after = values(viewModel)
        viewModel.applyHint()
        XCTAssertEqual(values(viewModel), after, "a closed hint cannot be applied")
    }

    // MARK: - Stats and saved data

    func testHintedSolveCountsButSkipsBestTime() {
        var stats = Stats()
        stats.recordCompletion(for: .easy, time: 300, usedReveal: false)
        stats.recordCompletion(for: .easy, time: 100, usedReveal: false, usedHint: true)
        XCTAssertEqual(stats.bestTime(for: .easy), 300)
        XCTAssertEqual(stats.solvedCount(for: .easy), 2)
        XCTAssertEqual(stats.totalTimeSeconds, 400)
    }

    func testOldSavesLoadWithDefaults() throws {
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TestData.newGameState())) as? [String: Any])
        state.removeValue(forKey: "usedHint")
        state.removeValue(forKey: "hintLog")
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: state))
        XCTAssertFalse(decoded.usedHint)
        XCTAssertTrue(decoded.hintLog.isEmpty)

        var settings = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any])
        settings.removeValue(forKey: "askBeforeHintResult")
        settings.removeValue(forKey: "cellNameStyle")
        settings["autoFillHints"] = true // written by the previous version
        let loaded = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertTrue(loaded.askBeforeHintResult)
        XCTAssertEqual(loaded.cellNameStyle, .long)
    }

    // MARK: - Fixtures

    private static func generated(_ predicate: (LogicalSolver.Result) -> Bool) -> (puzzle: [Int], solution: [Int])? {
        var rng = SeededRandomNumberGenerator(seed: 7)
        for _ in 0..<200 {
            let board = makePuzzle(using: &rng)
            let values = board.map { ($0 ?? -1) + 1 }
            if predicate(LogicalSolver().solve(SolverBoard(values: values))) {
                return (values, solvePuzzle(board, using: &rng)!.map { $0! + 1 })
            }
        }
        return nil
    }

    private static func gameState(_ puzzle: [Int], _ solution: [Int]) -> GameState {
        GameState.newGame(for: SudokuPuzzle(
            id: "fixture", difficulty: .hard,
            initialGrid: puzzle.map(String.init).joined(),
            solutionGrid: solution.map(String.init).joined()
        ))
    }

    private static func stateNeedingAnElimination() -> GameState? {
        generated { $0.isSolved && $0.steps.contains { $0.placements.isEmpty } }.map { gameState($0.puzzle, $0.solution) }
    }

    /// A board where no known technique applies yet.
    private static func stuckState() -> GameState? {
        guard let (puzzle, solution) = generated({ !$0.isSolved }) else { return nil }
        let stuck = LogicalSolver().solve(SolverBoard(values: puzzle)).board
        var state = gameState(puzzle, solution)
        for index in state.cells.indices where state.cells[index].value == nil {
            let value = stuck.values[state.cells[index].index]
            if value != 0 { state.cells[index].value = value }
            // Keep the solver's eliminations as notes, so it is stuck in the game too.
            else { state.cells[index].candidates = Set(SolverBoard.digits(in: stuck.candidates[state.cells[index].index])) }
        }
        return state
    }
}
