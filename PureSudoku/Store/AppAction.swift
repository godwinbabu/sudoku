import Foundation

/// An enumeration of all possible actions that can be dispatched to the `Store` to mutate the `AppState`.
enum AppAction {
    // MARK: - App Lifecycle
    /// Dispatched when the app needs to load its initial state from persistence.
    case loadInitialState

    // MARK: - Navigation
    /// Dispatched to change the currently displayed top-level view.
    case navigateTo(AppState.AppView)

    // MARK: - Main Menu
    /// Dispatched when the user taps the "New Game" button for a specific difficulty.
    case newGame(difficulty: Difficulty)
    /// Dispatched when the user taps the "Continue" button.
    case continueGame

    // MARK: - Game Play
    /// Dispatched when a user taps on a cell in the Sudoku grid.
    case cellSelected(id: UUID?)
    /// Dispatched when a user taps on a number in the number pad.
    case digitTapped(Int)
    /// Dispatched when the user taps the "Clear" button for the selected cell.
    case clearTapped
    /// Dispatched when the user toggles between Normal and Candidate input modes.
    case toggleInputMode

    // MARK: - Game Actions (Confirmation Flow)
    /// Dispatched when a user initiates an action that requires confirmation (e.g., Reset, Reveal).
    case requestConfirmation(GameAction)
    /// Dispatched when the user confirms the pending action.
    case confirmAction
    /// Dispatched when the user cancels the pending action.
    case cancelAction

    // MARK: - Settings
    /// Dispatched when the user saves new settings.
    case updateSettings(Settings)
    
    // MARK: - Persistence Callbacks
    /// Dispatched by the `Store` after successfully loading state from persistence.
    case _didLoadState(GameState?, Settings, Stats)
    /// Dispatched by the `Store` when a persistence operation fails.
    case _persistenceError(any Error)
}

/// Represents a game action that requires user confirmation.
enum GameAction: Identifiable {
    case reset
    case revealPuzzle
    case newPuzzle

    var id: Int {
        switch self {
        case .reset: return 0
        case .revealPuzzle: return 1
        case .newPuzzle: return 2
        }
    }

    var title: String {
        switch self {
        case .reset: return "Reset puzzle?"
        case .revealPuzzle: return "Reveal entire puzzle?"
        case .newPuzzle: return "Start a new puzzle?"
        }
    }

    var message: String {
        switch self {
        case .reset:
            return "This clears your progress and timer for this puzzle."
        case .revealPuzzle:
            return "Revealing marks the puzzle as completed with reveals."
        case .newPuzzle:
            return "Current progress will be lost."
        }
    }
}
