import Foundation

/// Full House, Hidden Single, Naked Single (Basic tier).
enum SinglesDetector {
    /// A house with one empty cell left: that cell takes the missing digit.
    static func fullHouses(_ board: SolverBoard) -> [TechniqueStep] {
        House.all.compactMap { house in
            let empty = house.cells.filter { board.values[$0] == 0 }
            guard empty.count == 1, let cell = empty.first else { return nil }
            let placed = Set(house.cells.map { board.values[$0] })
            guard let digit = (1...9).first(where: { !placed.contains($0) }), board.has(digit, at: cell) else { return nil }
            return TechniqueStep(
                technique: .fullHouse, digits: [digit],
                houses: [.init(house: house, role: .base)],
                cells: [.init(cell: cell, role: .defining)],
                placements: [CellDigit(cell: cell, digit: digit)]
            )
        }
    }

    /// In a house, a digit fits in only one cell.
    static func hiddenSingles(_ board: SolverBoard, in houses: [House], technique: Technique) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for house in houses {
            let placed = Set(house.cells.map { board.values[$0] })
            for digit in 1...9 where !placed.contains(digit) {
                let spots = board.cells(for: digit, in: house)
                guard spots.count == 1, let cell = spots.first else { continue }
                steps.append(TechniqueStep(
                    technique: technique, digits: [digit],
                    houses: [.init(house: house, role: .base)],
                    cells: [.init(cell: cell, role: .defining)],
                    placements: [CellDigit(cell: cell, digit: digit)]
                ))
            }
        }
        return steps
    }

    /// A cell with one candidate left.
    static func nakedSingles(_ board: SolverBoard) -> [TechniqueStep] {
        (0..<81).compactMap { cell in
            let digits = SolverBoard.digits(in: board.candidates[cell])
            guard board.values[cell] == 0, digits.count == 1, let digit = digits.first else { return nil }
            return TechniqueStep(
                technique: .nakedSingle, digits: [digit], houses: [],
                cells: [.init(cell: cell, role: .defining)],
                placements: [CellDigit(cell: cell, digit: digit)]
            )
        }
    }
}

/// Pointing and Claiming (Intermediate tier): a digit confined to the overlap of a box and a line.
enum IntersectionDetector {
    /// In a box, a digit's candidates lie on one line: remove it from the rest of that line.
    static func pointing(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for box in House.boxes {
            for digit in 1...9 {
                let spots = board.cells(for: digit, in: box)
                guard spots.count >= 2 else { continue }
                for line in sharedLines(of: spots) {
                    let removed = line.cells.filter { !box.cells.contains($0) && board.has(digit, at: $0) }
                    steps.append(step(.pointing, digit: digit, base: box, cover: line, spots: spots, removed: removed))
                }
            }
        }
        return steps
    }

    /// In a line, a digit's candidates lie in one box: remove it from the rest of that box.
    static func claiming(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for line in House.lines {
            for digit in 1...9 {
                let spots = board.cells(for: digit, in: line)
                guard spots.count >= 2 else { continue }
                let boxes = Set(spots.map(SolverBoard.box(of:)))
                guard boxes.count == 1, let boxIndex = boxes.first else { continue }
                let box = House(kind: .box, index: boxIndex)
                let removed = box.cells.filter { !line.cells.contains($0) && board.has(digit, at: $0) }
                steps.append(step(.claiming, digit: digit, base: line, cover: box, spots: spots, removed: removed))
            }
        }
        return steps
    }

    /// The row and/or column that contains every cell in `cells`.
    static func sharedLines(of cells: [Int]) -> [House] {
        var lines: [House] = []
        let rows = Set(cells.map(SolverBoard.row(of:)))
        let columns = Set(cells.map(SolverBoard.column(of:)))
        if rows.count == 1, let row = rows.first { lines.append(House(kind: .row, index: row)) }
        if columns.count == 1, let column = columns.first { lines.append(House(kind: .column, index: column)) }
        return lines
    }

    private static func step(_ technique: Technique, digit: Int, base: House, cover: House, spots: [Int], removed: [Int]) -> TechniqueStep {
        TechniqueStep(
            technique: technique, digits: [digit],
            houses: [.init(house: base, role: .base), .init(house: cover, role: .cover)],
            cells: spots.map { .init(cell: $0, role: .defining) },
            eliminations: removed.map { CellDigit(cell: $0, digit: digit) }
        )
    }
}
