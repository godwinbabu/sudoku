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

    func testAMoveRightAfterItsHintEarnsNoCredit() async throws {
        let (viewModel, found) = makeViewModel()
        viewModel.requestHint()
        let placement = try XCTUnwrap(viewModel.hint?.step?.placements.first)
        let hinted = try XCTUnwrap(viewModel.hint?.step?.technique)
        viewModel.endHint()
        viewModel.select(cell: viewModel.state.cells.first { $0.index == placement.cell }!)
        viewModel.setDigit(placement.digit)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(found().contains(hinted))
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
