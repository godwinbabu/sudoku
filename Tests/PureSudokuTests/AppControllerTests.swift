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

    /// With the streak at 0 but solves this week, the Journal names the last solved day (issue 51).
    func testJournalLastSolvedLine() throws {
        let (controller, _) = makeTestController()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let tuesday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 21)))
        let friday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 21)))
        let journal = StatsViewModel(controller: controller)
        XCTAssertNil(journal.lastSolvedLine(at: friday, calendar: calendar), "no solves, no line")

        controller.updateStats { $0.recordCompletion(for: .easy, time: 300, usedReveal: false, date: tuesday, calendar: calendar) }
        let updated = StatsViewModel(controller: controller)
        XCTAssertEqual(updated.streak(at: friday), 0)
        XCTAssertEqual(updated.lastSolvedLine(at: friday, calendar: calendar), "Last solved Tuesday.")
        let wednesday = tuesday.addingTimeInterval(86_400)
        XCTAssertNil(updated.lastSolvedLine(at: wednesday, calendar: calendar), "the streak is still alive")
    }
}
