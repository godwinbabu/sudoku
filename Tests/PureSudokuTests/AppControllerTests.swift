import XCTest
import UIKit
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

    func testImportsAreGradedAndFlaggedForUniqueness() async throws {
        let (controller, _) = makeTestController()
        let uniqueMade = await controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid)
        let unique = try XCTUnwrap(uniqueMade).gameState.puzzle
        XCTAssertEqual(unique.hasUniqueSolution, true)
        XCTAssertEqual(unique.difficulty, .easy)
        XCTAssertNotNil(unique.grade)

        let severalMade = await controller.createImportedGame(initialGrid: twoSolutionGrid)
        let several = try XCTUnwrap(severalMade).gameState.puzzle
        XCTAssertEqual(several.hasUniqueSolution, false)
        XCTAssertFalse(several.isUnique)
        XCTAssertNil(several.grade, "the solver can't finish a 9-clue puzzle")
        XCTAssertEqual(several.difficulty, .master, "beyond the solver: the top level")
    }

    /// The grid changed or the screen closed while the game was built: nothing is stored (issue 73).
    func testStaleImportIsNotSaved() async {
        let (controller, _) = makeTestController()
        let made = await controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid, isCurrent: { false })
        XCTAssertNil(made)
        XCTAssertTrue(controller.importedGames.isEmpty)
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
        let viewModel = controller.makeGameViewModel(for: .easy)!
        viewModel.revealPuzzle()
        viewModel.resetPuzzle()
        XCTAssertEqual(controller.activeGames[.easy]?.isCompleted, false)
        XCTAssertEqual(controller.stats, Stats(), "revealed games do not count")
    }

    /// A route whose game is gone resolves to no game, never to another level's game.
    func testMissingGamesResolveToNoGame() async {
        let (controller, _) = makeTestController()
        let menu = MainMenuViewModel(controller: controller)
        XCTAssertNil(menu.routeGame(importID: nil, difficulty: .easy), "no Easy game yet")
        await controller.startNewGame(for: .easy, mode: .seeded(1))
        XCTAssertNil(menu.routeGame(importID: "missing", difficulty: .easy), "a missing import never opens the Easy game")
        XCTAssertEqual(menu.routeGame(importID: nil, difficulty: .easy)?.state.puzzle.id, controller.activeGames[.easy]?.puzzle.id)
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
        let easy = controller.makeGameViewModel(for: .easy)!
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
        let started = await menu.startNewGame(for: .easy)!
        XCTAssertNotEqual(started.state.puzzle.id, before, "a level row always starts a new puzzle")
        XCTAssertTrue(started.state.cells.allSatisfy { $0.given || $0.value == nil })

        controller.makeGameViewModel(for: .hard)!.revealPuzzle()
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

    // MARK: Reset notice (#36)

    func testDamagedStatsShowResetNoticeOnceUntilDismissed() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("stats.json"))
        try Data("not json".utf8).write(to: dir.appendingPathComponent("technique_progress.json"))
        let launch = { AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider()) }

        let first = launch()
        XCTAssertEqual(first.resetData, ["stats", "learning progress"])
        XCTAssertEqual(first.resetNotice, "Some saved data couldn’t be read, so your stats and learning progress started over. "
                       + "The old data was kept on this iPhone.")
        XCTAssertEqual(launch().resetData, ["stats", "learning progress"], "kept until dismissed")

        launch().dismissResetNotice()
        let after = launch()
        XCTAssertTrue(after.resetData.isEmpty, "each incident is shown once")
        XCTAssertNil(after.resetNotice)
    }

    /// The notice comes from the set-aside copies on disk, so a failed save cannot lose it (#53).
    func testResetNoticeSurvivesAFailedAcknowledgement() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("stats.json"))
        let launch = { AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider()) }
        let ackFile = dir.appendingPathComponent("reset_notice.json")
        // A folder in place of the acknowledgement file: it cannot be read, so saving it fails.
        try FileManager.default.createDirectory(at: ackFile, withIntermediateDirectories: true)

        let first = launch()
        XCTAssertEqual(first.resetData, ["stats"])
        first.dismissResetNotice()
        XCTAssertNil(first.resetNotice)
        XCTAssertEqual(launch().resetData, ["stats"], "a failed acknowledgement shows the notice again")

        try FileManager.default.removeItem(at: ackFile)
        launch().dismissResetNotice()
        XCTAssertNil(launch().resetNotice, "acknowledged")

        try Data("not json".utf8).write(to: dir.appendingPathComponent("settings.json"))
        let later = launch()
        XCTAssertEqual(later.resetData, ["settings"], "a new corruption shows only the new copy")
        XCTAssertEqual(later.resetCopies.count, 1)
    }

    func testDamagedAcknowledgementFileCountsAsNothingAcknowledged() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("stats.json"))
        let launch = { AppController(persistence: PersistenceManager(directory: dir), timeProvider: MockTimeProvider()) }
        launch().dismissResetNotice()
        try Data("not json".utf8).write(to: dir.appendingPathComponent("reset_notice.json"))

        XCTAssertEqual(launch().resetData, ["stats"])
    }

    func testCleanLaunchHasNoResetNotice() {
        let (controller, _) = makeTestController()
        XCTAssertNil(controller.resetNotice)
    }

    // MARK: Imported games pruning (#38)

    private func importedGame(_ index: Int, solved: Bool, imageID: String?, opened: Date) -> ImportedGame {
        let puzzle = SudokuPuzzle(id: "import-\(index)", difficulty: .easy, initialGrid: TestData.puzzle.initialGrid,
                                  solutionGrid: TestData.puzzle.solutionGrid, source: .imported,
                                  importImageID: imageID, hasUniqueSolution: true)
        var state = GameState.newGame(for: puzzle)
        state.isCompleted = solved
        return ImportedGame(gameState: state, createdAt: opened, lastOpened: opened)
    }

    func testSavingImportsKeepsUnfinishedAndNewestSolved() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let imagesDir = dir.appendingPathComponent("ImportedImages", isDirectory: true)
        let store = ImportedImageStore(directory: imagesDir)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let base = Date(timeIntervalSince1970: 1_000_000)
        // 25 solved (index 0 oldest) and one unfinished game opened before all of them.
        var games = try (0..<25).map { index in
            importedGame(index, solved: true, imageID: try XCTUnwrap(store.save(image: image)),
                         opened: base + Double(index) * 60)
        }
        let unfinishedImage = try XCTUnwrap(store.save(image: image))
        games.append(importedGame(99, solved: false, imageID: unfinishedImage, opened: base - 3600))
        let persistence = PersistenceManager(directory: dir)
        try persistence.save(games, to: "imported_games.json")

        let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(), imageStore: store)
        let made = await controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid)
        XCTAssertNotNil(made)

        let saved = try XCTUnwrap(persistence.load([ImportedGame].self, from: "imported_games.json"))
        let solvedIDs = Set(saved.filter(\.gameState.isCompleted).map(\.id))
        XCTAssertEqual(solvedIDs, Set((5..<25).map { "import-\($0)" }), "the 20 newest solved are kept")
        XCTAssertTrue(saved.contains { $0.id == "import-99" }, "unfinished imports are never pruned")
        XCTAssertEqual(saved.count, 22)
        let imageExists = { (id: String) in FileManager.default.fileExists(atPath: imagesDir.appendingPathComponent("\(id).jpg").path) }
        XCTAssertTrue(imageExists(unfinishedImage))
        for game in games {
            let id = try XCTUnwrap(game.gameState.puzzle.importImageID)
            XCTAssertEqual(imageExists(id), saved.contains { $0.id == game.id }, "only images of kept games survive")
        }
    }

    /// A solved import whose late time is still waiting is never pruned, so the time can't be lost.
    func testPruningKeepsAnImportWaitingForItsLateTime() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_000_000)
        var games = (0..<20).map { importedGame($0, solved: true, imageID: nil, opened: now + Double($0)) }
        var waiting = importedGame(99, solved: true, imageID: nil, opened: now - 86_400) // the oldest
        waiting.gameState.timeAwaitingCount = 120
        waiting.gameState.puzzle.hasUniqueSolution = nil // its count hasn't finished yet
        games.append(waiting)
        games.append(importedGame(100, solved: false, imageID: nil, opened: now))
        let persistence = PersistenceManager(directory: dir)
        try persistence.save(games, to: "imported_games.json")
        let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(date: now))
        let viewModel = try XCTUnwrap(controller.makeImportedGameViewModel(id: "import-100"))
        viewModel.onSave?(viewModel.state) // saving another game prunes, before the count can finish

        let saved = try XCTUnwrap(persistence.load([ImportedGame].self, from: "imported_games.json"))
        XCTAssertTrue(saved.contains { $0.id == "import-99" }, "the waiting game stays until its time is handed off")
    }

    /// The import being saved is kept even when 20 others look newer because the clock moved back.
    func testSavingASolvedImportKeepsItWhenOthersAreDatedInTheFuture() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_000_000)
        var games = (0..<20).map { importedGame($0, solved: true, imageID: nil, opened: now + 86_400 + Double($0)) }
        games.append(importedGame(50, solved: true, imageID: nil, opened: now - 60))
        let persistence = PersistenceManager(directory: dir)
        try persistence.save(games, to: "imported_games.json")
        let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(date: now))

        let viewModel = try XCTUnwrap(controller.makeImportedGameViewModel(id: "import-50"))
        viewModel.onSave?(viewModel.state)

        let saved = try XCTUnwrap(persistence.load([ImportedGame].self, from: "imported_games.json"))
        XCTAssertTrue(saved.contains { $0.id == "import-50" }, "the game being saved is never pruned")
        XCTAssertEqual(saved.filter { $0.gameState.isCompleted }.count, 20, "it takes one of the 20 solved slots")
    }

    func testAutosaveOfAnImportDoesNotScanImages() async throws {
        let (controller, dir) = makeTestController()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let imageID = try XCTUnwrap(controller.saveImportedImage(image))
        let gameMade = await controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid, imageID: imageID)
        let game = try XCTUnwrap(gameMade)
        let stray = dir.appendingPathComponent("ImportedImages/stray.jpg")
        try Data([0]).write(to: stray)

        let viewModel = try XCTUnwrap(controller.makeImportedGameViewModel(id: game.id))
        viewModel.onSave?(viewModel.state)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stray.path), "an autosave leaves the image folder alone")

        controller.deleteImportedGame(id: game.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stray.path), "a change to the imports cleans up")
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
        let viewModel = controller.makeGameViewModel(for: .easy)!
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
        let viewModel = controller.makeGameViewModel(for: .easy)!
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
        state.checkedWrong = [state.cells[index].id]
        let viewModel = GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
        viewModel.apply(settings: settings)
        XCTAssertTrue(viewModel.state.cells[index].isError)
    }

    private func reopen(_ state: GameState, settings: Settings) throws -> GameViewModel {
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        let viewModel = GameViewModel(state: saved, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
        viewModel.apply(settings: settings)
        return viewModel
    }

    /// Right away: a wrong digit with no duplicate is marked only by Check, and the mark survives a reopen.
    func testCheckMarkUnderRightAwaySurvivesReopen() throws {
        var settings = Settings()
        settings.mistakes = .immediate
        let state = TestData.newGameState()
        let solution = Array(state.puzzle.solutionGrid).map { Int(String($0))! }
        // An empty cell and a wrong digit that no peer holds, so only Check can mark it.
        let (cell, digit) = try XCTUnwrap(state.cells.lazy.filter { $0.value == nil }.compactMap { cell -> (SudokuCell, Int)? in
            let peerValues = Set(state.cells.filter { Board.peers[cell.index].contains($0.index) }.compactMap(\.value))
            return (1...9).first { $0 != solution[cell.index] && !peerValues.contains($0) }.map { (cell, $0) }
        }.first)
        let viewModel = GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
        viewModel.select(cell: cell)
        viewModel.setDigit(digit)
        viewModel.checkCell()
        XCTAssertTrue(viewModel.state.cells[cell.index].isError)

        let reopened = try reopen(viewModel.state, settings: settings)
        XCTAssertTrue(reopened.state.cells[cell.index].isError, "the Check mark is saved with the game")
    }

    /// Duplicates marked under Right away are not Check marks: after a switch to When I check and a
    /// reopen, neither shows, and erasing the wrong one leaves nothing marked.
    func testAutoMarksDoNotBecomeCheckMarksOnReopen() throws {
        var settings = Settings()
        settings.mistakes = .immediate
        let state = TestData.newGameState()
        let solution = Array(state.puzzle.solutionGrid).map { Int(String($0))! }
        let row = try XCTUnwrap((0..<9).first { row in state.cells.filter { $0.row == row && $0.value == nil }.count >= 2 })
        let empties = state.cells.filter { $0.row == row && $0.value == nil }
        let (right, wrong) = (empties[0], empties[1])
        let viewModel = GameViewModel(state: state, settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
        for cell in [right, wrong] {
            viewModel.select(cell: cell)
            viewModel.setDigit(solution[right.index])
        }
        XCTAssertTrue(viewModel.state.cells[right.index].isError)
        XCTAssertTrue(viewModel.state.cells[wrong.index].isError)

        settings.mistakes = .onCheck
        let reopened = try reopen(viewModel.state, settings: settings)
        XCTAssertFalse(reopened.state.cells[wrong.index].isError, "no Check was done")
        XCTAssertFalse(reopened.state.cells[right.index].isError)
        reopened.select(cell: reopened.state.cells[wrong.index])
        reopened.clearSelectedCell()
        XCTAssertFalse(reopened.state.cells[right.index].isError)
    }

    /// An import solved before its background count finished gets its time once the count says unique.
    func testImportSolvedBeforeItsCountGetsItsTime() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = PersistenceManager(directory: dir)
        let puzzle = SudokuPuzzle(id: "old-unique", difficulty: .easy, initialGrid: TestData.puzzle.initialGrid,
                                  solutionGrid: TestData.puzzle.solutionGrid, source: .imported)
        try persistence.save([ImportedGame(gameState: GameState.newGame(for: puzzle))], to: "imported_games.json")
        let clock = AdvancingTimeProvider()
        let controller = AppController(persistence: persistence, timeProvider: clock,
                                       imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
        // No await before the solve, so the count is still pending.
        let viewModel = try XCTUnwrap(controller.makeImportedGameViewModel(id: try XCTUnwrap(controller.importedGames.first?.id)))
        viewModel.handleSceneDidAppear()
        clock.advance(120)
        solve(viewModel)
        XCTAssertTrue(viewModel.state.isCompleted)
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1)
        XCTAssertNil(controller.stats.bestTime(for: .easy), "uniqueness not known yet")

        for _ in 0..<100 where controller.importedGames.first?.gameState.puzzle.hasUniqueSolution == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.importedGames.first?.gameState.puzzle.hasUniqueSolution, true)
        XCTAssertEqual(controller.stats.bestTime(for: .easy), 120)
        XCTAssertEqual(controller.stats.solveTimes[.easy], [120])
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1, "not another solve")
    }

    /// Quit after solving but before the count: the time is still added on the next launch.
    func testPendingImportTimeSurvivesARelaunch() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = PersistenceManager(directory: dir)
        let puzzle = SudokuPuzzle(id: "old-unique", difficulty: .easy, initialGrid: TestData.puzzle.initialGrid,
                                  solutionGrid: TestData.puzzle.solutionGrid, source: .imported)
        var solved = GameState.newGame(for: puzzle)
        solved.cells = solved.cells.map { cell in
            var cell = cell
            cell.value = Int(String(Array(puzzle.solutionGrid)[cell.index]))
            return cell
        }
        solved.isCompleted = true
        solved.counted = true
        solved.elapsedSeconds = 120
        solved.timeAwaitingCount = 120
        solved.elapsedSeconds = 5 // a replay since: the saved solve time still wins
        try persistence.save([ImportedGame(gameState: solved)], to: "imported_games.json")
        let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(),
                                       imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
        for _ in 0..<100 where controller.importedGames.first?.gameState.puzzle.hasUniqueSolution == nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.stats.bestTime(for: .easy), 120)
        XCTAssertNil(controller.importedGames.first?.gameState.timeAwaitingCount, "added once")
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 0, "the solve was counted before the quit")
    }

    /// Interrupted after the count saved uniqueness but before the time was handed off: the next
    /// launch finishes it, once (stats already holding the id means it was recorded).
    func testAnInterruptedHandoffFinishesOnce() async throws {
        for (alreadyRecorded, countSaved) in [(false, true), (true, true), (true, false)] {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let persistence = PersistenceManager(directory: dir)
            var puzzle = SudokuPuzzle(id: "old-unique", difficulty: .easy, initialGrid: TestData.puzzle.initialGrid,
                                      solutionGrid: TestData.puzzle.solutionGrid, source: .imported)
            puzzle.hasUniqueSolution = countSaved ? true : nil // false: the app died before the count was saved
            var solved = GameState.newGame(for: puzzle)
            solved.isCompleted = true
            solved.counted = true
            solved.timeAwaitingCount = 120
            let game = ImportedGame(gameState: solved)
            try persistence.save([game], to: "imported_games.json")
            if alreadyRecorded {
                var stats = Stats()
                stats.recordLateTime(id: game.id, for: .easy, time: 120)
                try persistence.save(stats, to: "stats.json")
            }
            let controller = AppController(persistence: persistence, timeProvider: MockTimeProvider(),
                                           imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true)))
            for _ in 0..<100 where controller.importedGames.first?.gameState.timeAwaitingCount != nil {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            XCTAssertEqual(controller.stats.solveTimes[.easy], [120], "once (recorded \(alreadyRecorded), count saved \(countSaved))")
            XCTAssertNil(controller.importedGames.first?.gameState.timeAwaitingCount)
        }
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

    func testRevealThenRestartThenSolveCountsOnce() async {
        let (controller, _) = makeTestController()
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        let viewModel = controller.makeGameViewModel(for: .easy)!
        viewModel.revealPuzzle()
        XCTAssertFalse(viewModel.state.counted, "a revealed solve never reached the stats")
        viewModel.resetPuzzle()
        solve(viewModel)
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1, "the honest solve after a reveal counts")
    }

    func testAReplayAndARestartKeepTheirPlayedTime() async {
        let clock = AdvancingTimeProvider()
        let (controller, _) = makeTestController(timeProvider: clock)
        await controller.startNewGame(for: .easy, mode: .seeded(7))
        let viewModel = controller.makeGameViewModel(for: .easy)!
        viewModel.handleSceneDidAppear()
        clock.advance(300)
        solve(viewModel)
        XCTAssertEqual(controller.stats.totalTimeSeconds, 300)
        viewModel.resetPuzzle()
        clock.advance(120)
        solve(viewModel)
        XCTAssertEqual(controller.stats.totalTimeSeconds, 420, "the replay's time counts, not another solve")
        XCTAssertEqual(controller.stats.totalPuzzlesSolved, 1)
        viewModel.resetPuzzle()
        clock.advance(50)
        viewModel.resetPuzzle()
        XCTAssertEqual(controller.stats.totalTimeSeconds, 470, "Restart of an unfinished game keeps its time")
    }

    /// Right away marks conflicts; a reopened game must not turn them into permanent Check marks.
    func testReopenedConflictMarksClearWhenFixed() {
        var state = TestData.newGameState()
        let solution = Array(state.puzzle.solutionGrid).map { Int(String($0))! }
        let row = state.cells.filter { $0.row == 0 && $0.value == nil }
        let (a, b) = (state.cells.firstIndex { $0.id == row[0].id }!, state.cells.firstIndex { $0.id == row[1].id }!)
        state.cells[a].value = solution[state.cells[a].index] // correct
        state.cells[b].value = solution[state.cells[a].index] // same digit: a conflict, marks both
        state.cells[a].isError = true
        state.cells[b].isError = true
        let viewModel = GameViewModel(state: state, settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider())
        viewModel.select(cell: viewModel.state.cells[b])
        viewModel.clearSelectedCell()
        XCTAssertFalse(viewModel.state.cells[a].isError, "the correct digit is no longer marked")
    }
}
