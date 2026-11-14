import XCTest
@testable import PureSudoku

/// Save failures (#62) and the completion handoff (#72). A folder in place of a file makes saves to
/// that file fail; removing it lets them work again.
@MainActor
final class SaveSafetyTests: XCTestCase {
    private var dir: URL!
    private let clock = AdvancingTimeProvider()

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func launch() -> AppController {
        AppController(persistence: PersistenceManager(directory: dir), timeProvider: clock,
                      imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
    }

    private func block(_ file: String) throws {
        let url = dir.appendingPathComponent(file)
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func unblock(_ file: String) throws {
        try FileManager.default.removeItem(at: dir.appendingPathComponent(file))
    }

    private func saved<T: Codable>(_ type: T.Type, _ file: String) throws -> T? {
        try PersistenceManager(directory: dir).load(type, from: file)
    }

    private func solve(_ viewModel: GameViewModel) {
        let solution = Array(viewModel.state.puzzle.solutionGrid).map { Int(String($0))! }
        for cell in viewModel.state.cells where cell.value == nil {
            viewModel.select(cell: cell)
            viewModel.setDigit(solution[cell.index])
        }
        XCTAssertTrue(viewModel.state.isCompleted)
    }

    /// Starts an Easy game, plays it for `seconds`, and solves it.
    private func playAndSolve(_ controller: AppController, seconds: TimeInterval = 300) async -> GameViewModel {
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        let viewModel = controller.makeGameViewModel(for: .easy)
        viewModel.handleSceneDidAppear()
        clock.advance(seconds)
        solve(viewModel)
        return viewModel
    }

    // MARK: Save-failure notice (#62)

    func testAFailedSaveShowsTheNoticeUntilThatFileSaves() throws {
        let controller = launch()
        XCTAssertNil(controller.saveFailureNotice)
        try block("settings.json")
        controller.updateSettings { $0.showTimer.toggle() }
        XCTAssertEqual(controller.saveFailureNotice, "Some progress could not be saved. PureSudoku will keep trying.")
        try unblock("settings.json")
        controller.updateSettings { $0.showTimer.toggle() }
        XCTAssertNil(controller.saveFailureNotice)
    }

    func testASettingsSaveDoesNotClearAGameFailure() async throws {
        let controller = launch()
        try block("game_easy.json")
        await controller.startNewGame(for: .easy, mode: .seeded(1))
        controller.updateSettings { $0.showTimer.toggle() }
        XCTAssertEqual(controller.failedSaves, ["game_easy.json"])
        XCTAssertNotNil(controller.saveFailureNotice)
    }

    func testAHardGameSaveDoesNotClearAFailedEasySave() async throws {
        let controller = launch()
        try block("game_easy.json")
        await controller.startNewGame(for: .easy, mode: .seeded(1))
        await controller.startNewGame(for: .hard, mode: .seeded(2))
        XCTAssertEqual(controller.failedSaves, ["game_easy.json"])
        try unblock("game_easy.json")
        await controller.startNewGame(for: .easy, mode: .seeded(3))
        XCTAssertNil(controller.saveFailureNotice)
    }

    // MARK: Completion handoff (#72)

    private func assertCountedOnce(_ controller: AppController, time: Int = 300,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        for stats in [controller.stats, try XCTUnwrap(saved(Stats.self, "stats.json"))] {
            XCTAssertEqual(stats.totalPuzzlesSolved, 1, file: file, line: line)
            XCTAssertEqual(stats.solvedCount(for: .easy), 1, file: file, line: line)
            XCTAssertEqual(stats.solveTimes[.easy], [time], file: file, line: line)
        }
        XCTAssertEqual(try saved([PendingCompletion].self, "pending_completions.json") ?? [], [], file: file, line: line)
        XCTAssertEqual(try saved(GameState.self, "game_easy.json")?.counted, true, file: file, line: line)
    }

    func testAFailedStatsSaveIsRetriedAndCountedOnce() async throws {
        let controller = launch()
        try block("stats.json")
        _ = await playAndSolve(controller)
        XCTAssertEqual(try saved(GameState.self, "game_easy.json")?.counted, false, "not counted until the stats land")
        XCTAssertEqual(try saved([PendingCompletion].self, "pending_completions.json")?.count, 1)
        XCTAssertNotNil(controller.saveFailureNotice)
        try unblock("stats.json")
        controller.updateStats { _ in } // the next stats save retries
        try assertCountedOnce(controller)
        XCTAssertNil(controller.saveFailureNotice)
        try assertCountedOnce(launch())
    }

    func testStatsFailingTwiceThenWorkingCountsOnce() async throws {
        let controller = launch()
        try block("stats.json")
        _ = await playAndSolve(controller)
        controller.updateStats { $0.totalTimeSeconds += 0 }
        try unblock("stats.json")
        controller.updateStats { _ in }
        try assertCountedOnce(controller)
    }

    func testAFailedStatsSaveIsCountedOnceAtTheNextLaunch() async throws {
        let controller = launch()
        try block("stats.json")
        let viewModel = await playAndSolve(controller)
        viewModel.handleSceneDidDisappear() // the view model's own save says counted; the record still counts it
        try await Task.sleep(nanoseconds: 100_000_000)
        try unblock("stats.json")
        let relaunched = launch()
        try assertCountedOnce(relaunched)
        try assertCountedOnce(launch())
    }

    func testAFailedGameSaveIsCountedOnceAfterARelaunch() async throws {
        let controller = launch()
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        try block("game_easy.json")
        let viewModel = controller.makeGameViewModel(for: .easy)
        viewModel.handleSceneDidAppear()
        clock.advance(300)
        solve(viewModel)
        XCTAssertEqual(try saved(Stats.self, "stats.json")?.totalPuzzlesSolved, 1)
        XCTAssertEqual(try saved([PendingCompletion].self, "pending_completions.json")?.count, 1, "kept until the game is saved")
        try unblock("game_easy.json")
        controller.updateStats { _ in }
        try assertCountedOnce(controller)
        try assertCountedOnce(launch())
    }

    /// The moment after the stats saved but before the game did, as left on disk by a crash.
    func testAnInterruptedHandoffOnDiskIsCountedOnce() throws {
        let persistence = PersistenceManager(directory: dir)
        var game = GameState.newGame(for: TestData.puzzle)
        game.isCompleted = true
        game.elapsedSeconds = 300
        let pending = PendingCompletion(gameID: game.puzzle.id, difficulty: .easy, elapsedSeconds: 300, date: clock.now(),
                                        assisted: false, setsTimes: true, source: .generated)
        var stats = Stats()
        stats.apply(pending)
        try persistence.save(stats, to: "stats.json")
        try persistence.save(game, to: "game_easy.json")
        try persistence.save([pending], to: "pending_completions.json")
        try assertCountedOnce(launch())
        try assertCountedOnce(launch())
    }

    func testARestartAndANewGameBeforeTheRetryKeepTheOriginalTimeAndDate() async throws {
        let controller = launch()
        try block("stats.json")
        let solvedAt = clock.now() + 300
        let viewModel = await playAndSolve(controller)
        viewModel.resetPuzzle()
        clock.advance(3 * 86_400)
        await controller.startNewGame(for: .easy, mode: .seeded(8))
        try unblock("stats.json")
        controller.updateStats { _ in }
        XCTAssertEqual(controller.stats.solveTimes[.easy], [300])
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1)
        XCTAssertEqual(controller.stats.lastCompletionDate, Stats.playDay(solvedAt))
        XCTAssertEqual(try saved([PendingCompletion].self, "pending_completions.json"), [], "the replaced game needs no mark")
    }

    func testAnImportedSolveWithAFailedStatsSaveIsCountedOnce() throws {
        let controller = launch()
        let game = try XCTUnwrap(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid))
        try block("stats.json")
        let viewModel = try XCTUnwrap(controller.makeImportedGameViewModel(id: game.id))
        solve(viewModel)
        XCTAssertEqual(controller.importedGames.first?.gameState.counted, false)
        try unblock("stats.json")
        controller.updateStats { _ in }
        let relaunched = launch()
        XCTAssertEqual(relaunched.stats.importedPuzzlesSolved, 1)
        XCTAssertEqual(relaunched.stats.totalPuzzlesSolved, 1)
        XCTAssertEqual(relaunched.importedGames.first?.gameState.counted, true)
    }

