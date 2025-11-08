import Foundation

struct GameState: Codable, Equatable {
    var puzzle: SudokuPuzzle
    var cells: [SudokuCell]
    var elapsedSeconds: Int
    var isCompleted: Bool
    var usedReveal: Bool
    var lastUpdated: Date

    init(puzzle: SudokuPuzzle, cells: [SudokuCell], elapsedSeconds: Int = 0, isCompleted: Bool = false, usedReveal: Bool = false, lastUpdated: Date = Date()) {
        self.puzzle = puzzle
        self.cells = cells
        self.elapsedSeconds = elapsedSeconds
        self.isCompleted = isCompleted
        self.usedReveal = usedReveal
        self.lastUpdated = lastUpdated
    }

    static func newGame(for puzzle: SudokuPuzzle, now: Date = Date()) -> GameState {
        var cells: [SudokuCell] = []
        cells.reserveCapacity(81)
        let initialChars = Array(puzzle.initialGrid)
        for index in 0..<81 {
            let row = index / 9
            let col = index % 9
            let char = initialChars[index]
            let digit = Int(String(char))
            let isGiven = digit != nil && digit != 0
            let cell = SudokuCell(row: row, col: col, given: isGiven, value: isGiven ? digit : nil)
            cells.append(cell)
        }
        return GameState(puzzle: puzzle, cells: cells, elapsedSeconds: 0, isCompleted: false, usedReveal: false, lastUpdated: now)
    }

    mutating func replace(cell updated: SudokuCell) {
        guard let idx = cells.firstIndex(where: { $0.id == updated.id }) else { return }
        cells[idx] = updated
    }

    mutating func resetToInitial(now: Date = Date()) {
        self = GameState.newGame(for: puzzle, now: now)
    }
}
