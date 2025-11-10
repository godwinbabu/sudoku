import Foundation

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var settings: Settings
    @Published private(set) var stats: Stats
    @Published private(set) var activeGames: [Difficulty: GameState]
    @Published var lastPersistenceError: (any Error)?

    private let persistence: PersistenceManager
    private let puzzleRepository: SudokuPuzzleRepository
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider

    init(persistence: PersistenceManager = PersistenceManager(), puzzleRepository: SudokuPuzzleRepository = SudokuPuzzleRepository(), validator: SudokuValidator = SudokuValidator(), timeProvider: TimeProvider = SystemTimeProvider()) {
        self.persistence = persistence
        self.puzzleRepository = puzzleRepository
        self.validator = validator
        self.timeProvider = timeProvider

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
    }

    func makeGameViewModel(for difficulty: Difficulty) -> GameViewModel {
        let state = activeGames[difficulty] ?? (try? createNewGameState(for: difficulty)) ?? GameState.newGame(for: fallbackPuzzle(for: difficulty))
        activeGames[difficulty] = state
        let viewModel = GameViewModel(state: state, settings: settings, validator: validator, timeProvider: timeProvider)
        viewModel.onCompletion = { [weak self] completedState in
            self?.handleCompletion(state: completedState, difficulty: difficulty)
        }
        viewModel.onNewGame = { [weak self] in
            self?.startNewGame(for: difficulty)
        }
        viewModel.onSave = { [weak self] updatedState in
            self?.persist(state: updatedState, for: difficulty)
        }
        return viewModel
    }

    @discardableResult
    func startNewGame(for difficulty: Difficulty) -> GameState? {
        if let newState = try? createNewGameState(for: difficulty) {
            activeGames[difficulty] = newState
            do {
                try persistence.save(newState, to: File.game(difficulty).rawValue)
            } catch {
                self.lastPersistenceError = error
            }
            return newState
        }
        return nil
    }

    func updateSettings(_ block: @escaping (inout Settings) -> Void) {
        DispatchQueue.main.async {
            block(&self.settings)
            self.settings.enforceBedtimeRulesIfNeeded()
            do {
                try self.persistence.save(self.settings, to: File.settings.rawValue)
            } catch {
                self.lastPersistenceError = error
            }
        }
    }

    func updateStats(_ block: @escaping (inout Stats) -> Void) {
        DispatchQueue.main.async {
            block(&self.stats)
            do {
                try self.persistence.save(self.stats, to: File.stats.rawValue)
            } catch {
                self.lastPersistenceError = error
            }
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
            stats.recordCompletion(for: difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal, date: self.timeProvider.now())
        }
        activeGames[difficulty] = state
        do {
            try persistence.save(state, to: File.game(difficulty).rawValue)
        } catch {
            self.lastPersistenceError = error
        }
    }

    private func createNewGameState(for difficulty: Difficulty) throws -> GameState {
        let puzzle = try puzzleRepository.randomPuzzle(for: difficulty)
        return GameState.newGame(for: puzzle, now: timeProvider.now())
    }

    private func fallbackPuzzle(for difficulty: Difficulty) -> SudokuPuzzle {
        SudokuPuzzle(id: "fallback-\(difficulty.rawValue)", difficulty: difficulty, initialGrid: String(repeating: "0", count: 81), solutionGrid: String(repeating: "0", count: 81))
    }
}

private enum File: RawRepresentable {
    typealias RawValue = String

    case settings
    case stats
    case game(Difficulty)

    var rawValue: String {
        switch self {
        case .settings: return "settings.json"
        case .stats: return "stats.json"
        case let .game(difficulty): return "game_\(difficulty.rawValue).json"
        }
    }

    init?(rawValue: String) { return nil }
}
