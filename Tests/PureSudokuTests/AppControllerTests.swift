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

    func testSavingImportsKeepsUnfinishedAndNewestSolved() throws {
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
        XCTAssertNotNil(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid))

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
    }

    func testAutosaveOfAnImportDoesNotScanImages() throws {
        let (controller, dir) = makeTestController()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let imageID = try XCTUnwrap(controller.saveImportedImage(image))
        let game = try XCTUnwrap(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid, imageID: imageID))
        let stray = dir.appendingPathComponent("ImportedImages/stray.jpg")
        try Data([0]).write(to: stray)

        let viewModel = try XCTUnwrap(controller.makeImportedGameViewModel(id: game.id))
        viewModel.onSave?(viewModel.state)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stray.path), "an autosave leaves the image folder alone")

        controller.deleteImportedGame(id: game.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stray.path), "a change to the imports cleans up")
    }
}
