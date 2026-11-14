import Foundation
import UIKit
import SwiftUI

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var settings: Settings
    @Published private(set) var stats: Stats
    @Published private(set) var activeGames: [Difficulty: GameState]
    @Published private(set) var importedGames: [ImportedGame]
    /// Per-technique learning progress (CODESPEC 13.4), keyed by `Technique.rawValue`.
    @Published private(set) var techniqueProgress: [String: TechniqueProgress]
    /// True when technique_progress.json could not be loaded: never overwrite it this session, and
    /// credit nothing (hints are still noted in memory).
    private var techniqueProgressLoadFailed = false
    /// Which moves may still earn credit (CODESPEC 13.4), saved with the progress (`LearningFile`).
    private(set) var learningLedger = LearningLedger()
    /// Files whose last save failed. An entry clears only when that same file saves again; while any
    /// is left, Home shows `saveFailureNotice` (CODESPEC 8).
    @Published private(set) var failedSaves: Set<String> = []
    /// Solves not yet both in the saved stats and saved as counted in their game (CODESPEC 8).
    private var pendingCompletions: [PendingCompletion] = []
    /// Set-aside copies (`name.corrupt-<time>.json`) the player has not yet acknowledged on Home
    /// (CODESPEC 8). Only acknowledged copy names are saved, in reset_notice.json.
    @Published private(set) var resetCopies: [String] = []
    /// The Night sheet, opened from the moon on any screen (CODESPEC 12.2).
    @Published var showsNightSheet = false
    /// Set by a game during Night, Hush and Goodnight. The root hides the home indicator for it, so
    /// the setting reaches the window from inside a pushed game.
    @Published var hidesHomeIndicator = false
    /// The first-night welcome → calibrate → result flow (CODESPEC 12.3).
    @Published private(set) var showsFirstNight = false
    /// This game's Drift steps, set by the game screen: the backlight follows the drifted glow.
    @Published var driftSteps = 0
    /// Find my lowest glow is on screen: the backlight sits at its minimum so the tiles show the
    /// palette layer alone (CODESPEC 12.3).
    @Published var isCalibrating = false

    /// The screen backlight Night wants now.
    var nightBacklight: CGFloat {
        PSPalette.backlight(glow: DriftController.apply(steps: driftSteps, to: settings).glow)
    }
    let afterDark: AfterDarkScheduler
    private var suppressesFirstNight = false

    private let persistence: PersistenceManager
    private let generatorService: SudokuGeneratorService
    private let puzzleRepository: SudokuPuzzleRepository
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider
    private let imageStore: ImportedImageStore
    /// Images saved for an import screen that has not created its game yet; never treated as orphans.
    private var pendingImageIDs: Set<String> = []
    /// True when imported_games.json could not be loaded. Its photos may still belong to the backup
    /// copy, so orphan cleanup is skipped for this session.
    private var importedGamesLoadFailed = false
    /// The image IDs the last orphan cleanup kept; cleanup runs again only when this set changes.
    private var cleanedImageIDs: Set<String>?
    /// Solved imports kept in imported_games.json; older solved ones are dropped (CODESPEC 8).
    static let keptSolvedImports = 20

    init(
        persistence: PersistenceManager = PersistenceManager(),
        puzzleRepository: SudokuPuzzleRepository? = nil,
        validator: SudokuValidator = SudokuValidator(),
        timeProvider: TimeProvider = SystemTimeProvider(),
        generatorService: SudokuGeneratorService = SudokuGeneratorService(),
        imageStore: ImportedImageStore = ImportedImageStore(),
        afterDark: AfterDarkScheduler? = nil
    ) {
        self.persistence = persistence
        self.generatorService = generatorService
        self.puzzleRepository = puzzleRepository ?? SudokuPuzzleRepository(generator: generatorService, validator: validator)
        self.validator = validator
        self.timeProvider = timeProvider
        self.imageStore = imageStore
        self.afterDark = afterDark ?? AfterDarkScheduler(clock: timeProvider)

        do {
            self.settings = try persistence.load(Settings.self, from: File.settings.rawValue) ?? .default
        } catch {
            self.settings = .default
        }
        do {
            self.stats = try persistence.load(Stats.self, from: File.stats.rawValue) ?? Stats()
        } catch {
            self.stats = Stats()
        }

        var games: [Difficulty: GameState] = [:]
        var gameLoadFailed = false
        for difficulty in Difficulty.allCases {
            do {
                if let state = try persistence.load(GameState.self, from: File.game(difficulty).rawValue) {
                    games[difficulty] = state
                }
            } catch {
                gameLoadFailed = true
            }
        }
        self.activeGames = games

        do {
            self.importedGames = try persistence.load([ImportedGame].self, from: File.importedGames.rawValue) ?? []
        } catch {
            self.importedGames = []
            self.importedGamesLoadFailed = true
        }
        do {
            let learning = try persistence.load(LearningFile.self, from: File.techniqueProgress.rawValue) ?? LearningFile()
            self.techniqueProgress = learning.progress
            self.learningLedger = learning.ledger
        } catch {
            self.techniqueProgress = [:]
            self.techniqueProgressLoadFailed = true
        }
        // A damaged file is set aside like the others; the reset notice then names the stats.
        pendingCompletions = (try? persistence.load([PendingCompletion].self, from: File.pendingCompletions.rawValue)) ?? []
        // Keys of finished or replaced games can't matter again: keep the file small. Only when every
        // saved game loaded and none was set aside as unreadable: that game may still be restored,
        // on this launch or a later one.
        let gameFiles = Difficulty.allCases.map { File.game($0).rawValue } + [File.importedGames.rawValue]
        // shortcut: a set-aside copy stops pruning until it is deleted; expire copies after 30 days if the file grows.
        let gamesMayReturn = gameLoadFailed || importedGamesLoadFailed || gameFiles.contains(where: persistence.hasSetAsideCopy)
        if !techniqueProgressLoadFailed && !gamesMayReturn {
            let before = learningLedger
            learningLedger.prune(keeping: Set(activeGames.values.map(\.puzzle.id) + importedGames.map(\.gameState.puzzle.id)))
            if learningLedger != before { saveLearning() }
        }
        loadResetNotice()
        countSolutionsOfOldImports()
        #if DEBUG
        // UI tests start past the first-night flow, whatever the simulator clock says.
        let arguments = ProcessInfo.processInfo.arguments
        suppressesFirstNight = arguments.contains("-uiTestSkipFirstNight")
        // UI tests only: start in Day, before the first night, to walk through that flow.
        if arguments.contains("-uiTestFirstNight") {
            settings.appearance = .day
            settings.calibrated = false
        }
        #endif
        self.afterDark.onBoundary = { [weak self] in self?.afterDarkBoundary() }
        self.afterDark.schedule(for: settings)
    }

    /// Imports saved before solution counting have no uniqueness flag. Count them off the main thread;
    /// until then `isUnique` is false, so uniqueness techniques stay off (CODESPEC 2.1).
    private func countSolutionsOfOldImports() {
        if !pendingCompletions.isEmpty { updateStats { _ in } } // handoffs an earlier launch could not finish
        settleLateTimes()
        let pending = importedGames.filter { $0.gameState.puzzle.hasUniqueSolution == nil }
            .map { (id: $0.id, values: $0.gameState.puzzle.initialGrid.map { Int(String($0)) ?? 0 }) }
        guard !pending.isEmpty else { return }
        Task {
            let counted = await Task.detached(priority: .utility) {
                pending.map { (id: $0.id, unique: SolutionCounter.count($0.values, limit: 2) == 1) }
            }.value
            for result in counted {
                guard let index = importedGames.firstIndex(where: { $0.id == result.id }) else { continue }
                importedGames[index].gameState.puzzle.hasUniqueSolution = result.unique
            }
            if !settleLateTimes() { persistImportedGames() } // the counts themselves
        }
    }

    /// Imports solved before their count finished (maybe before a relaunch) get their best and typical
    /// time once the count says unique. Stats record it by puzzle id first, so a retry is a no-op; only
    /// then is the waiting time cleared. Any failed or interrupted write is retried on the next launch,
    /// so a late time is neither lost nor added twice.
    /// Returns true if it saved the imports.
    @discardableResult
    private func settleLateTimes() -> Bool {
        let waiting = importedGames.filter { $0.gameState.timeAwaitingCount != nil && $0.gameState.puzzle.hasUniqueSolution != nil }
        guard !waiting.isEmpty else { return false }
        let late = waiting.filter { $0.gameState.puzzle.hasUniqueSolution == true }
        let saved = late.isEmpty || updateStats { stats in
            for game in late {
                stats.recordLateTime(id: game.id, for: game.gameState.puzzle.difficulty, time: game.gameState.timeAwaitingCount ?? 0)
            }
        }
        if saved {
            for game in waiting {
                if let index = importedGames.firstIndex(where: { $0.id == game.id }) { importedGames[index].gameState.timeAwaitingCount = nil }
            }
        }
        persistImportedGames()
        return true
    }

    func makeGameViewModel(for difficulty: Difficulty) -> GameViewModel {
        let state = activeGames[difficulty]! // This will now be safely set by startNewGame
        let viewModel = GameViewModel(state: state, settings: settings, validator: validator, timeProvider: timeProvider, hintService: generatorService)
        viewModel.onCompletion = { [weak self] completedState in
            self?.handleCompletion(state: completedState, difficulty: difficulty)
        }
        viewModel.onNewGame = { [weak self] in
            await self?.startNewGame(for: difficulty)
        }
        viewModel.onSave = { [weak self] updatedState in
            self?.persist(state: updatedState, for: difficulty)
        }
        viewModel.onTimeDiscarded = { [weak self] seconds in self?.updateStats { $0.totalTimeSeconds += seconds } }
        connectLearning(viewModel)
        return viewModel
    }

    /// The unfinished level game played most recently: Home's Continue card (CODESPEC 3.1).
    var continueGame: GameState? {
        activeGames.values.filter { !$0.isCompleted }.max { $0.lastUpdated < $1.lastUpdated }
    }

    /// A practice game from a lesson: not saved and not counted in stats, but it does count
    /// toward learning (CODESPEC 13.5).
    func makePracticeGameViewModel(_ entry: BundledPuzzles.Entry, number: Int) -> GameViewModel {
        let puzzle = SudokuPuzzle(
            // The whole grid: bundled puzzles can share a long prefix, and the id keys learning credit.
            // shortcut: these ledger keys are ~105 bytes and never pruned (practice comes back), so the
            // ledger nears 1 MB after ~100 practice puzzles fully played; upgrade to a short stable key
            // such as practice-<level>-<index> if that starts to matter.
            id: "practice-\(entry.initialGrid)", difficulty: entry.difficulty,
            initialGrid: entry.initialGrid, solutionGrid: entry.solutionGrid, hasUniqueSolution: true
        )
        var state = GameState.newGame(for: puzzle, now: timeProvider.now())
        #if DEBUG
        // UI tests only: fill all but one cell, so a test can reach the Solved panel (CODESPEC 8).
        if ProcessInfo.processInfo.arguments.contains("-uiTestNearlySolved") {
            let solution = Array(entry.solutionGrid)
            for index in state.cells.indices.filter({ state.cells[$0].value == nil }).dropFirst() {
                state.cells[index].value = Int(String(solution[index]))
            }
        }
        #endif
        let viewModel = GameViewModel(state: state, settings: settings,
                                      validator: validator, timeProvider: timeProvider, hintService: generatorService)
        viewModel.isPractice = true
        connectLearning(viewModel)
        return viewModel
    }

    /// Hidden Single (line) is part of the Hidden Single lesson: its progress, including saves that
    /// stored it on its own, counts as Hidden Single (box).
    func progress(for technique: Technique) -> TechniqueProgress {
        let technique = Self.lessonTechnique(technique)
        let own = techniqueProgress[technique.rawValue] ?? TechniqueProgress()
        guard technique == .hiddenSingleBox, let line = techniqueProgress[Technique.hiddenSingleLine.rawValue] else { return own }
        return own.merged(with: line)
    }

    private static func lessonTechnique(_ technique: Technique) -> Technique {
        technique == .hiddenSingleLine ? .hiddenSingleBox : technique
    }

    private func connectLearning(_ viewModel: GameViewModel) {
        // Games saved before the ledger name their hinted techniques only in the hint log.
        let puzzle = viewModel.state.puzzle.id
        var seeded = learningLedger
        for technique in viewModel.state.hintLog.compactMap({ Technique(rawValue: $0.technique) }) {
            seeded.recordHint(puzzle: puzzle, technique: Self.lessonTechnique(technique), changes: [])
        }
        if seeded != learningLedger {
            learningLedger = seeded
            saveLearning()
        }
        viewModel.onTechniqueFound = { [weak self] technique, puzzleID, move in
            guard let self, !techniqueProgressLoadFailed else { return }
            let technique = Self.lessonTechnique(technique)
            guard learningLedger.credit(move, technique: technique, puzzle: puzzleID) else { return }
            updateProgress(technique) { $0.recordFound(puzzleID: puzzleID, at: self.timeProvider.now()) }
        }
        viewModel.onHintShown = { [weak self] technique, changes, puzzleID in
            guard let self else { return }
            let technique = technique.map(Self.lessonTechnique)
            let before = learningLedger
            let first = learningLedger.recordHint(puzzle: puzzleID, technique: technique, changes: changes)
            // hintsSeen counts each technique once per puzzle.
            if let technique, first {
                updateProgress(technique) { $0.recordHint(at: self.timeProvider.now()) }
            } else if learningLedger != before {
                saveLearning()
            }
        }
    }

    /// Progress and ledger in one atomic write.
    private func saveLearning() {
        guard !techniqueProgressLoadFailed else { return }
        save(LearningFile(progress: techniqueProgress, ledger: learningLedger), to: .techniqueProgress)
    }

    private func updateProgress(_ technique: Technique, _ change: (inout TechniqueProgress) -> Void) {
        let technique = Self.lessonTechnique(technique)
        var progress = progress(for: technique)
        change(&progress)
        techniqueProgress[technique.rawValue] = progress
        // The line record is merged into the box one now; keeping both would count it twice.
        if technique == .hiddenSingleBox { techniqueProgress[Technique.hiddenSingleLine.rawValue] = nil }
        saveLearning()
    }

    func makeImportedGameViewModel(id: String) -> GameViewModel? {
        guard let index = importedGames.firstIndex(where: { $0.id == id }) else { return nil }
        let state = importedGames[index].gameState
        let viewModel = GameViewModel(state: state, settings: settings, validator: validator, timeProvider: timeProvider, hintService: generatorService)
        viewModel.onCompletion = { [weak self] completedState in
            self?.handleImportedCompletion(state: completedState, id: id)
        }
        viewModel.onSave = { [weak self] updatedState in
            self?.persistImported(state: updatedState, id: id)
        }
        viewModel.onTimeDiscarded = { [weak self] seconds in self?.updateStats { $0.totalTimeSeconds += seconds } }
        connectLearning(viewModel)
        return viewModel
    }

    /// Generates off the main thread (it can take a few hundred ms on older phones), then stores it.
    @discardableResult
    func startNewGame(for difficulty: Difficulty, mode: GenerationMode = .random) async -> GameState {
        let repository = puzzleRepository
        let puzzle = await Task.detached(priority: .userInitiated) {
            repository.generate(for: difficulty, mode: mode).puzzle
        }.value
        let newState = GameState.newGame(for: puzzle, now: timeProvider.now())
        // Time spent on an unfinished game it replaces still counts as played (the Journal total).
        if let old = activeGames[difficulty], !old.isCompleted, old.elapsedSeconds > 0 {
            updateStats { $0.totalTimeSeconds += old.elapsedSeconds }
        }
        activeGames[difficulty] = newState
        save(newState, to: .game(difficulty))
        return newState
    }

    @discardableResult
    func createImportedGame(initialGrid: String, imageID: String? = nil, date: Date = Date()) -> ImportedGame? {
        guard initialGrid.count == 81 else { return nil }
        guard let solution = generatorService.solve(initialGrid: initialGrid) else { return nil }
        let values = initialGrid.map { Int(String($0)) ?? 0 }
        // shortcut: counting and grading run on the main thread (about 20 ms on a Mac at worst, more on
        // old phones now that XY-Chain is tried); make this async like startNewGame if imports feel slow.
        // Level from the techniques needed; an import the solver can't finish is Master (CODESPEC 2.2).
        let unique = SolutionCounter.count(values, limit: 2) == 1
        let grade = PuzzleGrader.grade(values, allowsUniqueness: unique)?.grade
        let puzzle = SudokuPuzzle(
            id: UUID().uuidString,
            difficulty: grade?.difficulty ?? .master,
            initialGrid: initialGrid,
            solutionGrid: solution,
            grade: grade,
            source: .imported,
            importedAt: date,
            importImageID: imageID,
            hasUniqueSolution: unique
        )
        let gameState = GameState.newGame(for: puzzle, now: timeProvider.now())
        let imported = ImportedGame(gameState: gameState, createdAt: date, lastOpened: date)
        importedGames.append(imported)
        if let imageID { pendingImageIDs.remove(imageID) }
        persistImportedGames()
        return imported
    }

    // MARK: Display (CODESPEC 12)

    /// Night is worked out on read, so After dark follows the clock and Match iPhone the system setting.
    var isNight: Bool {
        afterDark.isNight(settings, systemIsDark: UIScreen.main.traitCollection.userInterfaceStyle == .dark)
    }
    var palette: PSPalette { settings.palette(isNight: isNight) }
    var preferredColorScheme: ColorScheme? { settings.preferredColorScheme(isNight: isNight) }
    /// Night always keeps sound and vibration off, whatever the saved settings say.
    /// Any future sound or haptic must check these, never `settings.soundsEnabled` / `hapticsEnabled`.
    var soundsActive: Bool { settings.soundsEnabled && !isNight }
    var hapticsActive: Bool { settings.hapticsEnabled && !isNight }

    /// Picking After dark (or sunset and sunrise) is the only thing that asks for location.
    func setAppearance(_ appearance: Appearance) {
        updateSettings { $0.appearance = appearance }
        if appearance == .afterDark && settings.useLocationForAfterDark { afterDark.requestLocation() }
    }

    func setUsesSunForAfterDark(_ on: Bool) {
        updateSettings { $0.useLocationForAfterDark = on }
        if on { afterDark.requestLocation() }
    }

    private func afterDarkBoundary() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { objectWillChange.send() }
        updateFirstNight()
    }

    // MARK: First night (CODESPEC 12.3)

    /// Shows the first-night flow the first time Night is active, until it is finished or skipped.
    func updateFirstNight() {
        guard !suppressesFirstNight, !showsFirstNight, !settings.calibrated, isNight else { return }
        showsFirstNight = true
        showsNightSheet = false // one modal at a time
    }

    /// "Use this" in Find my lowest glow: the pick is the floor. Glow starts at Lights out, or 4 above
    /// the floor if that is higher, so the first night isn't drawn at the edge of readable.
    func calibrate(pick: Double) {
        updateSettings {
            $0.glowFloor = pick
            $0.glow = min(100, max(NightPreset.lightsOut.glow, pick + 4))
            $0.calibrated = true
        }
    }

    /// "Skip for now — use Lights out".
    func skipFirstNight() {
        updateSettings {
            $0.apply(.lightsOut)
            $0.calibrated = true
        }
        showsFirstNight = false
    }

    /// "Start playing" on the result screen.
    func endFirstNight() {
        showsFirstNight = false
    }

    func updateSettings(_ block: (inout Settings) -> Void) {
        block(&settings)
        afterDark.schedule(for: settings)
        save(settings, to: .settings)
    }

    func saveImportedImage(_ image: UIImage) -> String? {
        guard settings.keepImportImages, let id = imageStore.save(image: image) else { return nil }
        pendingImageIDs.insert(id)
        return id
    }

    func removeImportedImage(id: String) {
        pendingImageIDs.remove(id)
        imageStore.delete(id: id)
    }

    func deleteImportedGame(id: String) {
        guard let index = importedGames.firstIndex(where: { $0.id == id }) else { return }
        importedGames.remove(at: index)
        persistImportedGames()
    }

    /// Unfinished imported games, most recently played first.
    var savedImports: [ImportedGame] {
        importedGames.filter { !$0.gameState.isCompleted }.sorted { $0.lastOpened > $1.lastOpened }
    }

    func clearImportedImages() {
        imageStore.clearAll()
    }

    /// Scans the image folder only when the set of images in use changed, not on every autosave.
    private func cleanupImportImages() {
        guard !importedGamesLoadFailed else { return }
        let ids = Set(importedGames.compactMap { $0.gameState.puzzle.importImageID }).union(pendingImageIDs)
        guard ids != cleanedImageIDs else { return }
        imageStore.removeOrphans(keeping: ids)
        cleanedImageIDs = ids
    }

    /// Every stats save also carries the pending solves (each counted once), and once it lands marks
    /// their games counted. Returns false if the stats file could not be written.
    @discardableResult
    func updateStats(_ block: (inout Stats) -> Void) -> Bool {
        block(&stats)
        for completion in pendingCompletions { stats.apply(completion) }
        let pendingFailed = failedSaves.contains(File.pendingCompletions.rawValue)
        // A record that never reached disk goes first: a stats save alone can't bring it back.
        if pendingFailed && !pendingCompletions.isEmpty { save(pendingCompletions, to: .pendingCompletions) }
        guard save(stats, to: .stats) else { return false }
        let before = pendingCompletions.count
        pendingCompletions.removeAll { markCounted($0.gameID) } // kept if its game could not be saved
        // Also when only the earlier cleanup failed: the file still holds the finished records.
        if pendingCompletions.count != before || pendingFailed { save(pendingCompletions, to: .pendingCompletions) }
        return true
    }

    /// Saves the game `gameID` as counted. True when saved, or when that game is gone (replaced or
    /// deleted): the saved stats then hold its id, so it can't count again.
    private func markCounted(_ gameID: String) -> Bool {
        if let difficulty = activeGames.first(where: { $0.value.puzzle.id == gameID })?.key,
           var game = activeGames[difficulty] {
            game.counted = true
            activeGames[difficulty] = game
            return save(game, to: .game(difficulty))
        }
        guard let index = importedGames.firstIndex(where: { $0.id == gameID }) else { return true }
        importedGames[index].gameState.counted = true
        return persistImportedGames(keeping: gameID)
    }

    /// Saves to `file` and tracks the outcome for `saveFailureNotice`. Returns false if it failed.
    @discardableResult
    private func save<T: Codable>(_ value: T, to file: File) -> Bool {
        do {
            try persistence.save(value, to: file.rawValue)
            if failedSaves.contains(file.rawValue) { failedSaves.remove(file.rawValue) } // no publish on every autosave
            return true
        } catch {
            failedSaves.insert(file.rawValue)
            return false
        }
    }

    /// The Home notice while any save is failing (CODESPEC 8). Saves retry on the next save to that file.
    var saveFailureNotice: String? {
        failedSaves.isEmpty ? nil : "Some progress could not be saved. PureSudoku will keep trying."
    }

    private func persist(state: GameState, for difficulty: Difficulty) {
        var state = state
        // The app, not the view model, says when a solve reached the saved stats.
        if let stored = activeGames[difficulty], stored.puzzle.id == state.puzzle.id { state.counted = stored.counted }
        state.lastUpdated = timeProvider.now() // the Continue card picks the game played last
        activeGames[difficulty] = state
        save(state, to: .game(difficulty))
    }

    /// The finished game is in memory before its solve is recorded, so the record can mark it counted.
    private func handleCompletion(state: GameState, difficulty: Difficulty) {
        activeGames[difficulty] = state
        record(state, at: difficulty)
        if let state = activeGames[difficulty] { save(state, to: .game(difficulty)) } // saved even if the stats failed
    }

    private func persistImported(state: GameState, id: String, saving: Bool = true) {
        guard let index = importedGames.firstIndex(where: { $0.id == id }) else { return }
        var state = state
        // An open game may predate the background solution count; keep the counted flag.
        if state.puzzle.hasUniqueSolution == nil {
            state.puzzle.hasUniqueSolution = importedGames[index].gameState.puzzle.hasUniqueSolution
        }
        // The view model's copy may be older; keep the stored time until the count clears it.
        state.timeAwaitingCount = state.timeAwaitingCount ?? importedGames[index].gameState.timeAwaitingCount
        if saving { state.counted = importedGames[index].gameState.counted } // as in persist(state:for:)
        importedGames[index].gameState = state
        importedGames[index].lastOpened = timeProvider.now()
        if saving { persistImportedGames(keeping: id) }
    }

    private func handleImportedCompletion(state: GameState, id: String) {
        var state = state
        // An open game may predate the background solution count: take uniqueness from the stored
        // import first, so a unique puzzle still sets times.
        if state.puzzle.hasUniqueSolution == nil {
            state.puzzle.hasUniqueSolution = importedGames.first { $0.id == id }?.gameState.puzzle.hasUniqueSolution
        }
        // Saved with the game, so a relaunch before the count ends still gets the time.
        if state.puzzle.hasUniqueSolution == nil, !state.counted, !stats.countedGameIDs.contains(id), !state.usedReveal, !state.assisted {
            state.timeAwaitingCount = state.elapsedSeconds
        }
        persistImported(state: state, id: id, saving: false) // in memory first, as in handleCompletion
        record(state, at: state.puzzle.difficulty)
        persistImportedGames(keeping: id)
    }

    /// Adds a solve to the stats once per puzzle (a restarted solve is already counted), through a
    /// `PendingCompletion` written first; the game is marked counted only once the stats are saved
    /// (CODESPEC 8). Puzzles with several solutions set no best or typical time.
    private func record(_ state: GameState, at difficulty: Difficulty) {
        guard !state.usedReveal else { return } // a revealed solve never reaches the stats
        let id = state.puzzle.id
        guard !state.counted, !stats.countedGameIDs.contains(id) else {
            // A replay of a counted puzzle: not another solve, but its time still counts as played.
            updateStats { $0.totalTimeSeconds += state.elapsedSeconds }
            if !state.counted { _ = markCounted(id) }
            return
        }
        pendingCompletions.append(PendingCompletion(
            gameID: id, difficulty: difficulty, elapsedSeconds: state.elapsedSeconds, date: timeProvider.now(),
            assisted: state.assisted, setsTimes: state.puzzle.isUnique, source: state.puzzle.source
        ))
        save(pendingCompletions, to: .pendingCompletions)
        updateStats { _ in }
    }

    /// Prunes old solved imports, saves the list, then removes images no game uses (only after a
    /// successful save). Returns false if the save failed.
    @discardableResult
    private func persistImportedGames(keeping savedID: String? = nil) -> Bool {
        pruneSolvedImports(keeping: savedID)
        guard save(importedGames, to: .importedGames) else { return false }
        cleanupImportImages()
        return true
    }
}

