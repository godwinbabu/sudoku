import Foundation
@testable import PureSudoku

enum TestData {
    static let puzzle = SudokuPuzzle(
        id: "test",
        difficulty: .easy,
        initialGrid: "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
        solutionGrid: "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    )

    static func newGameState() -> GameState {
        GameState.newGame(for: puzzle)
    }
}
