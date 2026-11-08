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
    @Published var lastPersistenceError: (any Error)?
    /// The Night sheet, opened from the moon on any screen (CODESPEC 12.2).
    @Published var showsNightSheet = false
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
            self.lastPersistenceError = error
        }
        do {
            self.stats = try persistence.load(Stats.self, from: File.stats.rawValue) ?? Stats()
        } catch {
            self.stats = Stats()
            self.lastPersistenceError = error
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
                self.lastPersistenceError = error
            }
        }
        self.activeGames = games

        do {
            self.importedGames = try persistence.load([ImportedGame].self, from: File.importedGames.rawValue) ?? []
        } catch {
            self.importedGames = []
            self.importedGamesLoadFailed = true
            self.lastPersistenceError = error
        }
        do {
            let learning = try persistence.load(LearningFile.self, from: File.techniqueProgress.rawValue) ?? LearningFile()
            self.techniqueProgress = learning.progress
            self.learningLedger = learning.ledger
        } catch {
            self.techniqueProgress = [:]
            self.techniqueProgressLoadFailed = true
            self.lastPersistenceError = error
        }
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
        settleLateTimes() // a handoff an earlier launch could not finish
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
        do {
            try persistence.save(LearningFile(progress: techniqueProgress, ledger: learningLedger), to: File.techniqueProgress.rawValue)
        } catch {
            lastPersistenceError = error
        }
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
        do {
            try persistence.save(newState, to: File.game(difficulty).rawValue)
        } catch {
            self.lastPersistenceError = error
        }
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
        do {
            try persistence.save(settings, to: File.settings.rawValue)
        } catch {
            lastPersistenceError = error
        }
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

    private func cleanupImportImages() {
        guard !importedGamesLoadFailed else { return }
        let ids = Set(importedGames.compactMap { $0.gameState.puzzle.importImageID })
        imageStore.removeOrphans(keeping: ids.union(pendingImageIDs))
    }

    /// Returns false if the stats file could not be written.
    @discardableResult
    func updateStats(_ block: (inout Stats) -> Void) -> Bool {
        block(&stats)
        do {
            try persistence.save(stats, to: File.stats.rawValue)
            return true
        } catch {
            lastPersistenceError = error
            return false
        }
    }

    private func persist(state: GameState, for difficulty: Difficulty) {
        var state = state
        state.lastUpdated = timeProvider.now() // the Continue card picks the game played last
        activeGames[difficulty] = state
        do {
            try persistence.save(state, to: File.game(difficulty).rawValue)
        } catch {
            self.lastPersistenceError = error
        }
    }

    private func handleCompletion(state: GameState, difficulty: Difficulty) {
        var state = state
        record(state, at: difficulty)
        if !state.usedReveal { state.counted = true }
        activeGames[difficulty] = state
        do {
            try persistence.save(state, to: File.game(difficulty).rawValue)
        } catch {
            self.lastPersistenceError = error
        }
    }

    private func persistImported(state: GameState, id: String) {
        guard let index = importedGames.firstIndex(where: { $0.id == id }) else { return }
        var state = state
        // An open game may predate the background solution count; keep the counted flag.
        if state.puzzle.hasUniqueSolution == nil {
            state.puzzle.hasUniqueSolution = importedGames[index].gameState.puzzle.hasUniqueSolution
        }
        // The view model's copy may be older; keep the stored time until the count clears it.
        state.timeAwaitingCount = state.timeAwaitingCount ?? importedGames[index].gameState.timeAwaitingCount
        importedGames[index].gameState = state
        importedGames[index].lastOpened = timeProvider.now()
        persistImportedGames()
    }

    private func handleImportedCompletion(state: GameState, id: String) {
        var state = state
        // An open game may predate the background solution count: take uniqueness from the stored
        // import first, so a unique puzzle still sets times.
        if state.puzzle.hasUniqueSolution == nil {
            state.puzzle.hasUniqueSolution = importedGames.first { $0.id == id }?.gameState.puzzle.hasUniqueSolution
        }
        // Saved with the game, so a relaunch before the count ends still gets the time.
        if state.puzzle.hasUniqueSolution == nil, !state.counted, !state.usedReveal, !state.assisted {
            state.timeAwaitingCount = state.elapsedSeconds
        }
        record(state, at: state.puzzle.difficulty)
        if !state.usedReveal { state.counted = true }
        persistImported(state: state, id: id)
    }

    /// Adds a solve to the stats once per puzzle (a restarted solve is already counted). Puzzles with
    /// several solutions set no best or typical time.
    private func record(_ state: GameState, at difficulty: Difficulty) {
        guard !state.counted else {
            // A replay of a counted puzzle: not another solve, but its time still counts as played.
            if !state.usedReveal { updateStats { $0.totalTimeSeconds += state.elapsedSeconds } }
            return
        }
        updateStats { stats in
            stats.recordCompletion(
                for: difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal,
                assisted: state.assisted, setsTimes: state.puzzle.isUnique, source: state.puzzle.source,
                date: self.timeProvider.now()
            )
        }
    }

    /// Saves the imported list, then removes images no game uses (only after a successful save).
    @discardableResult
    private func persistImportedGames() -> Bool {
        do {
            try persistence.save(importedGames, to: File.importedGames.rawValue)
        } catch {
            self.lastPersistenceError = error
            return false
        }
        cleanupImportImages()
        return true
    }
}

private enum File: RawRepresentable {
    typealias RawValue = String

    case settings
    case stats
    case game(Difficulty)
    case importedGames
    case techniqueProgress

    var rawValue: String {
        switch self {
        case .settings: return "settings.json"
        case .stats: return "stats.json"
        case let .game(difficulty): return "game_\(difficulty.rawValue).json"
        case .importedGames: return "imported_games.json"
        case .techniqueProgress: return "technique_progress.json"
        }
    }

    init?(rawValue: String) { return nil }
}
