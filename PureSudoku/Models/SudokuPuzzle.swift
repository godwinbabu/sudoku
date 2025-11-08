import Foundation

struct SudokuPuzzle: Codable, Equatable, Identifiable {
    let id: String
    let difficulty: Difficulty
    let initialGrid: String
    let solutionGrid: String

    init(id: String, difficulty: Difficulty, initialGrid: String, solutionGrid: String) {
        self.id = id
        self.difficulty = difficulty
        self.initialGrid = initialGrid
        self.solutionGrid = solutionGrid
    }
}