// MARK: Solved imports (CODESPEC 8)

extension AppController {
    /// Keeps every unfinished import, the one being saved (`savedID`, even if the clock moved), and
    /// only the `keptSolvedImports` most recently played other solved ones. A solved game still waiting
    /// to hand off its late time is kept on top, until its count finishes.
    fileprivate func pruneSolvedImports(keeping savedID: String?) {
        // A game still waiting to hand off its late time stays until it has (it would lose the time).
        let solved = importedGames.filter { $0.gameState.isCompleted && $0.id != savedID && $0.gameState.timeAwaitingCount == nil }
            .sorted { $0.lastOpened > $1.lastOpened }
        // The saved game is always kept; if it is solved it takes one of the slots.
        let savedIsSolved = importedGames.contains { $0.id == savedID && $0.gameState.isCompleted }
        let dropped = Set(solved.dropFirst(Self.keptSolvedImports - (savedIsSolved ? 1 : 0)).map(\.id))
        guard !dropped.isEmpty else { return }
        importedGames.removeAll { dropped.contains($0.id) }
    }
}

// MARK: Reset notice (CODESPEC 8)

extension AppController {
    /// Derives the notice from the set-aside copies on disk, minus those the player already
    /// acknowledged, so it cannot be lost when a save fails.
    fileprivate func loadResetNotice() {
        // A damaged acknowledgement file counts as nothing acknowledged.
        let acknowledged = Set((try? persistence.load([String].self, from: File.resetNotice.rawValue)) ?? [])
        resetCopies = persistence.setAsideCopies().filter { !acknowledged.contains($0) && File.dataName(forCopy: $0) != nil }
    }

