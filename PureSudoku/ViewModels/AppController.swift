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
    /// Set-aside copies (`name.corrupt-<time>.json`) the player has not yet acknowledged on Home
    /// (CODESPEC 8). Only acknowledged copy names are saved, in reset_notice.json.
    @Published private(set) var resetCopies: [String] = []
    /// The Night sheet, opened from the moon on any screen (CODESPEC 12.2).
    @Published var showsNightSheet = false
    /// The first-night welcome → calibrate → result flow (CODESPEC 12.3).
    @Published private(set) var showsFirstNight = false
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
            persistImportedGames()
        }
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

    /// "Use this" in Find my lowest glow: the pick is the floor, and glow starts 4 above it.
    func calibrate(pick: Double) {
        updateSettings {
            $0.glowFloor = pick
            $0.glow = min(100, pick + 4)
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

    /// Scans the image folder only when the set of images in use changed, not on every autosave.
    private func cleanupImportImages() {
        guard !importedGamesLoadFailed else { return }
        let ids = Set(importedGames.compactMap { $0.gameState.puzzle.importImageID }).union(pendingImageIDs)
        guard ids != cleanedImageIDs else { return }
        imageStore.removeOrphans(keeping: ids)
        cleanedImageIDs = ids
    }

    func updateStats(_ block: (inout Stats) -> Void) {
        block(&stats)
        do {
            try persistence.save(stats, to: File.stats.rawValue)
        } catch {
            lastPersistenceError = error
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
        updateStats { stats in
            stats.recordCompletion(for: difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal, assisted: state.assisted, source: state.puzzle.source, date: self.timeProvider.now())
        }
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
        importedGames[index].gameState = state
        importedGames[index].lastOpened = timeProvider.now()
        persistImportedGames(keeping: id)
    }

    private func handleImportedCompletion(state: GameState, id: String) {
        updateStats { stats in
            stats.recordCompletion(
                for: state.puzzle.difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal,
                assisted: state.assisted, source: state.puzzle.source, date: self.timeProvider.now()
            )
        }
        persistImported(state: state, id: id)
    }

    /// Prunes old solved imports, saves the list, then removes images no game uses (only after a
    /// successful save).
    private func persistImportedGames(keeping savedID: String? = nil) {
        pruneSolvedImports(keeping: savedID)
        do {
            try persistence.save(importedGames, to: File.importedGames.rawValue)
        } catch {
            self.lastPersistenceError = error
            return
        }
        cleanupImportImages()
    }
}

// MARK: Solved imports (CODESPEC 8)

extension AppController {
    /// Keeps every unfinished import, the one being saved (`savedID`, even if the clock moved), and
    /// only the `keptSolvedImports` most recently played other solved ones.
    fileprivate func pruneSolvedImports(keeping savedID: String?) {
        let solved = importedGames.filter { $0.gameState.isCompleted && $0.id != savedID }
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

    var rawValue: String {
        switch self {
        case .settings: return "settings.json"
        case .stats: return "stats.json"
        case let .game(difficulty): return "game_\(difficulty.rawValue).json"
        case .importedGames: return "imported_games.json"
        case .techniqueProgress: return "technique_progress.json"
        case .resetNotice: return "reset_notice.json"
        }
    }

    /// What the player lost when `copy` (`name.corrupt-<time>.json`) was set aside, in words for
    /// the reset notice.
    static func dataName(forCopy copy: String) -> String? {
        guard let range = copy.range(of: ".corrupt-") else { return nil }
        let fileName = String(copy[..<range.lowerBound]) + ".json"
        switch fileName {
        case File.settings.rawValue: return "settings"
        case File.stats.rawValue: return "stats"
        case File.importedGames.rawValue: return "imported puzzles"
        case File.techniqueProgress.rawValue: return "learning progress"
        case _ where fileName.hasPrefix("game_"): return "saved games"
        default: return nil
        }
    }

    init?(rawValue: String) { return nil }
}
