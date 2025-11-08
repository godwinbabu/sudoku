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

        for group in allGroups {
            var seen: [Int: UUID] = [:]
            for cell in group {
                guard let value = cell.value, !cell.given else { continue }
                if let other = seen[value] {
                    conflicts.insert(cell.id)
                    conflicts.insert(other)
                } else {
                    seen[value] = cell.id
                }
            }
        }
        return conflicts
    }
}
