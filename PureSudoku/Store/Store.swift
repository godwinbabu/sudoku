import Foundation
import Combine

/// The central, observable object that manages the entire application's state and logic.
@MainActor
final class Store: ObservableObject {
    /// The single source of truth for the entire application state.
    @Published private(set) var state: AppState

    // MARK: - Dependencies
    private let persistence: PersistenceManager
    private let puzzleRepository: SudokuPuzzleRepository
    private let timeProvider: TimeProvider
    private let validator: SudokuValidator

    // MARK: - Private State
    private var timer: Timer?
    private var lastTickDate: Date?

    init(
        initialState: AppState = .init(),
        persistence: PersistenceManager,
        puzzleRepository: SudokuPuzzleRepository,
        timeProvider: TimeProvider = DefaultTimeProvider(),
        validator: SudokuValidator = SudokuValidator()
    ) {
        self.state = initialState
        self.persistence = persistence
        self.puzzleRepository = puzzleRepository
        self.timeProvider = timeProvider
        self.validator = validator
    }

    /// The main entry point for all state mutations.
    /// It first runs the `reducer` to calculate the new state, then handles any side effects.
    func send(_ action: AppAction) {
        let oldState = state
        reduce(&state, action)
        
        Task {
            await handleSideEffect(for: action, oldState: oldState)
        }
    }

    // MARK: - Reducer
    
    /// A pure function that mutates the state based on a given action.
    private func reduce(_ state: inout AppState, _ action: AppAction) {
        switch action {
        
        // MARK: Navigation
        case .navigateTo(let view):
            state.currentView = view
            // When navigating away from the game, reset UI state
            if view != .game {
                state.gameUI = .init()
            }

        // MARK: Loading & Setup
        case ._didLoadState(let gameState, let settings, let stats):
            state.gameState = gameState
            state.settings = settings
            state.stats = stats
            
        case .newGame(let difficulty):
            let puzzle = puzzleRepository.newPuzzle(for: difficulty)
            state.gameState = GameState(puzzle: puzzle)
            state.currentView = .game
            state.gameUI = .init() // Reset UI state for new game

        case .continueGame:
            // Logic to continue will depend on how multiple active games are handled.
            // For now, we assume it just switches to the game view if a game is active.
            if state.gameState != nil {
                state.currentView = .game
            }

        // MARK: Game UI State
        case .cellSelected(let id):
            state.gameUI.selectedCellID = id
            
        case .toggleInputMode:
            state.gameUI.inputMode.toggle()

        case .requestConfirmation(let gameAction):
            state.gameUI.pendingAction = gameAction
            
        case .cancelAction:
            state.gameUI.pendingAction = nil

        // MARK: Game Logic
        case .clearTapped:
            guard var gameState = state.gameState, let cellID = state.gameUI.selectedCellID,
                  let index = gameState.cells.firstIndex(where: { $0.id == cellID }),
                  !gameState.cells[index].given, !gameState.cells[index].isRevealed else { break }
            
            gameState.cells[index].value = nil
            gameState.cells[index].candidates.removeAll()
            gameState.cells[index].isError = false
            gameState.cells[index].isVerifiedCorrect = false
            state.gameState = gameState
            
        case .digitTapped(let digit):
            guard var gameState = state.gameState, let cellID = state.gameUI.selectedCellID,
                  let index = gameState.cells.firstIndex(where: { $0.id == cellID }),
                  !gameState.cells[index].given, !gameState.cells[index].isRevealed else { break }

            switch state.gameUI.inputMode {
            case .normal:
                gameState.cells[index].value = digit
                gameState.cells[index].candidates.removeAll()
                gameState.cells[index].isError = false
                gameState.cells[index].isVerifiedCorrect = false
                if state.settings.autoRemoveCandidates {
                    gameState.cells = validator.removeCandidates(digit, relatedTo: gameState.cells[index], from: gameState.cells)
                }
            case .candidate:
                if gameState.cells[index].candidates.contains(digit) {
                    gameState.cells[index].candidates.remove(digit)
                } else {
                    gameState.cells[index].candidates.insert(digit)
                }
            }
            state.gameState = gameState

        case .confirmAction:
            guard let action = state.gameUI.pendingAction else { break }
            
            switch action {
            case .reset:
                guard var gameState = state.gameState else { break }
                gameState.resetToInitial(now: timeProvider.now())
                gameState.elapsedSeconds = 0
                gameState.usedReveal = false
                gameState.isCompleted = false
                gameState.cells = gameState.cells.map { cell in
                    var mutable = cell
                    mutable.isError = false
                    mutable.candidates.removeAll()
                    mutable.isVerifiedCorrect = false
                    return mutable
                }
                state.gameState = gameState
                state.gameUI = .init()

            case .revealPuzzle:
                guard var gameState = state.gameState else { break }
                for idx in gameState.cells.indices {
                    if let value = validator.solutionValue(row: gameState.cells[idx].row, col: gameState.cells[idx].col, solution: gameState.puzzle.solutionGrid) {
                        gameState.cells[idx].value = value
                        gameState.cells[idx].isRevealed = true
                        gameState.cells[idx].candidates.removeAll()
                        gameState.cells[idx].isError = false
                        gameState.cells[idx].isVerifiedCorrect = false
                    }
                }
                gameState.usedReveal = true
                gameState.isCompleted = true
                state.gameState = gameState

            case .newPuzzle:
                guard let oldDifficulty = state.gameState?.difficulty else { break }
                let puzzle = puzzleRepository.newPuzzle(for: oldDifficulty)
                state.gameState = GameState(puzzle: puzzle)
                state.gameUI = .init()
            }
            state.gameUI.pendingAction = nil
            
        // MARK: Settings
        case .updateSettings(let newSettings):
            state.settings = newSettings
            
        // MARK: Errors
        case ._persistenceError(let error):
            state.lastPersistenceError = error
            
        default:
            break
        }
    }
    
    // MARK: - Side Effects
    
    private func handleSideEffect(for action: AppAction, oldState: AppState) async {
        switch action {
        case .loadInitialState:
            do {
                let savedGame = try persistence.loadGame()
                let savedSettings = try persistence.loadSettings()
                let savedStats = try persistence.loadStats()
                send(._didLoadState(savedGame, savedSettings, savedStats))
            } catch {
                send(._persistenceError(error))
            }
            
        case .newGame, .confirmAction, .digitTapped, .clearTapped:
            // After any action that could change the game state, save it.
            if state.gameState != oldState.gameState {
                if let gameState = state.gameState {
                    do {
                        try persistence.saveGame(gameState)
                    } catch {
                        send(._persistenceError(error))
                    }
                }
            }
            // After an action that could complete the puzzle, update stats
            if state.gameState?.isCompleted == true && oldState.gameState?.isCompleted == false {
                if let completedState = state.gameState {
                    var newStats = state.stats
                    newStats.add(result: completedState)
                    state.stats = newStats // Mutate state via reducer in next cycle if needed, but this is fine for now.
                    do {
                        try persistence.saveStats(newStats)
                    } catch {
                        send(._persistenceError(error))
                    }
                }
            }
            
        case .updateSettings(let newSettings):
            do {
                try persistence.saveSettings(newSettings)
            } catch {
                send(._persistenceError(error))
            }
            
        default:
            break
        }
    }
}
