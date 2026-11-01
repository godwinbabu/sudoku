import Foundation

struct ImportedGame: Codable, Equatable, Identifiable {
    let id: String
    var gameState: GameState
    var createdAt: Date
    var lastOpened: Date

    init(gameState: GameState, createdAt: Date = Date(), lastOpened: Date = Date()) {
        self.id = gameState.puzzle.id
        self.gameState = gameState
        self.createdAt = createdAt
        self.lastOpened = lastOpened
    }
}
