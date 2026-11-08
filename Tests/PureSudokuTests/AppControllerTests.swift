import XCTest
@testable import PureSudoku

@MainActor
final class AppControllerTests: XCTestCase {
    func testNightForcesSoundAndHapticsOff() {
        let (controller, _) = makeTestController()
        controller.updateSettings {
            $0.soundsEnabled = true
            $0.hapticsEnabled = true
            $0.appearance = .day
        }
        XCTAssertTrue(controller.soundsActive)
        XCTAssertTrue(controller.hapticsActive)
        XCTAssertFalse(controller.palette.isNight)
        controller.updateSettings { $0.appearance = .night }
        XCTAssertFalse(controller.soundsActive)
        XCTAssertFalse(controller.hapticsActive)
        XCTAssertTrue(controller.palette.isNight)
        XCTAssertEqual(controller.preferredColorScheme, .dark)
        XCTAssertTrue(controller.settings.soundsEnabled, "the saved choice is kept for Day")
    }

    /// Only the first row is given, so the import has many solutions (CODESPEC 2.1).
    private let twoSolutionGrid = String(TestData.puzzle.solutionGrid.prefix(9)) + String(repeating: "0", count: 72)

    func testImportsAreGradedAndFlaggedForUniqueness() throws {
        let (controller, _) = makeTestController()
        let unique = try XCTUnwrap(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid)).gameState.puzzle
        XCTAssertEqual(unique.hasUniqueSolution, true)
        XCTAssertEqual(unique.difficulty, .easy)
        XCTAssertNotNil(unique.grade)

