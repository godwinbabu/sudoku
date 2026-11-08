import XCTest
@testable import PureSudoku

/// Graduated hints (CODESPEC 6.3.1).
@MainActor
final class HintLadderTests: XCTestCase {
    private let solution = Array(TestData.puzzle.solutionGrid).map { Int(String($0))! }

    private func makeViewModel(state: GameState = TestData.newGameState(), autoRemove: Bool = true,
                               mistakes: MistakeMode = .immediate) -> GameViewModel {
        var settings = Settings()
        settings.tidyNotes = autoRemove
        settings.mistakes = mistakes
        return GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
    }

    private func values(_ viewModel: GameViewModel) -> [Int?] { viewModel.state.cells.map(\.value) }

    private func emptyCell(_ viewModel: GameViewModel, after skip: Int = 0) -> SudokuCell {
        viewModel.state.cells.filter { $0.value == nil }[skip]
    }

    // MARK: - Mistakes first

    func testWrongDigitIsTheFirstHint() {
        let viewModel = makeViewModel()
        let cell = emptyCell(viewModel)
        let wrong = solution[cell.index] % 9 + 1
        viewModel.select(cell: cell)
        viewModel.setDigit(wrong) // wrong on purpose
        let before = values(viewModel)

        viewModel.requestHint()
        let clash = SolverBoard.peers[cell.index].first { peer in viewModel.state.cells.first { $0.index == peer }?.value == wrong }
        XCTAssertEqual(viewModel.hint?.content, .mistake(cell: cell.index, kind: .wrongDigit(wrong, clash: clash)))
        XCTAssertEqual(viewModel.hint?.level, 1)
        XCTAssertEqual(viewModel.hint?.stepLabel, "Where to look")
        XCTAssertEqual(viewModel.hintHighlight.areaCells, Set(House(kind: .box, index: SolverBoard.box(of: cell.index)).cells))
        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.stepLabel, "Mistake")
        XCTAssertEqual(viewModel.hintHighlight.targetCells, [cell.index])
        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.actionLabel, "Clear it")
        XCTAssertEqual(values(viewModel), before, "the steps never change the board")

        viewModel.applyHint()
        XCTAssertNil(viewModel.state.cells.first { $0.index == cell.index }?.value, "Clear it empties the cell")
        XCTAssertEqual(viewModel.selectedCellID, cell.id)
        XCTAssertFalse(viewModel.state.assisted, "clearing a mistake is not assisted")
    }

    func testMistakeTextNamesTheDigitAndCell() {
        var session = HintSession(content: .mistake(cell: 20, kind: .wrongDigit(7)), level: 2)
        XCTAssertEqual(session.text(.plain), "The 7 in row 3, column 3 can't be right.")
        session.next()
        XCTAssertTrue(session.text(.plain).hasPrefix("Nothing on the board clashes"), "step 3 explains, not repeats")

        // A visible clash: name the cell it repeats, ring it, and say which house.
        var clash = HintSession(content: .mistake(cell: 20, kind: .wrongDigit(7, clash: 24)), level: 2)
        XCTAssertEqual(clash.text(.plain), "The 7 in row 3, column 3 repeats the 7 in row 3, column 7.")
        XCTAssertEqual(clash.highlight.evidenceCells, [24])
        XCTAssertTrue(clash.highlight.areaCells.isSuperset(of: House(kind: .row, index: 2).cells))
        clash.next()
        XCTAssertEqual(clash.text(.grid), "Each digit goes once in a row, column and box. R3 already has a 7 in R3C7, so this one has to go.")
        XCTAssertEqual(HintSession(content: .mistake(cell: 20, kind: .wrongDigit(7))).text(.grid), "Something in B1 doesn't fit.")
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
        for _ in 0..<2 { viewModel.hintNext() }
        viewModel.applyHint()
        XCTAssertTrue(viewModel.state.cells.first { $0.index == other.index }!.candidates.isEmpty, "Clear it drops the notes")
    }

    // MARK: - Steps 1-3

    func testEachStepAdvancesOneLevelAndAddsItsMarks() throws {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        let step = try XCTUnwrap(viewModel.hint?.step)
        let target = try XCTUnwrap(step.target, "the first hint on a fresh easy board is a single")

        XCTAssertEqual(viewModel.hint?.level, 1)
        XCTAssertEqual(viewModel.hint?.stepLabel, "Where to look")
        XCTAssertEqual(viewModel.hint?.actionLabel, "Which technique?")
        XCTAssertNil(viewModel.hint?.title)
        XCTAssertFalse(viewModel.hintHighlight.areaCells.isEmpty, "step 1 spotlights the focus")
        XCTAssertTrue(viewModel.hintHighlight.ghostDigits.isEmpty)
        XCTAssertNil(viewModel.hint?.lessonTechnique)

        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.level, 2)
        XCTAssertEqual(viewModel.hint?.stepLabel, "Technique")
        XCTAssertEqual(viewModel.hint?.title, step.technique.displayName)
        XCTAssertEqual(viewModel.hint?.tierLabel, "Beginner")
        XCTAssertEqual(viewModel.hint?.text(.plain), step.technique.definition)
        XCTAssertEqual(viewModel.hint?.actionLabel, "Show me why")
        XCTAssertEqual(viewModel.hint?.lessonTechnique, step.technique)
        XCTAssertTrue(viewModel.hintHighlight.ghostDigits.isEmpty, "a single's answer waits for step 3")

        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.level, 3)
        XCTAssertEqual(viewModel.hint?.stepLabel, "Why")
        XCTAssertEqual(viewModel.hint?.actionLabel, "Place \(target.digit) · assisted")
        XCTAssertEqual(viewModel.hintHighlight.ghostDigits, [target.cell: target.digit])
        XCTAssertFalse(viewModel.hint?.canGoNext ?? true)

        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.level, 3, "step 3 is the last")
        XCTAssertEqual(values(viewModel), before)
        XCTAssertFalse(viewModel.state.assisted, "steps 1-3 are free")
    }

    func testPlacingFromAHintSetsAssistedAndIsOneUndo() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        viewModel.hintNext()
        viewModel.hintNext()
        viewModel.applyHint()
        XCTAssertNil(viewModel.hint)
        XCTAssertNotEqual(values(viewModel), before)
        XCTAssertTrue(viewModel.state.assisted)
        XCTAssertEqual(viewModel.state.hints, 1)
        XCTAssertEqual(viewModel.state.hintLog.last, HintLogEntry(technique: viewModel.state.hintLog.last!.technique, deepestRung: 3, applied: true))

        viewModel.undo()
        XCTAssertEqual(values(viewModel), before)
        XCTAssertTrue(viewModel.state.assisted, "Undo never clears assisted")
    }

    func testHintToolStepsThenPlaces() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.hintTool()
        XCTAssertEqual(viewModel.hint?.level, 1)
        viewModel.hintTool()
        viewModel.hintTool()
        XCTAssertEqual(viewModel.hint?.level, 3)
        viewModel.hintTool()
        XCTAssertNil(viewModel.hint)
        XCTAssertNotEqual(values(viewModel), before)
        XCTAssertTrue(viewModel.state.assisted)
    }

    /// The card hides the selection, so the keypad must not type into a cell the player can't see.
    func testKeypadDoesNotTypeIntoAHiddenSelection() {
        let viewModel = makeViewModel()
        let cell = emptyCell(viewModel)
        viewModel.select(cell: cell)
        viewModel.requestHint()
        XCTAssertNil(viewModel.selectedCellID)
        let before = values(viewModel)
        viewModel.setDigit(solution[cell.index])
        XCTAssertEqual(values(viewModel), before)
        XCTAssertNotNil(viewModel.hint, "typing with nothing selected leaves the card open")
    }

    func testTappingACellClosesTheHint() {
        let viewModel = makeViewModel()
        viewModel.requestHint()
        viewModel.select(cell: emptyCell(viewModel))
        XCTAssertNil(viewModel.hint)
    }

    func testEntriesConflictCardOffersUndoOnly() {
        let session = HintSession(content: .mistake(cell: nil, kind: .entriesConflict))
        XCTAssertEqual(session.level, 3)
        XCTAssertFalse(session.canGoNext)
        XCTAssertFalse(session.canApply)
        XCTAssertTrue(session.offersUndo)
        XCTAssertNil(session.actionLabel, "the card shows Undo instead")
        let noStep = HintSession(content: .noStep(cell: nil, digit: nil))
        XCTAssertEqual(noStep.level, 3)
        XCTAssertFalse(noStep.canApply)
        XCTAssertFalse(noStep.offersUndo)
        XCTAssertNil(noStep.actionLabel)
    }

    /// "Next step" on the clashing-entries card runs its Undo, like the card's own button.
    func testHintToolUndoesOnTheEntriesConflictCard() throws {
        let givens = String(TestData.puzzle.solutionGrid.prefix(9)) + String(repeating: "0", count: 72)
        let stored = try XCTUnwrap(SudokuGeneratorService().solve(initialGrid: givens))
        let puzzle = SudokuPuzzle(id: "import", difficulty: .hard, initialGrid: givens, solutionGrid: stored, source: .imported)
        let viewModel = makeViewModel(state: GameState.newGame(for: puzzle))
        let below = viewModel.state.cells.first { $0.index == 9 }!
        viewModel.select(cell: below)
        viewModel.setDigit(Int(String(givens.first!))!) // same digit as the given above it: no solution fits
        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.content, .mistake(cell: nil, kind: .entriesConflict))
        viewModel.hintTool()
        XCTAssertNil(viewModel.hint)
        XCTAssertNil(viewModel.state.cells.first { $0.index == 9 }?.value, "Next step ran the card's Undo")
    }

    func testApplyBeforeStepThreeDoesNothing() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        viewModel.hintNext()
        viewModel.applyHint()
        XCTAssertEqual(values(viewModel), before)
        XCTAssertFalse(viewModel.state.assisted)
    }

    func testSameBoardGivesTheSameHint() {
        let viewModel = makeViewModel()
        viewModel.requestHint()
        let first = viewModel.hint?.step
        viewModel.endHint()
        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.step, first)
    }

    func testCloseLeavesTheBoardAndLogsTheStep() {
        let viewModel = makeViewModel()
        let before = values(viewModel)
        viewModel.requestHint()
        viewModel.hintNext()
        viewModel.endHint()
        XCTAssertNil(viewModel.hint)
        XCTAssertEqual(values(viewModel), before)
        XCTAssertEqual(viewModel.state.hintLog.last?.deepestRung, 2)
        XCTAssertEqual(viewModel.state.hintLog.last?.applied, false)
        XCTAssertEqual(viewModel.state.hints, 1)
    }

    /// Eliminations in cells without notes must be kept (as notes), so the next hint moves on.
    func testAppliedEliminationIsKeptAndTheNextHintMovesOn() throws {
        let state = try XCTUnwrap(Self.stateNeedingAnElimination())
        let viewModel = makeViewModel(state: state)
        for _ in 0..<120 {
            viewModel.requestHint()
            guard let step = viewModel.hint?.step else { return XCTFail("solver stopped before an elimination") }
            for _ in 0..<2 { viewModel.hintNext() }
            if step.placements.isEmpty {
                XCTAssertTrue(viewModel.hint?.actionLabel?.hasSuffix("· assisted") ?? false)
                let struck = viewModel.hintHighlight.struckDigits
                for elimination in step.eliminations { XCTAssertEqual(struck[elimination.cell]?.contains(elimination.digit), true) }
            }
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

    func testNoStepPlacesTheAnswerAsAssisted() throws {
        let state = try XCTUnwrap(Self.stuckState())
        let viewModel = makeViewModel(state: state)
        viewModel.requestHint()
        guard case .noStep(let cell?, let digit?) = viewModel.hint?.content else { return XCTFail("expected no-step hint") }
        XCTAssertEqual(viewModel.hint?.level, 3)
        XCTAssertEqual(viewModel.hint?.actionLabel, "Place \(digit) · assisted")
        viewModel.applyHint()
        XCTAssertEqual(viewModel.state.cells.first { $0.index == cell }?.value, digit)
        XCTAssertTrue(viewModel.state.assisted)
        XCTAssertFalse(viewModel.state.usedReveal, "a hint is not a reveal")
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
        let viewModel = makeViewModel()
        viewModel.requestHint()
        for _ in 0..<2 { viewModel.hintNext() }
        let cell = viewModel.state.cells.first { $0.value == nil && !(viewModel.hint?.step?.placements.map(\.cell).contains($0.index) ?? false) }!
        viewModel.select(cell: cell)
        viewModel.setDigit(solution[cell.index])
        XCTAssertNil(viewModel.hint)
        let after = values(viewModel)
        viewModel.applyHint()
        XCTAssertEqual(values(viewModel), after, "a closed hint cannot be applied")
    }

}

// MARK: - Hint text

extension HintLadderTests {

    func testHiddenSingleTextAndEvidence() throws {
        let viewModel = makeViewModel()
        viewModel.requestHint()
        guard case let .step(step, board)? = viewModel.hint?.content,
              [.hiddenSingleBox, .hiddenSingleLine].contains(step.technique),
              let target = step.target, let house = step.houses.first?.house else { return }
        XCTAssertEqual(step.nudge(.plain), "Look at \(CellNotation.plain.house(house)). Where can \(target.digit) go?")
        XCTAssertTrue(step.why(.grid, on: board).hasSuffix("So \(target.digit) can only go in \(CellNotation.grid.cell(target.cell))."))
        let evidence = step.evidence(on: board)
        XCTAssertFalse(evidence.isEmpty)
        XCTAssertTrue(evidence.allSatisfy { board.values[$0] == target.digit }, "evidence cells hold the digit")
        for _ in 0..<2 { viewModel.hintNext() }
        XCTAssertEqual(viewModel.hintHighlight.evidenceCells, evidence)
    }

    /// Hints show singles box, then row, then column, the way people scan (engine.js order).
    func testHintSinglesScanBoxesThenRowsThenColumns() {
        var lineSteps = 0
        for entry in BundledPuzzles.puzzles(for: .hard).prefix(5) {
            var board = SolverBoard(values: entry.initialGrid.map { Int(String($0)) ?? 0 })
            while let step = LogicalSolver().nextHintStep(board) {
                if step.technique == .hiddenSingleLine {
                    lineSteps += 1
                    XCTAssertTrue(SinglesDetector.hiddenSingles(board, in: House.boxes, technique: .hiddenSingleBox).isEmpty)
                    let rows = SinglesDetector.hiddenSingles(board, in: House.rows, technique: .hiddenSingleLine)
                    XCTAssertTrue(rows.isEmpty || step.houses.first?.house.kind == .row, "a row single comes before a column single")
                }
                board.apply(step)
            }
        }
        XCTAssertGreaterThan(lineSteps, 0, "the fixtures exercise line singles")
    }

    /// The hint order must not hide column singles from mastery or grading.
    func testColumnSinglesStillEarnLearningCredit() throws {
        let entry = BundledPuzzles.puzzles(for: .easy)[0]
        let board = SolverBoard(values: entry.initialGrid.map { Int(String($0)) ?? 0 })
        let digit = try XCTUnwrap(Int(String(entry.solutionGrid.first!)))
        XCTAssertEqual(digit, 2)
        XCTAssertEqual(MasteryJudge.technique(for: .placed(cell: 0, digit: digit), on: board), .hiddenSingleLine)
        let columnSingles = LogicalSolver.steps(for: .hiddenSingleLine, on: board).filter { $0.houses.first?.house.kind == .column }
        XCTAssertTrue(columnSingles.contains { $0.placements == [CellDigit(cell: 0, digit: 2)] })
    }

    func testAnEightTakesAn() {
        XCTAssertEqual(CellNotation.withArticle(8), "an 8")
        XCTAssertEqual(CellNotation.withArticle(5), "a 5")
    }

    func testNotationInBothModes() {
        XCTAssertEqual(CellNotation.plain.cell(37), "row 5, column 2")
        XCTAssertEqual(CellNotation.grid.cell(37), "R5C2")
        XCTAssertEqual(CellNotation.plain.box(3), "box 4")
        XCTAssertEqual(CellNotation.grid.box(3), "B4")
        XCTAssertEqual(CellNotation.plain.house(House(kind: .row, index: 4)), "row 5")
        XCTAssertEqual(CellNotation.grid.house(House(kind: .row, index: 4)), "R5")
        XCTAssertEqual(CellNotation.plain.house(House(kind: .column, index: 1)), "column 2")
        XCTAssertEqual(CellNotation.grid.house(House(kind: .column, index: 1)), "C2")
    }

    func testHintSentencesInBothModes() {
        // Box 4 (0-based 3) needs an 8 at row 5, column 2: every other empty cell sees an 8.
        let step = TechniqueStep(technique: .hiddenSingleBox, digits: [8], houses: [.init(house: House(kind: .box, index: 3), role: .base)],
                                 cells: [.init(cell: 37, role: .defining)], placements: [CellDigit(cell: 37, digit: 8)])
        var values = Array(repeating: 0, count: 81)
        values[32] = 8 // row 4, column 6: covers row 4 of box 4
        values[52] = 8 // row 6, column 8: covers row 6
        values[54] = 8 // row 7, column 1: covers column 1
        values[11] = 8 // row 2, column 3: covers column 3
        let board = SolverBoard(values: values)
        XCTAssertEqual(step.nudge(.plain), "Look at box 4. Where can 8 go?")
        XCTAssertEqual(step.nudge(.grid), "Look at B4. Where can 8 go?")
        XCTAssertEqual(step.why(.plain, on: board),
                       "Every other empty cell in box 4 already sees an 8. So 8 can only go in row 5, column 2.")
        XCTAssertEqual(step.why(.grid, on: board), "Every other empty cell in B4 already sees an 8. So 8 can only go in R5C2.")
        XCTAssertEqual(step.evidence(on: board), [11, 32, 52, 54])
    }

    /// On a 390 pt wide phone (336 pt of text), every step-2 definition fits the card at full size,
    /// and step 3 of the Beginner and Intermediate intersection techniques fits without scrolling.
    /// Longer step-3 texts (subsets, wings, uniqueness) scroll inside the card.
    func testHintTextsFitTheCard() throws {
        let unscrolled: Set<Technique> = [.fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle, .pointing, .claiming]
        for technique in Lesson.techniques {
            guard let example = Lesson.example(for: technique) else { continue }
            let session = { HintSession(content: .step(example.step, board: example.board), level: $0) }
            let definition = session(2).text(.plain)
            XCTAssertTrue(Self.fits(definition, size: HintCardView.bodySize), "step 2 of \(technique): \(definition)")
            let why = session(3).text(.plain)
            if unscrolled.contains(technique) {
                XCTAssertTrue(Self.fits(why, size: HintCardView.smallBodySize), "step 3 of \(technique): \(why)")
            }
        }
    }

    private static func fits(_ text: String, size: CGFloat) -> Bool {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = HintCardView.lineSpacing
        let attributed = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: size), .paragraphStyle: style])
        let box = CGSize(width: 336, height: CGFloat.greatestFiniteMagnitude)
        return attributed.boundingRect(with: box, options: [.usesLineFragmentOrigin], context: nil).height <= HintCardView.bodyHeight
    }

    /// Step 3 hides multi-cell removals from the visible text; VoiceOver must still hear every cell.
    func testStepThreeAccessibilityNamesEveryRemovedCell() throws {
        let multiCell = Lesson.techniques.compactMap { Lesson.example(for: $0) }.first { Set($0.step.eliminations.map(\.cell)).count > 1 }
        let lesson = try XCTUnwrap(multiCell, "a lesson removes digits from several cells")
        let session = HintSession(content: .step(lesson.step, board: lesson.board), level: 3)
        for names in CellNotation.allCases {
            let spoken = session.accessibilityText(names)
            for elimination in lesson.step.eliminations {
                XCTAssertTrue(spoken.contains(names.cell(elimination.cell)), "\(names.cell(elimination.cell)) missing: \(spoken)")
                XCTAssertTrue(spoken.contains("Remove \(elimination.digit) from"), spoken)
            }
            XCTAssertTrue(spoken.hasPrefix(session.text(names)), "the visible reason comes first")
        }
        XCTAssertEqual(HintSession(content: .step(lesson.step, board: lesson.board), level: 2).accessibilityText(.plain),
                       lesson.step.technique.definition, "other steps read their visible text")
    }

}

