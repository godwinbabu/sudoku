import Foundation

struct SudokuValidator {
    func isValid(solution: String) -> Bool {
        guard solution.count == 81 else { return false }
        let digits = Array(solution)
        for row in 0..<9 {
            var set = Set<Character>()
            for col in 0..<9 {
                set.insert(digits[row * 9 + col])
            }
            if set.count != 9 { return false }
        }
        for col in 0..<9 {
            var set = Set<Character>()
            for row in 0..<9 {
                set.insert(digits[row * 9 + col])
            }
            if set.count != 9 { return false }
        }
        for boxRow in 0..<3 {
            for boxCol in 0..<3 {
                var set = Set<Character>()
                for r in 0..<3 {
                    for c in 0..<3 {
                        let index = (boxRow * 3 + r) * 9 + (boxCol * 3 + c)
                        set.insert(digits[index])
                    }
                }
                if set.count != 9 { return false }
            }
        }
        return true
    }

    func isCorrect(value: Int, row: Int, col: Int, solution: String) -> Bool {
        guard solution.count == 81 else { return false }
        let chars = Array(solution)
        let char = chars[row * 9 + col]
        return Int(String(char)) == value
    }

    func solutionValue(row: Int, col: Int, solution: String) -> Int? {
        guard solution.count == 81 else { return nil }
        let chars = Array(solution)
        return Int(String(chars[row * 9 + col]))
    }

    func isSolved(cells: [SudokuCell], solution: String) -> Bool {
        guard cells.count == 81 else { return false }
        for cell in cells where !cell.given {
            guard let value = cell.value, isCorrect(value: value, row: cell.row, col: cell.col, solution: solution) else {
                return false
            }
        }
        return true
    }

    func conflictingIndices(in cells: [SudokuCell], autoCheckMistakes: Bool) -> Set<UUID> {
        guard autoCheckMistakes else { return [] }
        var conflicts: Set<UUID> = []
        let rowGroups = Dictionary(grouping: cells, by: { $0.row }).values.map(Array.init)
        let colGroups = Dictionary(grouping: cells, by: { $0.col }).values.map(Array.init)
        let boxGroups = Dictionary(grouping: cells, by: { (($0.row / 3) * 3) + ($0.col / 3) }).values.map(Array.init)
        let allGroups = rowGroups + colGroups + boxGroups

        // We want to flag duplicates against givens and between non-given cells,
        // but we never flag a given cell itself.
        for group in allGroups {
            // Track first occurrence: either a given (true) or a non-given with its UUID (false)
            enum FirstSeen { case given, placed(UUID) }
            var seen: [Int: FirstSeen] = [:]

            for cell in group {
                guard let value = cell.value else { continue }
                if let first = seen[value] {
                    switch (first, cell.given) {
                    case (.given, true):
                        // Two givens with same value should not happen in valid puzzles; ignore highlighting givens
                        break
                    case (.given, false):
                        // Duplicate with a given: flag this non-given cell only
                        conflicts.insert(cell.id)
                    case let (.placed(otherID), false):
                        // Duplicate between two non-given cells: flag both
                        conflicts.insert(cell.id)
                        conflicts.insert(otherID)
                    case (.placed, true):
                        // Current is given and previous was non-given: only flag the non-given one
                        if case let .placed(otherID) = first { conflicts.insert(otherID) }
                    }
                } else {
                    // First time seeing this value in the group
                    seen[value] = cell.given ? .given : .placed(cell.id)
                }
            }
        }
        return conflicts
    }

    func removeCandidates(_ digit: Int, relatedTo cell: SudokuCell, from cells: [SudokuCell]) -> [SudokuCell] {
        var newCells = cells
        for idx in newCells.indices {
            guard newCells[idx].id != cell.id else { continue }
            if newCells[idx].row == cell.row || newCells[idx].col == cell.col || (newCells[idx].row / 3 == cell.row / 3 && newCells[idx].col / 3 == cell.col / 3) {
                newCells[idx].candidates.remove(digit)
            }
        }
        return newCells
    }

    func hasContradiction(in cells: [SudokuCell]) -> Bool {
        let board: GeneratorBoard = cells.map { cell in
            guard let value = cell.value, value > 0 else { return nil }
            return value - 1
        }
        return PureSudoku.hasContradiction(board)
    }
}