    /// What was reset, in words, for the copies not yet acknowledged.
    var resetData: [String] {
        var names: [String] = []
        for name in resetCopies.compactMap(File.dataName(forCopy:)) where !names.contains(name) {
            names.append(name)
        }
        return names
    }

    /// The Home notice for `resetData`, or nil when there is nothing to tell.
    var resetNotice: String? {
        guard !resetData.isEmpty else { return nil }
        return "Some saved data couldn’t be read, so your \(resetData.formatted(.list(type: .and))) started over. "
            + "The old data was kept on this iPhone."
    }

    /// Saves every set-aside copy on disk as acknowledged. If that save fails, the notice shows
    /// again at the next launch.
    func dismissResetNotice() {
        resetCopies = []
        try? persistence.save(persistence.setAsideCopies(), to: File.resetNotice.rawValue)
    }
}

private enum File: RawRepresentable {
    typealias RawValue = String

    case settings
    case stats
    case game(Difficulty)
    case importedGames
    case techniqueProgress
    case resetNotice
    case pendingCompletions

    var rawValue: String {
        switch self {
        case .settings: return "settings.json"
        case .stats: return "stats.json"
        case let .game(difficulty): return "game_\(difficulty.rawValue).json"
        case .importedGames: return "imported_games.json"
        case .techniqueProgress: return "technique_progress.json"
        case .resetNotice: return "reset_notice.json"
        case .pendingCompletions: return "pending_completions.json"
        }
    }

    /// What the player lost when `copy` (`name.corrupt-<time>.json`) was set aside, in words for
    /// the reset notice.
    static func dataName(forCopy copy: String) -> String? {
        guard let range = copy.range(of: ".corrupt-") else { return nil }
        let fileName = String(copy[..<range.lowerBound]) + ".json"
        switch fileName {
        case File.settings.rawValue: return "settings"
        case File.stats.rawValue, File.pendingCompletions.rawValue: return "stats"
        case File.importedGames.rawValue: return "imported puzzles"
        case File.techniqueProgress.rawValue: return "learning progress"
        case _ where fileName.hasPrefix("game_"): return "saved games"
        default: return nil
        }
    }

    init?(rawValue: String) { return nil }
}