// MARK: - Mistakes: Never, stats and saved data

extension HintLadderTests {

    func testNeverModeMarksNoErrorsButTheHintStillFindsThem() {
        let viewModel = makeViewModel(mistakes: .never)
        let cell = emptyCell(viewModel)
        let rowDigit = viewModel.state.cells.first { $0.row == cell.row && $0.value != nil }!.value!
        viewModel.select(cell: cell)
        viewModel.setDigit(rowDigit) // clashes with its row
        viewModel.checkPuzzle()
        viewModel.checkCell()
        XCTAssertFalse(viewModel.state.cells.contains { $0.isError }, "Never marks nothing, even after Check")
        viewModel.requestHint()
        XCTAssertTrue(viewModel.hint?.isMistake ?? false, "the hint still checks for mistakes first")
    }

    func testSwitchingToNeverClearsCheckedMarks() {
        let viewModel = makeViewModel(mistakes: .onCheck)
        let cell = emptyCell(viewModel)
        viewModel.select(cell: cell)
        viewModel.setDigit(solution[cell.index] % 9 + 1)
        viewModel.checkPuzzle()
        XCTAssertTrue(viewModel.state.cells.contains { $0.isError })
        var settings = Settings()
        settings.mistakes = .never
        viewModel.apply(settings: settings)
        XCTAssertFalse(viewModel.state.cells.contains { $0.isError })
    }

