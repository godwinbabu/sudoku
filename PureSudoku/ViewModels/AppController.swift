import Foundation

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var settings: Settings
    @Published private(set) var stats: Stats
    @Published private(set) var activeGames: [Difficulty: GameState]

    private let persistence: PersistenceManager
    private let puzzleRepository: SudokuPuzzleRepository
    private let validator: SudokuValidator
    private let timeProvider: TimeProvider

    init(persistence: PersistenceManager = PersistenceManager(), puzzleRepository: SudokuPuzzleRepository = SudokuPuzzleRepository(), validator: SudokuValidator = SudokuValidator(), timeProvider: TimeProvider = SystemTimeProvider()) {
        self.persistence = persistence
        self.puzzleRepository = puzzleRepository
        self.validator = validator
        self.timeProvider = timeProvider

        self.settings = (try? persistence.load(Settings.self, from: File.settings.rawValue)) ?? .default
        self.stats = (try? persistence.load(Stats.self, from: File.stats.rawValue)) ?? Stats()

        var games: [Difficulty: GameState] = [:]
        for difficulty in Difficulty.allCases {
            if let state = try? persistence.load(GameState.self, from: File.game(difficulty).rawValue) {
                games[difficulty] = state
            }
        }
        self.activeGames = games
    }

    func makeGameViewModel(for difficulty: Difficulty) -> GameViewModel {
        let state = activeGames[difficulty] ?? (try? createNewGameState(for: difficulty)) ?? GameState.newGame(for: fallbackPuzzle(for: difficulty))
        activeGames[difficulty] = state
        let viewModel = GameViewModel(state: state, settings: settings, validator: validator, timeProvider: timeProvider)
        viewModel.onStateChange = { [weak self] updatedState in
            self?.persist(state: updatedState, for: difficulty)
        }
        viewModel.onCompletion = { [weak self] completedState in
            self?.handleCompletion(state: completedState, difficulty: difficulty)
        }
        return viewModel
    }

    @discardableResult
    func startNewGame(for difficulty: Difficulty) -> GameState? {
        if let newState = try? createNewGameState(for: difficulty) {
            activeGames[difficulty] = newState
            try? persistence.save(newState, to: File.game(difficulty).rawValue)
            return newState
        }
        return nil
    }

    func updateSettings(_ block: (inout Settings) -> Void) {
        block(&settings)
        settings.enforceBedtimeRulesIfNeeded()
        try? persistence.save(settings, to: File.settings.rawValue)
    }

    func updateStats(_ block: (inout Stats) -> Void) {
        block(&stats)
        try? persistence.save(stats, to: File.stats.rawValue)
    }

    func clearGame(for difficulty: Difficulty) {
        activeGames[difficulty] = nil
        persistence.delete(File.game(difficulty).rawValue)
    }

    private func persist(state: GameState, for difficulty: Difficulty) {
        activeGames[difficulty] = state
        try? persistence.save(state, to: File.game(difficulty).rawValue)
    }

    private func handleCompletion(state: GameState, difficulty: Difficulty) {
        updateStats { stats in
            stats.recordCompletion(for: difficulty, time: state.elapsedSeconds, usedReveal: state.usedReveal, date: timeProvider.now())
        }
        activeGames[difficulty] = state
        try? persistence.save(state, to: File.game(difficulty).rawValue)
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