    func testAnOldStatsFileAndOldCountedGamesCountNothingAgain() async throws {
        var stats = Stats(streakDays: 2, puzzlesSolved: [.easy: 4], totalPuzzlesSolved: 4, totalTimeSeconds: 1_000)
        stats.solveTimes = [.easy: [250]]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // as PersistenceManager writes
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(stats)) as? [String: Any])
        json["countedGameIDs"] = nil
        json["schemaVersion"] = nil
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json).write(to: dir.appendingPathComponent("stats.json"))
        let newGame = try encoder.encode(GameState.newGame(for: TestData.puzzle))
        var game = try XCTUnwrap(JSONSerialization.jsonObject(with: newGame) as? [String: Any])
        game["counted"] = nil // from before the counted flag: a completed save reads as counted
        game["isCompleted"] = true
        try JSONSerialization.data(withJSONObject: game).write(to: dir.appendingPathComponent("game_easy.json"))

        let controller = launch()
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 4)
        XCTAssertEqual(controller.stats.countedGameIDs, [])
        let viewModel = controller.makeGameViewModel(for: .easy)
        viewModel.resetPuzzle()
        viewModel.handleSceneDidAppear()
        clock.advance(100)
        solve(viewModel)
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 4, "a replay, not another solve")
        XCTAssertEqual(controller.stats.totalTimeSeconds, 1_100)
        XCTAssertEqual(controller.stats.solveTimes[.easy], [250])
        let statsData = try Data(contentsOf: dir.appendingPathComponent("stats.json"))
        let reencoded = try XCTUnwrap(JSONSerialization.jsonObject(with: statsData) as? [String: Any])
        XCTAssertEqual(reencoded["schemaVersion"] as? Int, 2)
    }

    /// Neither the record nor the stats land: the record is written again by the next stats save,
    /// even one that fails, and the view model's own save can't mark the game counted meanwhile.
    func testAFailedPendingWriteIsRetriedBeforeTheStats() async throws {
        let controller = launch()
        try block("pending_completions.json")
        try block("stats.json")
        let viewModel = await playAndSolve(controller)
        viewModel.handleSceneDidDisappear()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(try saved(GameState.self, "game_easy.json")?.counted, false)
        try unblock("pending_completions.json")
        controller.updateStats { _ in }
        XCTAssertEqual(try saved([PendingCompletion].self, "pending_completions.json")?.count, 1)
        try unblock("stats.json")
        try assertCountedOnce(launch())
    }

    /// Both the record and the stats fail, then the app quits: the next launch rebuilds the record
    /// from the finished, uncounted game, with its own time and date.
    func testARelaunchAfterTheRecordAndStatsBothFailedCountsOnce() async throws {
        let controller = launch()
        try block("pending_completions.json")
        try block("stats.json")
        let solvedAt = clock.now() + 300
        _ = await playAndSolve(controller)
        try unblock("pending_completions.json")
        try unblock("stats.json")
        clock.advance(2 * 86_400)
        let relaunched = launch()
        try assertCountedOnce(relaunched)
        XCTAssertEqual(relaunched.stats.lastCompletionDate, Stats.playDay(solvedAt))
        try assertCountedOnce(launch())
    }

    /// A finished, uncounted game from before `solvedAt` (whatever made it so) is never counted at
    /// launch: its solve may already be in the totals.
    func testAnOldFinishedUncountedGameIsNotCountedAtLaunch() throws {
        let persistence = PersistenceManager(directory: dir)
        try persistence.save(Stats(puzzlesSolved: [.easy: 4], totalPuzzlesSolved: 4, totalTimeSeconds: 1_000), to: "stats.json")
        for (file, source) in [("game_easy.json", GameSource.generated), ("imported_games.json", .imported)] {
            var puzzle = TestData.puzzle
            if source == .imported {
                puzzle = SudokuPuzzle(id: "old-import", difficulty: .easy, initialGrid: puzzle.initialGrid,
                                      solutionGrid: puzzle.solutionGrid, source: .imported, hasUniqueSolution: true)
            }
            var game = GameState.newGame(for: puzzle)
            game.isCompleted = true
            game.counted = false
            game.elapsedSeconds = 200
            if source == .imported {
                try persistence.save([ImportedGame(gameState: game)], to: file)
            } else {
                try persistence.save(game, to: file)
            }
        }
        let controller = launch()
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 4)
        XCTAssertEqual(controller.stats.totalTimeSeconds, 1_000)
        XCTAssertEqual(controller.stats.countedGameIDs, [])
        XCTAssertNil(try saved([PendingCompletion].self, "pending_completions.json"))
        XCTAssertEqual(launch().stats.totalPuzzlesSolved, 4)
    }

    /// Everything lands but the cleanup of the pending file: the next stats save retries it.
    func testAFailedPendingCleanupIsRetried() async throws {
        let controller = launch()
        try block("stats.json")
        _ = await playAndSolve(controller)
        try block("pending_completions.json")
        try unblock("stats.json")
        controller.updateStats { _ in }
        XCTAssertEqual(controller.failedSaves, ["pending_completions.json"])
        try unblock("pending_completions.json")
        controller.updateStats { _ in }
        XCTAssertNil(controller.saveFailureNotice)
        try assertCountedOnce(controller)
    }

    func testADamagedPendingFileShowsTheResetNotice() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("pending_completions.json"))
        XCTAssertEqual(launch().resetData, ["stats"])
    }

    func testARevealedSolveWritesNoPendingRecord() async throws {
        let controller = launch()
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        controller.makeGameViewModel(for: .easy).revealPuzzle()
        XCTAssertNil(try saved([PendingCompletion].self, "pending_completions.json"))
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 0)
    }
}