    func testNeverIsOffered() {
        XCTAssertTrue(MistakeMode.allCases.contains(.never))
    }

    // MARK: - Stats and saved data

    func testAssistedSolveKeepsTheStreakButSkipsBestTime() {
        var stats = Stats()
        let calendar = Calendar(identifier: .gregorian)
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        stats.recordCompletion(for: .easy, time: 300, usedReveal: false, date: day1, calendar: calendar)
        stats.recordCompletion(for: .easy, time: 100, usedReveal: false, assisted: true, date: day2, calendar: calendar)
        XCTAssertEqual(stats.bestTime(for: .easy), 300, "an assisted solve sets no best time")
        XCTAssertEqual(stats.solvedCount(for: .easy), 2)
        XCTAssertEqual(stats.totalTimeSeconds, 400)
        XCTAssertEqual(stats.streakDays, 2, "an assisted solve keeps the streak")
    }

    func testRevealedSolveCountsForNothing() {
        var stats = Stats()
        stats.recordCompletion(for: .easy, time: 100, usedReveal: true, assisted: true)
        XCTAssertEqual(stats, Stats())
    }

    func testOldSavesLoadWithDefaults() throws {
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TestData.newGameState())) as? [String: Any])
        state.removeValue(forKey: "assisted")
        state.removeValue(forKey: "hintLog")
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: state))
        XCTAssertFalse(decoded.assisted)
        XCTAssertTrue(decoded.hintLog.isEmpty)
        XCTAssertEqual(decoded.hints, 0)

        state["usedHint"] = true // written before `assisted`
        let migrated = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: state))
        XCTAssertTrue(migrated.assisted)
    }

    func testCellNameStyleMigratesToNotation() throws {
        var settings = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any])
        settings.removeValue(forKey: "notation")
        let fresh = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertEqual(fresh.notation, .plain)
        settings["cellNameStyle"] = "short"
        let short = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertEqual(short.notation, .grid)
        settings["cellNameStyle"] = "long"
        let long = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertEqual(long.notation, .plain)
        settings["notation"] = "grid"
        let both = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertEqual(both.notation, .grid, "the new key wins")
    }

    func testAskBeforeHintResultIsIgnored() throws {
        var settings = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any])
        settings["askBeforeHintResult"] = false // written by the previous version
        settings["autoFillHints"] = true // written by an older one
        let loaded = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: settings))
        XCTAssertEqual(loaded, Settings())
        let written = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(loaded)) as? [String: Any])
        XCTAssertNil(written["askBeforeHintResult"], "the old key is not written back")
        XCTAssertNil(written["cellNameStyle"])
    }

}

// MARK: - Fixtures

extension HintLadderTests {

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

    // MARK: - Check feedback (QA #49)

    func testCheckSaysWhatItFound() {
        let viewModel = makeViewModel(mistakes: .onCheck)
        viewModel.checkPuzzle()
        XCTAssertEqual(viewModel.checkMessage, "No mistakes so far.")
        let cell = emptyCell(viewModel)
        viewModel.select(cell: cell)
        XCTAssertNil(viewModel.checkMessage, "the next move clears it")
        viewModel.setDigit(solution[cell.index] % 9 + 1)
        viewModel.checkPuzzle()
        XCTAssertEqual(viewModel.checkMessage, "1 wrong digit, marked with a bar.")
    }
}
