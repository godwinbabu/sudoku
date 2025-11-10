import Foundation

/// Represents the complete state of the entire application.
struct AppState {
    /// The currently visible top-level view.
    var currentView: AppView = .mainMenu

    /// The state of the current Sudoku game. `nil` if no game is active.
    var gameState: GameState?

    /// The user's application settings.
    var settings: Settings = .init()

    /// The user's gameplay statistics.
    var stats: Stats = .init()

    /// The last error that occurred during a persistence operation.
    var lastPersistenceError: (any Error)?

    /// UI-specific state for the game screen.
    var gameUI: GameUIState = .init()
}

// MARK: - Sub-states

extension AppState {
    /// Represents the top-level views the user can navigate to.
    enum AppView {
        case mainMenu
        case game
        case settings
        case stats
    }

    /// Represents UI-specific state for the game screen that is not part of the core `GameState` model.
    struct GameUIState {
        var selectedCellID: UUID?
        var inputMode: InputMode = .normal
        var pendingAction: GameAction?
    }
}
