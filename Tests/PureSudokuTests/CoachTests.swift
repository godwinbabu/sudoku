import XCTest
@testable import PureSudoku

/// The coach (CODESPEC 6.3.3).
@MainActor
final class CoachTests: XCTestCase {
    private let solution = Array(TestData.puzzle.solutionGrid).map { Int(String($0))! }

    private func makeViewModel(time: TimeProvider = MockTimeProvider(), coach: Bool = true) -> GameViewModel {
        var settings = Settings()
        settings.coachWhenStuck = coach
        return GameViewModel(state: TestData.newGameState(), settings: settings, validator: SudokuValidator(), timeProvider: time)
    }

    func testPatternsAreDistinctAndStartWithTheNextStep() {
        let board = SolverBoard(cells: TestData.newGameState().cells)
        let solver = LogicalSolver()
        let patterns = solver.patterns(board)
        XCTAssertFalse(patterns.isEmpty)
        XCTAssertEqual(patterns.first?.technique, solver.nextStep(board)?.technique, "simplest first, as the solver would")
        let names = patterns.map(\.technique.displayName)
        XCTAssertEqual(names.count, Set(names).count, "one pattern per technique name")
        XCTAssertTrue(patterns.allSatisfy { $0.changeCount > 0 }, "every pattern changes the board")
    }

    func testBrowsingIsFreeAndRevealingCountsAsAHint() {
        let viewModel = makeViewModel()
        var shown: [Technique?] = []
        viewModel.onHintShown = { technique, _, _ in shown.append(technique) }
        viewModel.openCoach()
        let coach = try? XCTUnwrap(viewModel.coach)
        XCTAssertNil(viewModel.hint, "the coach replaces the hint card")
        XCTAssertFalse(viewModel.hintHighlight.areaCells.isEmpty, "the pattern is highlighted")
        if (coach?.patterns.count ?? 0) > 1 {
            viewModel.coachForward()
            XCTAssertEqual(viewModel.coach?.index, 1)
            viewModel.coachBack()
        }
        viewModel.endHint()
        XCTAssertEqual(viewModel.state.hints, 0, "looking at patterns is not a hint")
        XCTAssertTrue(shown.isEmpty, "the player can still earn mastery for a move they find")

        viewModel.openCoach()
        viewModel.coachReveal()
        XCTAssertEqual(shown.count, 1)
        viewModel.endHint()
        XCTAssertEqual(viewModel.state.hints, 1, "a revealed move is a hint")
        XCTAssertFalse(viewModel.state.assisted)
    }

    func testApplyingTheRevealedMoveIsAssisted() {
        let viewModel = makeViewModel()
        viewModel.openCoach()
        viewModel.coachReveal()
        let step = viewModel.coach!.current
        viewModel.applyCoach()
        XCTAssertNil(viewModel.coach)
        XCTAssertTrue(viewModel.state.assisted)
        for placement in step.placements {
            XCTAssertEqual(viewModel.state.cells.first { $0.index == placement.cell }?.value, placement.digit)
        }
    }

    func testTheDefinitionTogglesAndPagingResetsTheReveal() {
        let viewModel = makeViewModel()
        viewModel.openCoach()
        let names = CellNotation.plain
        let technique = viewModel.coach!.current.technique
        viewModel.coachToggleDefinition()
        XCTAssertEqual(viewModel.coach?.text(names), technique.definition)
        viewModel.coachToggleDefinition()
        XCTAssertTrue(viewModel.coach!.text(names).hasSuffix("?"), "the coach asks the player to find the move")
        viewModel.coachReveal()
        if viewModel.coach!.canGoForward {
            viewModel.coachForward()
            XCTAssertFalse(viewModel.coach!.revealed, "the next pattern starts hidden")
            viewModel.coachBack()
            XCTAssertTrue(viewModel.coach!.revealed, "a revealed pattern stays revealed")
        }
    }

    func testEveryRevealedPatternCountsAsAHintAfterPaging() throws {
        let viewModel = makeViewModel()
        viewModel.openCoach()
        try XCTSkipUnless(viewModel.coach!.patterns.count > 1, "needs two patterns")
        viewModel.coachReveal()
        viewModel.coachForward()
        viewModel.endHint()
        XCTAssertEqual(viewModel.state.hints, 1, "Show me then paging away is still a hint")

        viewModel.openCoach()
        viewModel.coachReveal()
        viewModel.coachForward()
        viewModel.coachReveal()
        viewModel.coachReveal() // twice on one page is one hint
        viewModel.endHint()
        XCTAssertEqual(viewModel.state.hints, 3, "two more revealed patterns")

        viewModel.openCoach()
        viewModel.coachReveal()
        viewModel.coachForward()
        viewModel.coachReveal()
        viewModel.applyCoach()
        XCTAssertEqual(viewModel.state.hints, 5, "applying logs the applied pattern and the other revealed one")
        XCTAssertEqual(viewModel.state.hintLog.last?.applied, true)
    }

