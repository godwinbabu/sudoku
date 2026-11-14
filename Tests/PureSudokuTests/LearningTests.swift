import XCTest
@testable import PureSudoku

/// Mastery, fading and lessons (CODESPEC 13.4, 13.5, 6.3.1).
@MainActor
final class LearningTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Mastery rule

    // swiftlint:disable:next inclusive_language
    func testMasteredAtTenCredits() {
        var progress = TechniqueProgress()
        XCTAssertEqual(progress.level, .new)
        for move in 0..<9 { progress.recordFound(puzzleID: "a", at: start.addingTimeInterval(Double(move))) }
        XCTAssertEqual(progress.credits, 9)
        XCTAssertEqual(progress.level, .learning, "nine is not enough")
        progress.recordFound(puzzleID: "a", at: start.addingTimeInterval(10))
        XCTAssertEqual(progress.level, .mastered, "every credited move counts, even in one puzzle")
        XCTAssertEqual(progress.foundUnaided.count, 1, "strength still grows once per puzzle")
    }

    /// Saves from before credits: one credit per puzzle found, and mastery earned the old way stays.
    func testOldProgressDecodes() throws {
        let old = #"{"foundUnaided":[{"puzzleID":"a","day":"2026-01-01"}],"hintsSeen":2,"strength":0.3}"#
        let one = try JSONDecoder().decode(TechniqueProgress.self, from: Data(old.utf8))
        XCTAssertEqual(one.credits, 1)
        XCTAssertEqual(one.hintsSeen, 2)
        XCTAssertEqual(one.level, .learning)
        let found = (1...3).map { #"{"puzzleID":"p\#($0)","day":"2026-01-0\#($0)"}"# }.joined(separator: ",")
        let threeDays = #"{"foundUnaided":[\#(found)],"hintsSeen":0,"strength":1}"#
        let earned = try JSONDecoder().decode(TechniqueProgress.self, from: Data(threeDays.utf8))
        XCTAssertEqual(earned.level, .mastered, "mastery under the old rule is kept")
        XCTAssertEqual(try JSONDecoder().decode(TechniqueProgress.self, from: JSONEncoder().encode(one)), one, "round trip")
        // Fields from earlier builds of this phase are ignored; a ledger without fields is empty.
        let extra = #"{"foundUnaided":[],"hintsSeen":0,"strength":0,"credits":2,"creditedMoves":["p|placed|0|1"]}"#
        XCTAssertEqual(try JSONDecoder().decode(TechniqueProgress.self, from: Data(extra.utf8)).credits, 2)
        XCTAssertEqual(try JSONDecoder().decode(LearningLedger.self, from: Data("{}".utf8)), LearningLedger())
        var game = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TestData.newGameState())) as? [String: Any])
        game["hintedCells"] = [["cell": 0, "digit": 1]]
        XCTAssertNoThrow(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: game)))
    }

    func testSeeingAHintMakesATechniqueLearningAndHalvesStrength() {
        var progress = TechniqueProgress()
        progress.recordFound(puzzleID: "a", at: start)
        let found = progress.strength(at: start)
        progress.recordHint(at: start)
        XCTAssertEqual(progress.strength(at: start), found * 0.5, accuracy: 1e-9)
        var hinted = TechniqueProgress()
        hinted.recordHint(at: start)
        XCTAssertEqual(hinted.level, .learning)
    }

    func testStrengthDecaysWithAHalfLifeThatGrowsWithPractice() {
        var once = TechniqueProgress()
        once.recordFound(puzzleID: "a", at: start)
        let halfLife = 3.0 * 2 // one find: 6 days
        XCTAssertEqual(once.strength(at: start.addingTimeInterval(halfLife * day)), once.strength(at: start) / 2, accuracy: 1e-9)
        var often = once
        for (index, id) in ["b", "c", "d"].enumerated() { often.recordFound(puzzleID: id, at: start.addingTimeInterval(Double(index + 1) * 60)) }
        XCTAssertGreaterThan(often.strength(at: start.addingTimeInterval(20 * day)), once.strength(at: start.addingTimeInterval(20 * day)))
    }

    // MARK: - Which technique a move shows

    /// Issue #9: a naked single must be creditable even when the solver's first step is elsewhere.
    func testANakedSingleMoveIsCreditedAsNakedSingle() throws {
        var rng = SeededRandomNumberGenerator(seed: 11)
        for _ in 0..<60 {
            var board = SolverBoard(values: makePuzzle(using: &rng).map { ($0 ?? -1) + 1 })
            let solver = LogicalSolver()
            while let step = solver.nextStep(board) {
                let singlesOnly = LogicalSolver.steps(for: .nakedSingle, on: board).flatMap(\.placements)
                let hidden = (LogicalSolver.steps(for: .hiddenSingleBox, on: board) + LogicalSolver.steps(for: .hiddenSingleLine, on: board)
                    + LogicalSolver.steps(for: .fullHouse, on: board)).flatMap(\.placements)
                if let only = singlesOnly.first(where: { !hidden.contains($0) }) {
                    let credited = MasteryJudge.technique(for: .placed(cell: only.cell, digit: only.digit), on: board)
                    XCTAssertEqual(credited, .nakedSingle)
                    XCTAssertNotEqual(step.placements.first, only, "the solver's own first step was something else")
                    return
                }
                board.apply(step)
            }
        }
        XCTFail("no board with a naked single that no other single explains")
    }

    func testAWrongOrRandomMoveEarnsNothing() {
        let board = SolverBoard(grid: TestData.puzzle.initialGrid)!
        let empty = board.values.firstIndex(of: 0)!
        let notACandidate = (1...9).first { !board.has($0, at: empty) }!
        XCTAssertNil(MasteryJudge.technique(for: .placed(cell: empty, digit: notACandidate), on: board))
    }

    // MARK: - Game view model wiring

    private func makeViewModel() -> (GameViewModel, () -> [Technique]) {
        let viewModel = GameViewModel(state: TestData.newGameState(), settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider())
        var found: [Technique] = []
        viewModel.onTechniqueFound = { technique, _, _ in found.append(technique) }
        return (viewModel, { found })
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    /// A manual placement credits the technique the engine would use for that cell and digit, once.
    func testFindingAStepWithoutAHintIsCredited() async throws {
        let (viewModel, found) = makeViewModel()
        let board = SolverBoard(cells: viewModel.state.cells)
        let step = try XCTUnwrap(LogicalSolver().nextStep(board))
        let placement = try XCTUnwrap(step.placements.first)
        let expected = MasteryJudge.technique(for: .placed(cell: placement.cell, digit: placement.digit), on: board)
        viewModel.select(cell: viewModel.state.cells.first { $0.index == placement.cell }!)
        viewModel.setDigit(placement.digit)
        await settle(found, count: 1)
        XCTAssertEqual(found(), [try XCTUnwrap(expected)])
        // The ledger credits a move once per puzzle, under any technique.
        var ledger = LearningLedger()
        let move = MasteryJudge.Move.placed(cell: placement.cell, digit: placement.digit)
        XCTAssertTrue(ledger.credit(move, technique: .hiddenSingleBox, puzzle: "test"))
        XCTAssertFalse(ledger.credit(move, technique: .hiddenSingleBox, puzzle: "test"), "Undo or Erase and replay")
        XCTAssertFalse(ledger.credit(move, technique: .fullHouse, puzzle: "test"), "the same move under another technique")
        XCTAssertTrue(ledger.credit(move, technique: .fullHouse, puzzle: "other"), "another puzzle")
        XCTAssertEqual(try JSONDecoder().decode(LearningLedger.self, from: JSONEncoder().encode(ledger)), ledger, "saved")
    }

    /// Everything the hint card does (Place · assisted, Apply/Remove · assisted) earns no credit.
    func testMovesFromTheHintCardEarnNoCredit() async throws {
        let (controller, _) = makeTestController()
        let entry = try XCTUnwrap(BundledPuzzles.puzzles(for: .medium).first)
        let viewModel = controller.makePracticeGameViewModel(entry, number: 1)
        var found: [Technique] = []
        viewModel.onTechniqueFound = { technique, _, _ in found.append(technique) }
        var placed = 0, removed = 0
        while placed == 0 || removed == 0, !viewModel.state.isCompleted, placed + removed < 120 {
            viewModel.requestHint()
            let step = try XCTUnwrap(viewModel.hint?.step, "a medium puzzle needs no mistake or reveal hint")
            if step.placements.isEmpty { removed += 1 } else { placed += 1 }
            viewModel.hintNext()
            viewModel.hintNext()
            viewModel.applyHint()
        }
        XCTAssertGreaterThan(placed, 0)
        XCTAssertGreaterThan(removed, 0, "an elimination was applied too")
        await settle({ found }, count: 1)
        XCTAssertTrue(found.isEmpty)
        XCTAssertTrue(viewModel.state.assisted)
    }

    /// Places the solver's next single (a correct move nobody hinted) as a positive control.
    private func placeNextSingle(_ viewModel: GameViewModel) throws {
        let step = try XCTUnwrap(LogicalSolver().nextStep(SolverBoard(cells: viewModel.state.cells)))
        let placement = try XCTUnwrap(step.placements.first)
        viewModel.select(cell: viewModel.state.cells.first { $0.index == placement.cell }!)
        viewModel.setDigit(placement.digit)
    }

    /// Waits until `count` credits arrive, then a little longer to catch any extra one.
    private func settle(_ found: () -> [Technique], count: Int) async {
        await waitFor { found().count >= count }
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    /// TestData's puzzle as a practice entry, played through a controller so the ledger applies.
    private func makeLearningGame() -> (controller: AppController, game: GameViewModel) {
        let (controller, _) = makeTestController()
        let p = TestData.puzzle
        let entry = BundledPuzzles.Entry(difficulty: .easy, initialGrid: p.initialGrid, solutionGrid: p.solutionGrid,
                                         score: 0, techniques: [])
        return (controller, controller.makePracticeGameViewModel(entry, number: 1))
    }

    private func pause() async { try? await Task.sleep(nanoseconds: 400_000_000) }

    func testAHintedTechniqueEarnsNoCreditForTheRestOfThePuzzle() async throws {
        let (controller, viewModel) = makeLearningGame()
        viewModel.requestHint()
        let placement = try XCTUnwrap(viewModel.hint?.step?.placements.first)
        let hinted = try XCTUnwrap(viewModel.hint?.step?.technique)
        viewModel.endHint()
        let target = viewModel.state.cells.first { $0.index == placement.cell }!
        // A wrong digit, Undo, then the hinted move: none of this may earn credit.
        viewModel.select(cell: target)
        viewModel.setDigit(placement.digit % 9 + 1)
        viewModel.undo()
        viewModel.select(cell: target)
        viewModel.setDigit(placement.digit)
        await pause()
        XCTAssertTrue(controller.learningLedger.credited.isEmpty, "the cell and digit the hint showed earn nothing, by any technique")
        // Positive control: an unhinted single of another kind is still credited. Pick one the judge
        // names as another lesson, so one move does it (no 300 ms waits per hinted single).
        let solution = Array(TestData.puzzle.solutionGrid).map { Int(String($0))! }
        let board = SolverBoard(cells: viewModel.state.cells)
        let lesson: (Technique) -> Technique = { $0 == .hiddenSingleLine ? .hiddenSingleBox : $0 }
        let other = try XCTUnwrap((0..<81).first { cell in
            guard board.values[cell] == 0,
                  let found = MasteryJudge.technique(for: .placed(cell: cell, digit: solution[cell]), on: board) else { return false }
            return lesson(found) != lesson(hinted)
        })
        viewModel.select(cell: viewModel.state.cells.first { $0.index == other }!)
        viewModel.setDigit(solution[other])
        await waitFor { !controller.learningLedger.credited.isEmpty }
        XCTAssertFalse(controller.learningLedger.credited.isEmpty, "crediting works at all")
        XCTAssertEqual(controller.progress(for: hinted).credits, 0, "the hinted technique stays uncredited in this puzzle")
    }

    func testAWrongButPossibleDigitEarnsNothing() async throws {
        let (viewModel, found) = makeViewModel()
        let board = SolverBoard(cells: viewModel.state.cells)
        let solution = Array(TestData.puzzle.solutionGrid).map { Int(String($0))! }
        let cell = try XCTUnwrap((0..<81).first { board.values[$0] == 0 && board.candidates[$0].nonzeroBitCount > 1 })
        let wrong = try XCTUnwrap(SolverBoard.digits(in: board.candidates[cell]).first { $0 != solution[cell] })
        // A single taken before the mistake, so its digit is right for the stored solution and only
        // the mistake can stop its credit.
        let single = try XCTUnwrap(LogicalSolver.steps(for: .hiddenSingleBox, on: board).flatMap(\.placements)
            .first { $0.cell != cell && solution[$0.cell] == $0.digit })
        XCTAssertNotNil(MasteryJudge.technique(for: .placed(cell: single.cell, digit: single.digit), on: board),
                        "earns credit on a clean board")
        viewModel.select(cell: viewModel.state.cells.first { $0.index == cell }!)
        viewModel.setDigit(wrong)
        // Board now has a mistake, so even a correct single elsewhere earns nothing.
        viewModel.select(cell: viewModel.state.cells.first { $0.index == single.cell }!)
        viewModel.setDigit(single.digit)
        await settle(found, count: 0)
        XCTAssertTrue(found().isEmpty)
    }

    func testRemovingANoteThatPointingExplainsIsCredited() {
        // Box 1: 5 only in r1c1, r1c2 → pointing removes 5 from r1c4.
        var candidates = Array(repeating: SolverBoard.allDigits, count: 81)
        for cell in [2, 9, 10, 11, 18, 19, 20] { candidates[cell] &= ~SolverBoard.bit(5) }
        let board = SolverBoard(values: Array(repeating: 0, count: 81), candidates: candidates)
        XCTAssertEqual(MasteryJudge.technique(for: .removedCandidate(cell: 3, digit: 5), on: board), .pointing)
        XCTAssertNil(MasteryJudge.technique(for: .placed(cell: 3, digit: 5), on: board), "placements only match singles")
    }

    func testReplayingAMoveDoesNotFarmStrength() {
        var progress = TechniqueProgress()
        progress.recordFound(puzzleID: "a", at: start)
        let once = progress.strength(at: start)
        progress.recordFound(puzzleID: "a", at: start.addingTimeInterval(10))
        progress.recordFound(puzzleID: "a", at: start.addingTimeInterval(20))
        XCTAssertEqual(progress.strength(at: start), once, accuracy: 1e-9)
    }

    func testPracticeGamesLeaveStatsAndSavedGamesAlone() {
        let (controller, _) = makeTestController()
        let games = controller.activeGames
        let viewModel = controller.makePracticeGameViewModel(BundledPuzzles.puzzles(for: .medium)[0], number: 1)
        XCTAssertTrue(viewModel.isPractice)
        viewModel.revealPuzzle()
        XCTAssertTrue(viewModel.state.isCompleted)
        XCTAssertEqual(controller.stats, Stats())
        XCTAssertEqual(controller.activeGames, games)
    }

    func testTemplateLessonPracticeSkipsTheExamplePuzzle() throws {
        let lesson = try XCTUnwrap(Lesson.make(for: .claiming))
        XCTAssertNil(LessonScript.all[.claiming], "a template lesson")
        let values = lesson.cells.map { $0.value ?? 0 }
        let drills = BundledPuzzles.drills(for: .claiming)
        let example = try XCTUnwrap(drills.first { entry in
            let start = entry.initialGrid.map { Int(String($0)) ?? 0 }
            return zip(start, values).allSatisfy { $0 == 0 || $0 == $1 }
        })
        XCTAssertFalse(lesson.practice.contains(example))
    }

    /// Hidden Single, Pointing, Naked Pair and X-Wing are written by hand (Design/v2 Learn.jsx).
    func testTheFourScriptedLessonsLoadAndStep() throws {
        let expected: [Technique: Int] = [.hiddenSingleBox: 5, .pointing: 4, .nakedPair: 4, .xWing: 4]
        for (technique, count) in expected {
            let lesson = try XCTUnwrap(Lesson.make(for: technique))
            XCTAssertNotNil(LessonScript.all[technique])
            XCTAssertEqual(lesson.steps.count, count, "\(technique)")
            XCTAssertEqual(Lesson.stepCount(for: technique), count)
            XCTAssertFalse(lesson.practice.isEmpty, "\(technique) has a practice puzzle")
            XCTAssertTrue(lesson.practice.allSatisfy { $0.techniques.contains(technique) })
            // Givens are a legal board, and every step marks something different from the last.
            XCTAssertFalse(SolverBoard(values: lesson.cells.map { $0.value ?? 0 }).hasContradiction, "\(technique)")
            for (previous, step) in zip(lesson.steps, lesson.steps.dropFirst()) {
                XCTAssertFalse(step.highlight.isEmpty)
                XCTAssertNotEqual(previous, step)
            }
        }
        let hidden = try XCTUnwrap(Lesson.make(for: .hiddenSingleBox))
        XCTAssertEqual(hidden.steps.last?.highlight.ghostDigits, [2: 5], "the last step shows 5 in the top-right cell")
        XCTAssertEqual(hidden.steps[3].highlight.struckDigits.keys.sorted(), [1, 10, 11, 18, 19], "ruled-out cells")
        let pointing = try XCTUnwrap(Lesson.make(for: .pointing))
        XCTAssertEqual(pointing.steps[2].highlight.struckDigits, [13: [3], 15: [3], 16: [3]], "3 crossed off in the rest of row 2")
        XCTAssertEqual(pointing.steps[0].highlight.ringedDigits, [9: [3], 11: [3]])
        let xWing = try XCTUnwrap(Lesson.make(for: .xWing))
        XCTAssertEqual(xWing.steps[3].highlight.struckDigits.keys.sorted(), [25, 29, 43, 74])
    }

    /// The written lessons are real Sudoku (Learn.jsx's boards were not): a solvable board, notes that
    /// are true candidates, patterns that are a digit's full set of places, and steps the solver's own
    /// detector finds.
    func testTheScriptedLessonsAreRealSudoku() throws {
        for (technique, script) in LessonScript.all {
            let board = SolverBoard(values: script.values)
            XCTAssertEqual(SolutionCounter.count(script.values, limit: 1), 1, "\(technique) has a solution")
            let candidates = { (cell: Int) in Set(SolverBoard.digits(in: board.candidates[cell])) }
            let detected = LogicalSolver.steps(for: technique, on: board)
            for (index, step) in script.steps.enumerated() {
                let marks = step.highlight, label = "\(technique) step \(index + 1)"
                for (cell, digits) in marks.shownCandidates {
                    XCTAssertTrue(digits.isSubset(of: candidates(cell)), "\(label): note \(digits.sorted()) in cell \(cell)")
                }
                // A one-digit pattern (Pointing, X-Wing) is every place for that digit in a row or box.
                let ringed = marks.ringedDigits.flatMap { cell, digits in digits.map { CellDigit(cell: cell, digit: $0) } }
                if Set(ringed.map(\.digit)).count == 1, let digit = ringed.first?.digit {
                    for cells in Dictionary(grouping: ringed.map(\.cell), by: { $0 / 9 }).values {
                        let full = (0..<9).flatMap { [House(kind: .row, index: $0), House(kind: .box, index: $0)] }.contains { house in
                            Set(house.cells.filter { candidates($0).contains(digit) }) == Set(cells)
                        }
                        XCTAssertTrue(full, "\(label): \(cells) is all of \(digit)'s places in a house")
                    }
                }
                let struck = marks.struckDigits.flatMap { cell, digits in digits.map { CellDigit(cell: cell, digit: $0) } }
                if !struck.isEmpty {
                    let found = detected.contains { Set(struck).isSubset(of: Set($0.eliminations)) }
                    XCTAssertTrue(found, "\(label): the solver makes these removals")
                }
                for (cell, digit) in marks.ghostDigits {
                    // A placement after removals (Naked Pair) needs only the removals' digits gone.
                    let left = candidates(cell).subtracting(script.steps[index - 1].highlight.struckDigits[cell] ?? [])
                    let placed = detected.contains { $0.placements.contains(CellDigit(cell: cell, digit: digit)) }
                    XCTAssertTrue(left == [digit] || placed, label)
                }
            }
        }
        let pencilled = try XCTUnwrap(LessonScript.nakedPair.steps.first).highlight.shownCandidates
        let board = SolverBoard(values: LessonScript.nakedPair.values)
        for (cell, digits) in pencilled {
            XCTAssertEqual(digits, Set(SolverBoard.digits(in: board.candidates[cell])), "Naked Pair notes in cell \(cell) are exact")
        }
    }

    func testEveryTechniqueSitsInOneOfFiveLearnTiers() {
        XCTAssertEqual(Set(Lesson.techniques.map(\.learnTier)), Set(LearnTier.allCases))
        XCTAssertEqual(Technique.pointing.learnTier, .intermediate)
        XCTAssertEqual(Technique.xyChain.learnTier, .expert)
        XCTAssertEqual(Technique.bugPlusOne.learnTier, .esoteric)
    }

    /// Every hint starts at step 1, and offers its lesson from step 2.
    func testEveryHintOpensAtStepOneWithALessonLink() {
        let (viewModel, _) = makeViewModel()
        viewModel.requestHint()
        XCTAssertEqual(viewModel.hint?.level, 1)
        XCTAssertNil(viewModel.hint?.lessonTechnique)
        viewModel.hintNext()
        XCTAssertEqual(viewModel.hint?.lessonTechnique, viewModel.hint?.step?.technique)
    }

    func testProgressIsSavedAndReloaded() throws {
        let (controller, dir) = makeTestController()
        let viewModel = controller.makePracticeGameViewModel(BundledPuzzles.puzzles(for: .easy)[0], number: 1)
        viewModel.onTechniqueFound?(.nakedPair, "p1", .placed(cell: 0, digit: 1))
        viewModel.onHintShown?(.xWing, [], "p1")
        XCTAssertEqual(controller.progress(for: .nakedPair).foundUnaided.count, 1)
        let reloaded = AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider(),
                                     imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
        XCTAssertEqual(reloaded.progress(for: .nakedPair).foundUnaided.count, 1)
        XCTAssertEqual(reloaded.progress(for: .xWing).hintsSeen, 1)
    }

    /// A credited move stays credited: a second view model on the same puzzle (Continue, or the
    /// same practice puzzle again) replays it for nothing.
    func testACreditedMoveEarnsNothingInALaterSession() async throws {
        let (controller, _) = makeTestController()
        let entry = try XCTUnwrap(BundledPuzzles.puzzles(for: .easy).first)
        var credited: Technique?
        var keep: [GameViewModel] = []
        for _ in 0..<2 {
            let viewModel = controller.makePracticeGameViewModel(entry, number: 1)
            keep.append(viewModel)
            let board = SolverBoard(cells: viewModel.state.cells)
            let placement = try XCTUnwrap(LogicalSolver().nextStep(board)?.placements.first)
            credited = MasteryJudge.technique(for: .placed(cell: placement.cell, digit: placement.digit), on: board)
            viewModel.select(cell: viewModel.state.cells.first { $0.index == placement.cell }!)
            viewModel.setDigit(placement.digit)
            let technique = try XCTUnwrap(credited)
            await waitFor { controller.progress(for: technique).credits >= 1 }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertEqual(controller.progress(for: try XCTUnwrap(credited)).credits, 1, "the replay earned nothing")
    }

    /// Fill notes, hint, Undo, then save and resume: the hinted cell still earns nothing.
    func testUndoAndResumeKeepAHintExcluded() async throws {
        let (controller, dir) = makeTestController()
        await controller.startNewGame(for: .easy)
        let viewModel = controller.makeGameViewModel(for: .easy)!
        viewModel.fillAllNotes()
        viewModel.requestHint()
        let placement = try XCTUnwrap(viewModel.hint?.step?.placements.first)
        viewModel.endHint()
        viewModel.undo() // takes back Fill all notes; the game no longer holds anything about the hint
        let images = ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true))
        let reloaded = AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider(), imageStore: images)
        let resumed = reloaded.makeGameViewModel(for: .easy)!
        resumed.select(cell: resumed.state.cells.first { $0.index == placement.cell }!)
        resumed.setDigit(placement.digit)
        await pause()
        XCTAssertTrue(reloaded.learningLedger.credited.isEmpty)
    }

    /// A practice hint holds when the same practice puzzle is opened again.
    func testAPracticeHintHoldsWhenReopened() async throws {
        let (controller, _) = makeTestController()
        let entry = BundledPuzzles.puzzles(for: .easy)[0]
        let first = controller.makePracticeGameViewModel(entry, number: 1)
        first.requestHint()
        let placement = try XCTUnwrap(first.hint?.step?.placements.first)
        first.endHint()
        let again = controller.makePracticeGameViewModel(entry, number: 1)
        again.select(cell: again.state.cells.first { $0.index == placement.cell }!)
        again.setDigit(placement.digit)
        await pause()
        XCTAssertTrue(controller.learningLedger.credited.isEmpty)
    }

    /// Bundled puzzles that share a long prefix are different practice puzzles, each with its own credit.
    func testPracticePuzzlesWithTheSamePrefixAreKeptApart() async throws {
        let (controller, _) = makeTestController()
        let twins = try XCTUnwrap(Dictionary(grouping: BundledPuzzles.all) { $0.initialGrid.prefix(12) }.values.first { $0.count > 1 })
        var games: [GameViewModel] = []
        for entry in twins.prefix(2) {
            let viewModel = controller.makePracticeGameViewModel(entry, number: 1)
            games.append(viewModel)
            try placeNextSingle(viewModel)
        }
        XCTAssertNotEqual(games[0].state.puzzle.id, games[1].state.puzzle.id)
        await waitFor { controller.learningLedger.credited.count >= 2 }
        XCTAssertEqual(controller.learningLedger.credited.count, 2)
    }

    /// A Hidden Single box hint also blocks line credit in that puzzle, and one move earns once.
    func testABoxHintBlocksLineCredit() {
        let (controller, viewModel) = makeLearningGame()
        let puzzle = viewModel.state.puzzle.id
        viewModel.onHintShown?(.hiddenSingleBox, [], puzzle)
        viewModel.onTechniqueFound?(.hiddenSingleLine, puzzle, .placed(cell: 5, digit: 5))
        XCTAssertEqual(controller.progress(for: .hiddenSingleBox).credits, 0)
        viewModel.onTechniqueFound?(.fullHouse, puzzle, .placed(cell: 6, digit: 9))
        viewModel.onTechniqueFound?(.nakedSingle, puzzle, .placed(cell: 6, digit: 9)) // erased and replayed
        XCTAssertEqual(controller.learningLedger.credited.count, 1, "one move, one credit")
    }

    /// At launch the ledger keeps practice keys and keys of saved games, and drops the rest.
    func testTheLedgerIsPrunedAtLaunch() async throws {
        let (controller, dir) = makeTestController()
        let active = await controller.startNewGame(for: .easy).puzzle.id
        var ledger = LearningLedger()
        ledger.credited = ["gone|placed|0|1", "practice-123|placed|0|1", "\(active)|placed|0|1"]
        ledger.hintedMoves = ["gone|0|1", "\(active)|0|1"]
        ledger.hintedTechniques = ["gone|pointing", "practice-123|pointing"]
        try PersistenceManager(directory: dir).save(LearningFile(ledger: ledger), to: "technique_progress.json")
        let images = ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true))
        let reloaded = AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider(), imageStore: images)
        XCTAssertEqual(reloaded.learningLedger.credited, ["practice-123|placed|0|1", "\(active)|placed|0|1"])
        XCTAssertEqual(reloaded.learningLedger.hintedMoves, ["\(active)|0|1"])
        XCTAssertEqual(reloaded.learningLedger.hintedTechniques, ["practice-123|pointing"])
    }

    /// A judgement still running when the next puzzle loads is credited to its own puzzle.
    func testACreditLandsOnThePuzzleItWasEarnedIn() async throws {
        let (viewModel, _) = makeViewModel()
        var credits: [String] = []
        viewModel.onTechniqueFound = { _, puzzleID, _ in credits.append(puzzleID) }
        let placement = try XCTUnwrap(LogicalSolver().nextStep(SolverBoard(cells: viewModel.state.cells))?.placements.first)
        let p = TestData.puzzle
        let twin = SudokuPuzzle(id: "other", difficulty: p.difficulty, initialGrid: p.initialGrid, solutionGrid: p.solutionGrid)
        let other = GameState.newGame(for: twin)
        for state in [nil, other] {
            if let state { viewModel.load(state: state) } // straight away: the first judgement is still running
            viewModel.select(cell: viewModel.state.cells.first { $0.index == placement.cell }!)
            viewModel.setDigit(placement.digit)
        }
        await waitFor { credits.count >= 2 }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(credits.sorted(), ["other", "test"])
    }

    /// Hidden Single (line) is one lesson with Hidden Single (box): old line-only saves count in Learn,
    /// and new line credits land on the box record, counted once.
    func testHiddenSingleLineProgressCountsAsHiddenSingle() throws {
        let (_, dir) = makeTestController()
        var line = TechniqueProgress()
        line.recordFound(puzzleID: "a", at: start)
        try PersistenceManager(directory: dir).save([Technique.hiddenSingleLine.rawValue: line], to: "technique_progress.json")
        let images = ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true))
        let persistence = PersistenceManager(directory: dir)
        let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(), imageStore: images)
        XCTAssertEqual(controller.progress(for: .hiddenSingleBox).credits, 1)
        XCTAssertEqual(controller.progress(for: .hiddenSingleBox).level, .learning)
        let viewModel = controller.makePracticeGameViewModel(BundledPuzzles.puzzles(for: .easy)[0], number: 1)
        viewModel.onTechniqueFound?(.hiddenSingleLine, "b", .placed(cell: 1, digit: 2))
        viewModel.onTechniqueFound?(.hiddenSingleLine, "b", .placed(cell: 1, digit: 2)) // already credited
        XCTAssertEqual(controller.progress(for: .hiddenSingleBox).credits, 2)
        XCTAssertNil(controller.techniqueProgress[Technique.hiddenSingleLine.rawValue], "merged into the box record")
    }

    // MARK: - Learning files that fail to load

    private func reload(_ dir: URL) -> AppController {
        let images = ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true))
        return AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider(), imageStore: images)
    }

    /// Where PersistenceManager keeps `name` (saving it first if needed).
    private func url(of name: String, in dir: URL) throws -> URL {
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        if let found = files.first(where: { $0.lastPathComponent == name }) { return found }
        try PersistenceManager(directory: dir).save([String](), to: name)
        return try url(of: name, in: dir)
    }

    private func bytes(_ name: String, in dir: URL) -> Data? {
        let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        return files.first { $0.lastPathComponent == name }.flatMap { try? Data(contentsOf: $0) }
    }

    /// Credits one move in a practice puzzle; returns the controller's folder and the puzzle id.
    private func creditOnce() throws -> (dir: URL, puzzle: String) {
        let (controller, dir) = makeTestController()
        let game = controller.makePracticeGameViewModel(BundledPuzzles.puzzles(for: .easy)[0], number: 1)
        let puzzle = game.state.puzzle.id
        game.onTechniqueFound?(.nakedSingle, puzzle, .placed(cell: 0, digit: 1))
        XCTAssertEqual(controller.progress(for: .nakedSingle).credits, 1)
        return (dir, puzzle)
    }

    /// Tries a credit and a hint on a controller whose learning file is unreadable.
    private func tryLearning(_ controller: AppController, puzzle: String) {
        let game = controller.makePracticeGameViewModel(BundledPuzzles.puzzles(for: .easy)[0], number: 1)
        game.onTechniqueFound?(.nakedSingle, puzzle, .placed(cell: 0, digit: 1)) // credited before
        game.onTechniqueFound?(.fullHouse, puzzle, .placed(cell: 2, digit: 3))
        game.onHintShown?(.pointing, [CellDigit(cell: 4, digit: 4)], puzzle)
    }

    /// Progress and ledger share one file. Corrupt it and launch twice before any restore: the loss
    /// takes both, so replaying the credited move never goes past the count from before.
    func testALostLearningFileCanNotGiveADuplicateCredit() throws {
        let (dir, puzzle) = try creditOnce()
        let saved = try PersistenceManager(directory: dir).load(LearningFile.self, from: "technique_progress.json")
        XCTAssertEqual(saved?.ledger.credited.count, 1, "the ledger is saved in the progress file")
        try Data("not json".utf8).write(to: try url(of: "technique_progress.json", in: dir))
        let first = reload(dir)
        tryLearning(first, puzzle: puzzle)
        XCTAssertEqual(first.progress(for: .nakedSingle).credits, 0)
        XCTAssertNil(bytes("technique_progress.json", in: dir), "set aside and not rewritten on the failed launch")
        let second = reload(dir) // the file is just missing now
        tryLearning(second, puzzle: puzzle)
        XCTAssertEqual(second.progress(for: .nakedSingle).credits, 1, "no more than before the corruption")
        XCTAssertEqual(second.learningLedger.credited.count, 2, "credits and exclusions were lost together and start again")
    }

    /// Saves before the ledger hold only the progress dictionary; they load with an empty ledger.
    func testAnOldProgressFileLoads() throws {
        let old = [Technique.pointing.rawValue: TechniqueProgress()]
        let decoded = try JSONDecoder().decode(LearningFile.self, from: JSONEncoder().encode(old))
        XCTAssertEqual(decoded.progress, old)
        XCTAssertEqual(decoded.ledger, LearningLedger())
    }

    /// A set-aside game file may be restored, even on a later launch: its ledger keys stay.
    func testPruningWaitsWhileAGameFileIsSetAside() async throws {
        let (controller, dir) = makeTestController()
        let id = await controller.startNewGame(for: .easy).puzzle.id
        var ledger = LearningLedger()
        ledger.credited = ["\(id)|placed|0|1"]
        try PersistenceManager(directory: dir).save(LearningFile(ledger: ledger), to: "technique_progress.json")
        try Data("not json".utf8).write(to: try url(of: "game_easy.json", in: dir))
        _ = reload(dir)
        let second = reload(dir) // game_easy.json is missing now; its corrupt copy is on disk
        XCTAssertEqual(second.learningLedger, ledger)
    }

    /// An unreadable imports file may still hold games: their ledger keys stay, also on the launch after.
    func testPruningWaitsWhenImportsCannotBeRead() throws {
        let (_, dir) = makeTestController()
        var ledger = LearningLedger()
        ledger.credited = ["import-1|placed|0|1"]
        try PersistenceManager(directory: dir).save(LearningFile(ledger: ledger), to: "technique_progress.json")
        try Data("not json".utf8).write(to: try url(of: "imported_games.json", in: dir))
        XCTAssertEqual(reload(dir).learningLedger, ledger)
        XCTAssertEqual(reload(dir).learningLedger, ledger, "second launch: the imports file is missing, its copy is set aside")
        let onDisk = try PersistenceManager(directory: dir).load(LearningFile.self, from: "technique_progress.json")
        XCTAssertEqual(onDisk?.ledger, ledger)
    }

    /// Games saved before the ledger name their hinted techniques only in the hint log.
    func testOldGamesSeedHintedTechniquesFromTheirHintLog() async throws {
        let (controller, dir) = makeTestController()
        var state = await controller.startNewGame(for: .easy)
        state.hintLog = [HintLogEntry(technique: "hiddenSingleLine", deepestRung: 2, applied: false),
                         HintLogEntry(technique: "pointing", deepestRung: 1, applied: false),
                         HintLogEntry(technique: "mistake", deepestRung: 3, applied: true)]
        try PersistenceManager(directory: dir).save(state, to: "game_easy.json")
        let reloaded = reload(dir)
        let game = reloaded.makeGameViewModel(for: .easy)!
        let id = state.puzzle.id
        XCTAssertEqual(reloaded.learningLedger.hintedTechniques, ["\(id)|hiddenSingleBox", "\(id)|pointing"])
        game.onTechniqueFound?(.hiddenSingleBox, id, .placed(cell: 0, digit: 1))
        XCTAssertEqual(reloaded.progress(for: .hiddenSingleBox).credits, 0, "the line hint blocks box credit too")
    }

    func testCreditsLabelCountsUses() {
        XCTAssertEqual(LearnView.creditsLabel(1, otherwise: ""), "1 unaided use")
        XCTAssertEqual(LearnView.creditsLabel(12, otherwise: ""), "12 unaided uses")
        XCTAssertEqual(LearnView.creditsLabel(0, otherwise: "Lesson"), "Lesson")
    }

    // MARK: - Lessons

    func testEveryTechniqueWithADrillHasAWorkedExample() throws {
        var withLesson = 0
        for technique in Lesson.techniques where !BundledPuzzles.drills(for: technique).isEmpty {
            guard let lesson = Lesson.make(for: technique) else { return XCTFail("\(technique) has drills but no lesson") }
            XCTAssertEqual(lesson.steps.count, Lesson.stepCount(for: technique))
            XCTAssertLessThanOrEqual(lesson.practice.count, 3)
            // A single shows its answer as the dashed target; other steps fill their pattern.
            let last = try XCTUnwrap(lesson.steps.last).highlight
            XCTAssertFalse(last.patternCells.isEmpty && last.ghostDigits.isEmpty, "\(technique)")
            withLesson += 1
        }
        XCTAssertGreaterThanOrEqual(withLesson, 20, "most techniques have an example in the bundle")
    }

    // MARK: - Learn copy (issue 50)

    /// "N of 27 techniques in your hands" counts mastered techniques only.
    func testLearnCountsOnlyFullyLearnedTechniques() {
        XCTAssertEqual(LearnView.inHandCount { _ in .learning }, 0, "half-learned is not in your hands")
        XCTAssertEqual(LearnView.inHandCount { $0 == .nakedSingle || $0 == .pointing ? .mastered : .learning }, 2)
        XCTAssertEqual(LearnView.inHandCount { _ in .mastered }, Lesson.techniques.count)
    }

    /// Every Learn row has its own one-line description, and none says "house".
    func testTechniqueDescriptionsAreDistinct() {
        let definitions = Lesson.techniques.map(\.definition)
        XCTAssertEqual(Set(definitions).count, definitions.count, "two techniques share a description")
        for technique in Lesson.techniques {
            XCTAssertFalse(technique.definition.lowercased().contains("house"), "\(technique) says house")
        }
    }
}
