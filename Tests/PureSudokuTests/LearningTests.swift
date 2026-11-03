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
        viewModel.onTechniqueFound = { technique, _ in found.append(technique) }
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
        let cell = viewModel.state.cells.first { $0.index == placement.cell }!
        viewModel.select(cell: cell)
        viewModel.setDigit(placement.digit)
        await settle(found, count: 1)
        XCTAssertEqual(found(), [try XCTUnwrap(expected)])
        // Undo and the same move again: no second credit.
        viewModel.undo()
        viewModel.select(cell: cell)
        viewModel.setDigit(placement.digit)
        await settle(found, count: 2)
        XCTAssertEqual(found().count, 1, "replaying a move earns nothing")
    }

    /// Everything the hint card does (Place · assisted, Apply/Remove · assisted) earns no credit.
    func testMovesFromTheHintCardEarnNoCredit() async throws {
        let (controller, _) = makeTestController()
        let entry = try XCTUnwrap(BundledPuzzles.puzzles(for: .medium).first)
        let viewModel = controller.makePracticeGameViewModel(entry, number: 1)
        var found: [Technique] = []
        viewModel.onTechniqueFound = { technique, _ in found.append(technique) }
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

    func testAHintedTechniqueEarnsNoCreditForTheRestOfThePuzzle() async throws {
        let (viewModel, found) = makeViewModel()
        viewModel.requestHint()
        let placement = try XCTUnwrap(viewModel.hint?.step?.placements.first)
        let hinted = try XCTUnwrap(viewModel.hint?.step?.technique)
        viewModel.endHint()
        let target = viewModel.state.cells.first { $0.index == placement.cell }!
        // A wrong digit, Undo, then the hinted move: none of this may earn credit for the hint.
        viewModel.select(cell: target)
        viewModel.setDigit(placement.digit % 9 + 1)
        viewModel.undo()
        viewModel.select(cell: target)
        viewModel.setDigit(placement.digit)
        await settle(found, count: 0)
        XCTAssertTrue(found().isEmpty, "the cell and digit the hint showed earn nothing, by any technique")
        XCTAssertFalse(found().contains(hinted))
        // Positive control: an unhinted single of another kind is still credited.
        var control = 0
        while control < 30, found().isEmpty {
            try placeNextSingle(viewModel)
            await settle(found, count: 0)
            control += 1
        }
        XCTAssertFalse(found().isEmpty, "crediting works at all")
        XCTAssertFalse(found().contains(hinted), "the hinted technique stays uncredited in this puzzle")
    }

    func testAWrongButPossibleDigitEarnsNothing() async throws {
        let (viewModel, found) = makeViewModel()
        let board = SolverBoard(cells: viewModel.state.cells)
        let solution = Array(TestData.puzzle.solutionGrid).map { Int(String($0))! }
        let cell = try XCTUnwrap((0..<81).first { board.values[$0] == 0 && board.candidates[$0].nonzeroBitCount > 1 })
        let wrong = try XCTUnwrap(SolverBoard.digits(in: board.candidates[cell]).first { $0 != solution[cell] })
        viewModel.select(cell: viewModel.state.cells.first { $0.index == cell }!)
        viewModel.setDigit(wrong)
        // Board now has a mistake, so even a correct single elsewhere earns nothing.
        try placeNextSingle(viewModel)
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
        XCTAssertFalse(lesson.isScripted)
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
            XCTAssertTrue(lesson.isScripted)
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
        XCTAssertEqual(pointing.steps[2].highlight.struckDigits, [13: [3], 16: [3]], "3 crossed off in row 2")
        XCTAssertEqual(pointing.steps[0].highlight.ringedDigits, [9: [3], 11: [3]])
        let xWing = try XCTUnwrap(Lesson.make(for: .xWing))
        XCTAssertEqual(xWing.steps[3].highlight.struckDigits.keys.sorted(), [25, 29, 43, 74])
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
        viewModel.onTechniqueFound?(.nakedPair, "p1")
        viewModel.onHintShown?(.xWing)
        XCTAssertEqual(controller.progress(for: .nakedPair).foundUnaided.count, 1)
        let reloaded = AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider(),
                                     imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
        XCTAssertEqual(reloaded.progress(for: .nakedPair).foundUnaided.count, 1)
        XCTAssertEqual(reloaded.progress(for: .xWing).hintsSeen, 1)
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
}
