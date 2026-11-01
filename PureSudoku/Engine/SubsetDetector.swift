import Foundation

/// Naked, hidden and locked subsets (Intermediate tier).
enum SubsetDetector {
    /// `size` cells in a house hold only `size` digits between them: remove those digits from the
    /// house's other cells.
    static func naked(_ board: SolverBoard, size: Int) -> [TechniqueStep] {
        let technique: Technique = [2: .nakedPair, 3: .nakedTriple, 4: .nakedQuad][size]!
        var steps: [TechniqueStep] = []
        for house in House.all {
            let open = house.cells.filter { board.values[$0] == 0 }
            let small = open.filter { (2...size).contains(board.candidates[$0].nonzeroBitCount) }
            for group in combinations(small, size: size) {
                let union = group.reduce(UInt16(0)) { $0 | board.candidates[$1] }
                guard union.nonzeroBitCount == size else { continue }
                let digits = SolverBoard.digits(in: union)
                let removed = open.filter { !group.contains($0) }.flatMap { cell in
                    digits.filter { board.has($0, at: cell) }.map { CellDigit(cell: cell, digit: $0) }
                }
                steps.append(TechniqueStep(
                    technique: technique, digits: digits,
                    houses: [.init(house: house, role: .base)],
                    cells: group.map { .init(cell: $0, role: .defining) },
                    eliminations: removed
                ))
            }
        }
        return steps
    }

    /// `size` digits fit only in the same `size` cells of a house: those cells lose their other
    /// candidates.
    static func hidden(_ board: SolverBoard, size: Int) -> [TechniqueStep] {
        let technique: Technique = [2: .hiddenPair, 3: .hiddenTriple, 4: .hiddenQuad][size]!
        var steps: [TechniqueStep] = []
        for house in House.all {
            let placed = Set(house.cells.map { board.values[$0] })
            let digits = (1...9).filter { digit in
                !placed.contains(digit) && (2...size).contains(board.cells(for: digit, in: house).count)
            }
            for group in combinations(digits, size: size) {
                let spots = Set(group.flatMap { board.cells(for: $0, in: house) })
                guard spots.count == size else { continue }
                let keep = SolverBoard.mask(of: group)
                let removed = spots.sorted().flatMap { cell in
                    SolverBoard.digits(in: board.candidates[cell] & ~keep).map { CellDigit(cell: cell, digit: $0) }
                }
                steps.append(TechniqueStep(
                    technique: technique, digits: group,
                    houses: [.init(house: house, role: .base)],
                    cells: spots.sorted().map { .init(cell: $0, role: .defining) },
                    eliminations: removed
                ))
            }
        }
        return steps
    }

    /// A naked pair or triple that sits in one box and one line: its digits leave both houses.
    static func locked(_ board: SolverBoard, size: Int) -> [TechniqueStep] {
        let technique: Technique = size == 2 ? .lockedPair : .lockedTriple
        var steps: [TechniqueStep] = []
        for box in House.boxes {
            let open = box.cells.filter { board.values[$0] == 0 && (2...size).contains(board.candidates[$0].nonzeroBitCount) }
            for group in combinations(open, size: size) {
                let union = group.reduce(UInt16(0)) { $0 | board.candidates[$1] }
                guard union.nonzeroBitCount == size else { continue }
                let lines = IntersectionDetector.sharedLines(of: group)
                guard let line = lines.first else { continue }
                let digits = SolverBoard.digits(in: union)
                let others = Set(box.cells + line.cells).subtracting(group).sorted()
                let removed = others.flatMap { cell in
                    digits.filter { board.has($0, at: cell) }.map { CellDigit(cell: cell, digit: $0) }
                }
                steps.append(TechniqueStep(
                    technique: technique, digits: digits,
                    houses: [.init(house: box, role: .base), .init(house: line, role: .base)],
                    cells: group.map { .init(cell: $0, role: .defining) },
                    eliminations: removed
                ))
            }
        }
        return steps
    }
}
