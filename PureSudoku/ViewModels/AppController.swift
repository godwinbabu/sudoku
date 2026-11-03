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
    /// True when technique_progress.json could not be loaded: never overwrite it this session.
    private var techniqueProgressLoadFailed = false
    @Published var lastPersistenceError: (any Error)?

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
        imageStore: ImportedImageStore = ImportedImageStore()
    ) {
        self.persistence = persistence
        self.generatorService = generatorService
        self.puzzleRepository = puzzleRepository ?? SudokuPuzzleRepository(generator: generatorService, validator: validator)
        self.validator = validator
        self.timeProvider = timeProvider
        self.imageStore = imageStore

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
        for difficulty in Difficulty.allCases {
            do {
                if let state = try persistence.load(GameState.self, from: File.game(difficulty).rawValue) {
                    games[difficulty] = state
                }
            } catch {
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
            self.techniqueProgress = try persistence.load([String: TechniqueProgress].self, from: File.techniqueProgress.rawValue) ?? [:]
        } catch {
            self.techniqueProgress = [:]
            self.techniqueProgressLoadFailed = true
            self.lastPersistenceError = error
        }
        countSolutionsOfOldImports()
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

    /// A practice game from a lesson: not saved and not counted in stats, but it does count
    /// toward learning (CODESPEC 13.5).
    func makePracticeGameViewModel(_ entry: BundledPuzzles.Entry, number: Int) -> GameViewModel {
        let puzzle = SudokuPuzzle(
            id: "practice-\(entry.initialGrid.prefix(12))", difficulty: entry.difficulty,
            initialGrid: entry.initialGrid, solutionGrid: entry.solutionGrid, hasUniqueSolution: true
        )
        let viewModel = GameViewModel(state: GameState.newGame(for: puzzle, now: timeProvider.now()), settings: settings,
                                      validator: validator, timeProvider: timeProvider, hintService: generatorService)
        viewModel.isPractice = true
        connectLearning(viewModel)
        return viewModel
    }

    func progress(for technique: Technique) -> TechniqueProgress {
        techniqueProgress[technique.rawValue] ?? TechniqueProgress()
    }

    private func connectLearning(_ viewModel: GameViewModel) {
        viewModel.learningLevel = { [weak self] technique in self?.progress(for: technique).level ?? .new }
        viewModel.onTechniqueFound = { [weak self] technique, puzzleID in
            self?.updateProgress(technique) { $0.recordFound(puzzleID: puzzleID, at: self?.timeProvider.now() ?? Date()) }
        }
        viewModel.onHintShown = { [weak self] technique in
            self?.updateProgress(technique) { $0.recordHint(at: self?.timeProvider.now() ?? Date()) }
        }
    }

    private func updateProgress(_ technique: Technique, _ change: (inout TechniqueProgress) -> Void) {
        var progress = progress(for: technique)
        change(&progress)
        techniqueProgress[technique.rawValue] = progress
        guard !techniqueProgressLoadFailed else { return }
        do {
            try persistence.save(techniqueProgress, to: File.techniqueProgress.rawValue)
        } catch {
            lastPersistenceError = error
        }
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
        // Level from the techniques needed; an import the solver can't finish is Hard (CODESPEC 2.2).
        let unique = SolutionCounter.count(values, limit: 2) == 1
        let grade = PuzzleGrader.grade(values, allowsUniqueness: unique)?.grade
        let puzzle = SudokuPuzzle(
            id: UUID().uuidString,
            difficulty: grade?.difficulty ?? .hard,
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
    var isNight: Bool { settings.isNight(systemIsDark: UIScreen.main.traitCollection.userInterfaceStyle == .dark) }
    var palette: PSPalette { settings.palette(isNight: isNight) }
    var preferredColorScheme: ColorScheme? { settings.preferredColorScheme(isNight: isNight) }
    /// Night always keeps sound and vibration off, whatever the saved settings say.
    /// Any future sound or haptic must check these, never `settings.soundsEnabled` / `hapticsEnabled`.
    var soundsActive: Bool { settings.soundsEnabled && !isNight }
    var hapticsActive: Bool { settings.hapticsEnabled && !isNight }

    /// Until the Night sheet lands (CODESPEC 12.2), the moon flips between Day and Night.
    func toggleNight() {
        let night = !isNight
        updateSettings { $0.appearance = night ? .night : .day }
    }

    func updateSettings(_ block: (inout Settings) -> Void) {
        block(&settings)
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

    func updateStats(_ block: (inout Stats) -> Void) {
        block(&stats)
        do {
            try persistence.save(stats, to: File.stats.rawValue)
        } catch {
            lastPersistenceError = error
        }
    }

    private func persist(state: GameState, for difficulty: Difficulty) {
        activeGames[difficulty] = state
        do {
            try persistence.save(state, to: File.game(difficulty).rawValue)
        } catch {
            self.lastPersistenceError = error
        }
    }

    private func handleCompletion(state: GameState, difficulty: Difficulty) {
        updateStats { stats in
            stats.recordCompletion(for: difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal, usedHint: state.usedHint, source: state.puzzle.source, date: self.timeProvider.now())
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
        persistImportedGames()
    }

    private func handleImportedCompletion(state: GameState, id: String) {
        updateStats { stats in
            stats.recordCompletion(
                for: state.puzzle.difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal,
                usedHint: state.usedHint, source: state.puzzle.source, date: self.timeProvider.now()
            )
        }
        persistImported(state: state, id: id)
    }

    /// Saves the imported list, then removes images no game uses (only after a successful save).
    private func persistImportedGames() {
        do {
            try persistence.save(importedGames, to: File.importedGames.rawValue)
        } catch {
            self.lastPersistenceError = error
            return
        }
        cleanupImportImages()
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
