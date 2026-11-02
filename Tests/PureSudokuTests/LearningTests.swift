import XCTest
@testable import PureSudoku

/// Mastery, fading and lessons (CODESPEC 13.4, 13.5, 6.3.1).
@MainActor
final class LearningTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Mastery rule

    func testMasteredAfterThreePuzzlesOnThreeDays() {
        var progress = TechniqueProgress()
        XCTAssertEqual(progress.level, .new)
        progress.recordFound(puzzleID: "a", at: start)
        progress.recordFound(puzzleID: "b", at: start.addingTimeInterval(60)) // same day
        progress.recordFound(puzzleID: "a", at: start.addingTimeInterval(2 * day)) // same puzzle again
        XCTAssertEqual(progress.level, .learning, "two days, and a repeated puzzle doesn't count twice")
        progress.recordFound(puzzleID: "c", at: start.addingTimeInterval(3 * day))
        XCTAssertEqual(progress.level, .learning)
        progress.recordFound(puzzleID: "d", at: start.addingTimeInterval(4 * day))
        XCTAssertEqual(progress.level, .mastered)
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

    private func makeViewModel(level: TechniqueProgress.Level = .learning) -> (GameViewModel, () -> [Technique]) {
        let viewModel = GameViewModel(state: TestData.newGameState(), settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider())
        var found: [Technique] = []
        viewModel.onTechniqueFound = { technique, _ in found.append(technique) }
        viewModel.learningLevel = { _ in level }
        return (viewModel, { found })
    }

    private func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    func testFindingAStepWithoutAHintIsCredited() async throws {
        let (viewModel, found) = makeViewModel()
        let step = try XCTUnwrap(LogicalSolver().nextStep(SolverBoard(cells: viewModel.state.cells)))
        let placement = try XCTUnwrap(step.placements.first)
        viewModel.select(cell: viewModel.state.cells.first { $0.index == placement.cell }!)
        viewModel.setDigit(placement.digit)
        await waitFor { !found().isEmpty }
        XCTAssertEqual(found().count, 1)
        XCTAssertTrue([Technique.fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle].contains(found()[0]))
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

    func testLessonPracticeSkipsTheExamplePuzzle() throws {
        let lesson = try XCTUnwrap(Lesson.make(for: .pointing))
        let drills = BundledPuzzles.drills(for: .pointing)
        let example = try XCTUnwrap(drills.first { entry in
            let start = entry.initialGrid.map { Int(String($0)) ?? 0 }
            return zip(start, lesson.board.values).allSatisfy { $0 == 0 || $0 == $1 }
        })
        XCTAssertFalse(lesson.practice.contains(example))
    }

    func testANewTechniqueOpensAtWhyWithALessonOffer() {
        let (fresh, _) = makeViewModel(level: .new)
        fresh.requestHint()
        XCTAssertEqual(fresh.hint?.rung, 3)
        XCTAssertEqual(fresh.hint?.offersLesson, true)
        let (known, _) = makeViewModel(level: .mastered)
        known.requestHint()
        XCTAssertEqual(known.hint?.rung, 1)
        XCTAssertEqual(known.hint?.offersLesson, false)
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

    func testEveryTechniqueWithADrillHasAWorkedExample() {
        var withLesson = 0
        for technique in Lesson.techniques where !BundledPuzzles.drills(for: technique).isEmpty {
            guard let lesson = Lesson.make(for: technique) else { return XCTFail("\(technique) has drills but no lesson") }
            let shown = lesson.step.technique == .hiddenSingleLine ? Technique.hiddenSingleBox : lesson.step.technique
            XCTAssertEqual(shown, technique)
            XCTAssertLessThanOrEqual(lesson.practice.count, 3)
            XCTAssertFalse(lesson.highlight.patternCells.isEmpty)
            withLesson += 1
        }
        XCTAssertGreaterThanOrEqual(withLesson, 20, "most techniques have an example in the bundle")
    }
}