        let several = try XCTUnwrap(controller.createImportedGame(initialGrid: twoSolutionGrid)).gameState.puzzle
        XCTAssertEqual(several.hasUniqueSolution, false)
        XCTAssertFalse(several.isUnique)
        XCTAssertNil(several.grade, "the solver can't finish a 9-clue puzzle")
        XCTAssertEqual(several.difficulty, .master, "beyond the solver: the top level")
    }

    func testOldImportsAreRecountedAndSaved() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = PersistenceManager(directory: dir)
        let puzzle = SudokuPuzzle(id: "old", difficulty: .hard, initialGrid: twoSolutionGrid,
                                  solutionGrid: TestData.puzzle.solutionGrid, source: .imported)
        XCTAssertNil(puzzle.hasUniqueSolution)
        try persistence.save([ImportedGame(gameState: GameState.newGame(for: puzzle))], to: "imported_games.json")

        let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(),
                                       imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
        for _ in 0..<100 where controller.importedGames.first?.gameState.puzzle.hasUniqueSolution == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.importedGames.first?.gameState.puzzle.hasUniqueSolution, false)
        let saved = try XCTUnwrap(persistence.load([ImportedGame].self, from: "imported_games.json"))
        XCTAssertEqual(saved.first?.gameState.puzzle.hasUniqueSolution, false, "the count is persisted")
    }

    func testUnknownTechniqueInASavedGradeKeepsTheGame() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TestData.puzzle)) as? [String: Any])
        json["grade"] = ["hardestTier": 3, "score": 500, "techniques": ["somethingFromTheFuture"]]
        let puzzle = try JSONDecoder().decode(SudokuPuzzle.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(puzzle.grade)
        XCTAssertEqual(puzzle.initialGrid, TestData.puzzle.initialGrid)
    }

    func testUpdateSettingsAppliesImmediately() {
        let (controller, _) = makeTestController()
        controller.updateSettings { $0.showTimer = false }
        XCTAssertFalse(controller.settings.showTimer)
    }

    func testCompletionThenResetKeepsTheResetGame() async {
        let (controller, _) = makeTestController()
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        let viewModel = controller.makeGameViewModel(for: .easy)
        viewModel.revealPuzzle()
        viewModel.resetPuzzle()
        XCTAssertEqual(controller.activeGames[.easy]?.isCompleted, false)
        XCTAssertEqual(controller.stats, Stats(), "revealed games do not count")
    }

    /// Home's Continue card resumes the unfinished game played last; a level row starts a new one
    /// (CODESPEC 3.1).
    func testContinueIsTheGamePlayedLastAndALevelStartsANewOne() async {
        let clock = AdvancingTimeProvider()
        let (controller, _) = makeTestController(timeProvider: clock)
        XCTAssertNil(controller.continueGame)
        await controller.startNewGame(for: .easy, mode: .seeded(1))
        clock.advance(60)
        await controller.startNewGame(for: .hard, mode: .seeded(2))
        XCTAssertEqual(controller.continueGame?.puzzle.difficulty, .hard)

        clock.advance(60)
        let easy = controller.makeGameViewModel(for: .easy)
        let empty = easy.state.cells.first { $0.value == nil }!
        easy.select(cell: empty)
        easy.setDigit(1)
        easy.handleSceneDidDisappear() // saves on the next main-actor turn
        for _ in 0..<50 where controller.continueGame?.puzzle.difficulty != .easy {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.continueGame?.puzzle.difficulty, .easy, "playing Easy makes it the latest")

        let menu = MainMenuViewModel(controller: controller)
        let before = controller.activeGames[.easy]?.puzzle.id
        let started = await menu.startNewGame(for: .easy)
        XCTAssertNotEqual(started.state.puzzle.id, before, "a level row always starts a new puzzle")
        XCTAssertTrue(started.state.cells.allSatisfy { $0.given || $0.value == nil })

        controller.makeGameViewModel(for: .hard).revealPuzzle()
        for _ in 0..<50 where controller.activeGames[.hard]?.isCompleted != true {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.activeGames[.hard]?.isCompleted, true)
        XCTAssertEqual(controller.continueGame?.puzzle.difficulty, .easy, "a finished game is never offered")
    }

    /// VoiceOver reads each Journal row as one line, with "none yet" for every dash (CODESPEC 3.3).
    func testJournalRowLabels() {
        let (controller, _) = makeTestController()
        controller.updateStats { $0.recordCompletion(for: .expert, time: 252, usedReveal: false) }
        let journal = StatsViewModel(controller: controller)
        XCTAssertEqual(journal.rowLabel(for: .expert), "Expert: 1 solved, best 4:12, typical 4:12")
        XCTAssertEqual(journal.rowLabel(for: .master), "Master: solved none yet, best none yet, typical none yet")
        XCTAssertEqual(journal.week().map(\.name).first, "Monday")
    }

    // MARK: - QA fixes (#33, #39, #37)

    private func solve(_ viewModel: GameViewModel) {
        let solution = Array(viewModel.state.puzzle.solutionGrid).map { Int(String($0))! }
        for cell in viewModel.state.cells where cell.value == nil {
            viewModel.select(cell: cell)
            viewModel.setDigit(solution[cell.index])
        }
    }

    func testRestartingASolvedPuzzleDoesNotCountItAgain() async throws {
        let (controller, _) = makeTestController()
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        let viewModel = controller.makeGameViewModel(for: .easy)
        solve(viewModel)
        XCTAssertTrue(viewModel.state.isCompleted)
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1)
        viewModel.resetPuzzle()
        XCTAssertTrue(viewModel.state.counted, "restart keeps the counted flag")
        solve(viewModel)
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1, "the same puzzle counts once")
        XCTAssertEqual(controller.stats.solvedCount(for: .easy), 1)
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(viewModel.state))
        XCTAssertTrue(saved.counted)
    }

    func testOldCompletedSavesAreAlreadyCounted() throws {
        var game = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(GameState.newGame(for: TestData.puzzle))) as? [String: Any])
        game["counted"] = nil
        game["isCompleted"] = true
        XCTAssertTrue(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: game)).counted)
        game["isCompleted"] = false
        XCTAssertFalse(try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: game)).counted)
    }

    func testReplacingAnUnfinishedGameKeepsItsPlayedTime() async {
        let clock = AdvancingTimeProvider()
        let (controller, _) = makeTestController(timeProvider: clock)
        await controller.startNewGame(for: .easy, mode: .seeded(3))
        let viewModel = controller.makeGameViewModel(for: .easy)
        viewModel.handleSceneDidAppear()
        clock.advance(300)
        viewModel.handleSceneDidDisappear() // saves on the next main-actor turn
        for _ in 0..<50 where controller.activeGames[.easy]?.elapsedSeconds != 300 {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.activeGames[.easy]?.elapsedSeconds, 300)
        await controller.startNewGame(for: .easy, mode: .seeded(4))
        XCTAssertEqual(controller.stats.totalTimeSeconds, 300, "the abandoned game's time stays in the total")
        await controller.startNewGame(for: .easy, mode: .seeded(5))
        XCTAssertEqual(controller.stats.totalTimeSeconds, 300, "an untouched game adds nothing")
    }

    /// When I check: a reopened game keeps its Check marks through a settings change.
    func testReopenedGameKeepsItsCheckMarks() {
        var settings = Settings()
        settings.mistakes = .onCheck
        var state = TestData.newGameState()
        let index = state.cells.firstIndex { $0.value == nil }!
        let solution = Array(state.puzzle.solutionGrid).map { Int(String($0))! }
        state.cells[index].value = solution[state.cells[index].index] % 9 + 1
        state.cells[index].isError = true
        let viewModel = GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
        viewModel.apply(settings: settings)
        XCTAssertTrue(viewModel.state.cells[index].isError)
    }

    /// With no explainable step, the hint fills the selected empty cell, not the first one.
    func testNoStepHintUsesTheSelectedCell() throws {
        var state = TestData.newGameState()
        // An empty board: no technique applies, so the hint places an answer.
        state.cells = state.cells.map { cell in
            var cell = cell
            cell.given = false
            cell.value = nil
            return cell
        }
        let chosen = state.cells[40]
        let viewModel = GameViewModel(state: state, settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider())
        viewModel.select(cell: chosen)
        viewModel.requestHint()
        guard case let .noStep(cell, _)? = viewModel.hint?.content else { return XCTFail("expected a no-step hint") }
        XCTAssertEqual(cell, chosen.index)
    }
}
