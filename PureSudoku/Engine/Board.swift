import Foundation

/// Shared helpers for the solver's board format: 81 entries, `nil` for empty, 0...8 for digits 1...9.
enum Board {
    /// Board from game cells (given or entered values).
    static func from(cells: [SudokuCell]) -> GeneratorBoard {
        cells.map { cell in
            guard let value = cell.value, (1...9).contains(value) else { return nil }
            return value - 1
        }
    }

    /// Board from an 81-character grid string ("0" or "." for empty).
    static func from(grid: String) -> GeneratorBoard {
        grid.map { char -> Int? in
            guard let digit = Int(String(char)), (1...9).contains(digit) else { return nil }
            return digit - 1
        }
    }

    /// Board from digits 1...9 (`nil` for empty), as used by the import screen.
    static func from(digits: [Int?]) -> GeneratorBoard {
        digits.map { digit in
            guard let digit, (1...9).contains(digit) else { return nil }
            return digit - 1
        }
    }

    /// For each position, the 20 positions in the same row, column or box.
    static let peers: [Set<Int>] = (0..<81).map { pos in
        let row = pos / 9, col = pos % 9
        let boxRow = (row / 3) * 3, boxCol = (col / 3) * 3
        var set: Set<Int> = []
        for c in 0..<9 where c != col { set.insert(row * 9 + c) }
        for r in 0..<9 where r != row { set.insert(r * 9 + col) }
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) where r * 9 + c != pos { set.insert(r * 9 + c) }
        }
        return set
    }

    /// True if a digit repeats in a row, column or box.
    static func hasContradiction(_ board: GeneratorBoard) -> Bool {
        !conflictingPositions(in: board).isEmpty
    }

    /// Every position whose digit repeats in its row, column or box.
    static func conflictingPositions(in board: GeneratorBoard) -> Set<Int> {
        var conflicts: Set<Int> = []
        for pos in 0..<81 {
            guard let digit = board[pos] else { continue }
            if peers[pos].contains(where: { board[$0] == digit }) {
                conflicts.insert(pos)
            }
        }
        return conflicts
    }
}
