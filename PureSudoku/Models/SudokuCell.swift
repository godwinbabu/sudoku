import Foundation

struct SudokuCell: Identifiable, Codable, Equatable {
    let id: UUID
    var row: Int
    var col: Int
    var given: Bool
    var value: Int?
    var candidates: Set<Int>
    var isError: Bool
    var isRevealed: Bool

    init(id: UUID = UUID(), row: Int, col: Int, given: Bool, value: Int?, candidates: Set<Int> = [], isError: Bool = false, isRevealed: Bool = false) {
        self.id = id
        self.row = row
        self.col = col
        self.given = given
        self.value = value
        self.candidates = candidates
        self.isError = isError
        self.isRevealed = isRevealed
    }

    var index: Int {
        row * 9 + col
    }
}