    func testRestartClosesTheCoach() {
        let viewModel = makeViewModel()
        viewModel.openCoach()
        XCTAssertNotNil(viewModel.coach)
        viewModel.resetPuzzle()
        XCTAssertNil(viewModel.coach, "the old board's patterns no longer apply")
        XCTAssertTrue(viewModel.hintHighlight.isEmpty)
    }

    func testACorrectDigitAfterAnUndoResetsStuck() {
        let time = AdvancingTimeProvider()
        let viewModel = makeViewModel(time: time)
        viewModel.handleSceneDidAppear()
        viewModel.updateStuck()
        let empties = viewModel.state.cells.filter { $0.value == nil }
        viewModel.select(cell: empties[0])
        viewModel.setDigit(solution[empties[0].index])
        time.advance(10)
        viewModel.pauseTimer()
        viewModel.updateStuck()
        viewModel.undo()
        viewModel.updateStuck()
        viewModel.resumeTimer()
        time.advance(90)
        viewModel.select(cell: empties[1])
        viewModel.setDigit(solution[empties[1].index])
        viewModel.pauseTimer()
        viewModel.updateStuck() // elapsed 100: progress again
        viewModel.resumeTimer()
        time.advance(60)
        viewModel.pauseTimer()
        viewModel.updateStuck()
        XCTAssertFalse(viewModel.isStuck, "60 s since the last correct digit")
    }

    func testAMistakeComesBeforeTheCoach() {
        let viewModel = makeViewModel()
        let cell = viewModel.state.cells.first { $0.value == nil }!
        viewModel.select(cell: cell)
        viewModel.setDigit(solution[cell.index] % 9 + 1)
        viewModel.openCoach()
        XCTAssertNil(viewModel.coach)
        XCTAssertTrue(viewModel.hint?.isMistake == true)
    }

    func testTwoMinutesWithoutADigitOffersTheCoach() {
        let time = AdvancingTimeProvider()
        let viewModel = makeViewModel(time: time)
        viewModel.handleSceneDidAppear()
        viewModel.updateStuck()
        time.advance(100)
        viewModel.pauseTimer()
        viewModel.updateStuck()
        XCTAssertFalse(viewModel.isStuck)

        viewModel.resumeTimer()
        time.advance(30)
        viewModel.pauseTimer()
        viewModel.updateStuck()
        XCTAssertTrue(viewModel.isStuck)

        viewModel.resumeTimer()
        viewModel.hintTool()
        XCTAssertNotNil(viewModel.coach, "once stuck, the Hint tool opens the coach")
        XCTAssertFalse(viewModel.isStuck)
    }

    func testACorrectDigitResetsStuck() {
        let time = AdvancingTimeProvider()
        let viewModel = makeViewModel(time: time)
        viewModel.handleSceneDidAppear()
        viewModel.updateStuck()
        time.advance(100)
        let cell = viewModel.state.cells.first { $0.value == nil }!
        viewModel.select(cell: cell)
        viewModel.setDigit(solution[cell.index])
        viewModel.pauseTimer()
        viewModel.updateStuck()
        viewModel.resumeTimer()
        time.advance(100)
        viewModel.pauseTimer()
        viewModel.updateStuck()
        XCTAssertFalse(viewModel.isStuck, "100 s since the last correct digit")
    }

    func testTheSettingTurnsStuckOff() {
        let time = AdvancingTimeProvider()
        let viewModel = makeViewModel(time: time, coach: false)
        viewModel.handleSceneDidAppear()
        viewModel.updateStuck()
        time.advance(600)
        viewModel.pauseTimer()
        viewModel.updateStuck()
        XCTAssertFalse(viewModel.isStuck)
        viewModel.resumeTimer()
        viewModel.hintTool()
        XCTAssertNil(viewModel.coach)
        XCTAssertNotNil(viewModel.hint)
    }

    func testSettingRoundTrips() throws {
        var settings = Settings()
        settings.coachWhenStuck = false
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)), settings)
        XCTAssertTrue(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)).coachWhenStuck, "on by default")
    }
}
