import Foundation

/// Single-digit patterns: Skyscraper, 2-String Kite, Empty Rectangle (Advanced tier).
enum SingleDigitDetector {
    /// Houses where `digit` has exactly two places: a strong link (one of the two must be it).
    static func strongLinks(_ board: SolverBoard, digit: Int, in houses: [House]) -> [(house: House, a: Int, b: Int)] {
        houses.compactMap { house in
            let spots = board.cells(for: digit, in: house)
            return spots.count == 2 ? (house, spots[0], spots[1]) : nil
        }
    }

    /// Two strong links in parallel lines with one end in the same cross line: one of the other
    /// two ends is the digit, so a cell that sees both of them can't be.
    static func skyscrapers(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for digit in 1...9 {
            for (lineKind, cross) in [(House.Kind.row, SolverBoard.column(of:)), (.column, SolverBoard.row(of:))] {
                let lines = (0..<9).map { House(kind: lineKind, index: $0) }
                for pair in combinations(strongLinks(board, digit: digit, in: lines), size: 2) {
                    let (first, second) = (pair[0], pair[1])
                    for (base1, top1) in [(first.a, first.b), (first.b, first.a)] {
                        for (base2, top2) in [(second.a, second.b), (second.b, second.a)]
                        where cross(base1) == cross(base2) && cross(top1) != cross(top2) {
                            let removed = seeingBoth(top1, top2, digit: digit, board: board, excluding: [base1, base2])
                            steps.append(TechniqueStep(
                                technique: .skyscraper, digits: [digit],
                                houses: [.init(house: first.house, role: .base), .init(house: second.house, role: .base)],
                                cells: [base1, top1, base2, top2].map { .init(cell: $0, role: .defining) },
                                eliminations: removed.map { CellDigit(cell: $0, digit: digit) }
                            ))
                        }
                    }
                }
            }
        }
        return steps
    }

    /// A row strong link and a column strong link joined inside one box: the cell where the other
    /// ends' lines cross can't be the digit.
    static func twoStringKites(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for digit in 1...9 {
            let rows = strongLinks(board, digit: digit, in: (0..<9).map { House(kind: .row, index: $0) })
            let columns = strongLinks(board, digit: digit, in: (0..<9).map { House(kind: .column, index: $0) })
            for row in rows {
                for column in columns {
                    for (rowEnd, rowOther) in [(row.a, row.b), (row.b, row.a)] {
                        for (columnEnd, columnOther) in [(column.a, column.b), (column.b, column.a)] {
                            let box = SolverBoard.box(of: rowEnd)
                            guard rowEnd != columnEnd, SolverBoard.box(of: columnEnd) == box,
                                  SolverBoard.box(of: rowOther) != box, SolverBoard.box(of: columnOther) != box else { continue }
                            let target = SolverBoard.row(of: columnOther) * 9 + SolverBoard.column(of: rowOther)
                            guard board.has(digit, at: target), ![rowEnd, rowOther, columnEnd, columnOther].contains(target) else { continue }
                            steps.append(TechniqueStep(
                                technique: .twoStringKite, digits: [digit],
                                houses: [.init(house: row.house, role: .base), .init(house: column.house, role: .base),
                                         .init(house: House(kind: .box, index: box), role: .cover)],
                                cells: [rowOther, rowEnd, columnEnd, columnOther].map { .init(cell: $0, role: .defining) },
                                eliminations: [CellDigit(cell: target, digit: digit)]
                            ))
                        }
                    }
                }
            }
        }
        return steps
    }

    /// In a box, the digit sits only on one row and one column (a cross). A strong link outside
    /// the box with one end on that row (or column) removes the digit where its other end's line
    /// meets the cross's column (or row).
    static func emptyRectangles(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for digit in 1...9 {
            for boxIndex in 0..<9 {
                let box = House(kind: .box, index: boxIndex)
                let spots = board.cells(for: digit, in: box)
                guard spots.count >= 2 else { continue }
                let boxRows = Set(box.cells.map(SolverBoard.row(of:)))
                let boxColumns = Set(box.cells.map(SolverBoard.column(of:)))
                for row in boxRows.sorted() {
                    for column in boxColumns.sorted() {
                        let onCross = spots.allSatisfy { SolverBoard.row(of: $0) == row || SolverBoard.column(of: $0) == column }
                        let oneLine = spots.allSatisfy { SolverBoard.row(of: $0) == row } || spots.allSatisfy { SolverBoard.column(of: $0) == column }
                        guard onCross, !oneLine else { continue }
                        // Strong link in a column outside the box, one end on the cross row.
                        for link in strongLinks(board, digit: digit, in: (0..<9).filter { !boxColumns.contains($0) }.map { House(kind: .column, index: $0) }) {
                            for (near, far) in [(link.a, link.b), (link.b, link.a)]
                            where SolverBoard.row(of: near) == row && !boxRows.contains(SolverBoard.row(of: far)) {
                                let target = SolverBoard.row(of: far) * 9 + column
                                guard board.has(digit, at: target) else { continue }
                                steps.append(step(digit, box, row, column, link.house, spots + [near, far], target))
                            }
                        }
                        // Strong link in a row outside the box, one end on the cross column.
                        for link in strongLinks(board, digit: digit, in: (0..<9).filter { !boxRows.contains($0) }.map { House(kind: .row, index: $0) }) {
                            for (near, far) in [(link.a, link.b), (link.b, link.a)]
                            where SolverBoard.column(of: near) == column && !boxColumns.contains(SolverBoard.column(of: far)) {
                                let target = row * 9 + SolverBoard.column(of: far)
                                guard board.has(digit, at: target) else { continue }
                                steps.append(step(digit, box, row, column, link.house, spots + [near, far], target))
                            }
                        }
                    }
                }
            }
        }
        return steps
    }

    private static func step(_ digit: Int, _ box: House, _ row: Int, _ column: Int, _ link: House, _ cells: [Int], _ target: Int) -> TechniqueStep {
        TechniqueStep(
            technique: .emptyRectangle, digits: [digit],
            houses: [.init(house: box, role: .base), .init(house: link, role: .base),
                     .init(house: House(kind: .row, index: row), role: .cover), .init(house: House(kind: .column, index: column), role: .cover)],
            cells: cells.map { .init(cell: $0, role: .defining) },
            eliminations: [CellDigit(cell: target, digit: digit)]
        )
    }

    /// Cells holding `digit` that see both `a` and `b`, other than the listed pattern cells.
    static func seeingBoth(_ a: Int, _ b: Int, digit: Int, board: SolverBoard, excluding: [Int] = []) -> [Int] {
        (0..<81).filter { cell in
            cell != a && cell != b && !excluding.contains(cell) && board.has(digit, at: cell)
                && SolverBoard.sees(cell, a) && SolverBoard.sees(cell, b)
        }
    }
}

/// XYZ-Wing and W-Wing (Advanced tier).
enum MoreWingsDetector {
    /// Pivot {X,Y,Z} with pincers {X,Z} and {Y,Z}: one of the three is Z, so a cell that sees all
    /// three can't be Z.
    static func xyzWings(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for pivot in 0..<81 where board.values[pivot] == 0 && board.candidates[pivot].nonzeroBitCount == 3 {
            let mask = board.candidates[pivot]
            let pincers = SolverBoard.peers[pivot].filter { cell in
                board.values[cell] == 0 && board.candidates[cell].nonzeroBitCount == 2 && board.candidates[cell] & ~mask == 0
            }
            for pair in combinations(pincers, size: 2) {
                let (a, b) = (pair[0], pair[1])
                let (maskA, maskB) = (board.candidates[a], board.candidates[b])
                guard maskA != maskB, maskA | maskB == mask, let z = SolverBoard.digits(in: maskA & maskB).first else { continue }
                let removed = SingleDigitDetector.seeingBoth(a, b, digit: z, board: board, excluding: [pivot]).filter { SolverBoard.sees($0, pivot) }
                steps.append(TechniqueStep(
                    technique: .xyzWing, digits: SolverBoard.digits(in: mask).filter { $0 != z } + [z], houses: [],
                    cells: [.init(cell: pivot, role: .pivot), .init(cell: a, role: .pincer), .init(cell: b, role: .pincer)],
                    eliminations: removed.map { CellDigit(cell: $0, digit: z) }
                ))
            }
        }
        return steps
    }

    /// Two cells with the same pair {X,Y} that don't see each other, joined by a strong link on X:
    /// one of them is Y, so a cell that sees both can't be Y.
    static func wWings(_ board: SolverBoard) -> [TechniqueStep] {
        let bivalue = (0..<81).filter { board.values[$0] == 0 && board.candidates[$0].nonzeroBitCount == 2 }
        var steps: [TechniqueStep] = []
        for pair in combinations(bivalue, size: 2) {
            let (a, b) = (pair[0], pair[1])
            guard board.candidates[a] == board.candidates[b], !SolverBoard.sees(a, b) else { continue }
            let digits = SolverBoard.digits(in: board.candidates[a])
            for (link, other) in [(digits[0], digits[1]), (digits[1], digits[0])] {
                for strong in SingleDigitDetector.strongLinks(board, digit: link, in: House.all) {
                    let ends = [strong.a, strong.b]
                    guard !ends.contains(a), !ends.contains(b) else { continue }
                    let joined = (SolverBoard.sees(strong.a, a) && SolverBoard.sees(strong.b, b))
                        || (SolverBoard.sees(strong.a, b) && SolverBoard.sees(strong.b, a))
                    guard joined else { continue }
                    let removed = SingleDigitDetector.seeingBoth(a, b, digit: other, board: board)
                    steps.append(TechniqueStep(
                        technique: .wWing, digits: [link, other], houses: [.init(house: strong.house, role: .base)],
                        cells: [.init(cell: a, role: .pincer), .init(cell: strong.a, role: .defining),
                                .init(cell: strong.b, role: .defining), .init(cell: b, role: .pincer)],
                        eliminations: removed.map { CellDigit(cell: $0, digit: other) }
                    ))
                }
            }
        }
        return steps
    }
}

/// Simple Coloring (Advanced tier): two-color one digit's chain of strong links.
enum ColoringDetector {
    static func simpleColoring(_ board: SolverBoard) -> [TechniqueStep] {
        var steps: [TechniqueStep] = []
        for digit in 1...9 {
            var neighbors: [Int: [Int]] = [:]
            for link in SingleDigitDetector.strongLinks(board, digit: digit, in: House.all) {
                neighbors[link.a, default: []].append(link.b)
                neighbors[link.b, default: []].append(link.a)
            }
            var color: [Int: Int] = [:]
            for start in neighbors.keys.sorted() where color[start] == nil {
                // Breadth-first two-coloring of one chain.
                var chain = [start]
                color[start] = 0
                var index = 0
                while index < chain.count {
                    let cell = chain[index]
                    for next in neighbors[cell] ?? [] where color[next] == nil {
                        color[next] = 1 - color[cell]!
                        chain.append(next)
                    }
                    index += 1
                }
                guard chain.count >= 3 else { continue } // two cells are just a strong link
                let groups = [0, 1].map { side in chain.filter { color[$0] == side }.sorted() }
                let cells = chain.sorted().map { TechniqueStep.RoleCell(cell: $0, role: .defining) }
                // Wrap: two cells of one color see each other, so that color is false.
                for side in [0, 1] where combinations(groups[side], size: 2).contains(where: { SolverBoard.sees($0[0], $0[1]) }) {
                    steps.append(TechniqueStep(
                        technique: .simpleColoring, digits: [digit], houses: [], cells: cells,
                        eliminations: groups[side].map { CellDigit(cell: $0, digit: digit) }
                    ))
                }
                // Trap: a cell outside the chain that sees both colors can't be the digit.
                let trapped = (0..<81).filter { cell in
                    color[cell] == nil && board.has(digit, at: cell)
                        && groups[0].contains { SolverBoard.sees(cell, $0) } && groups[1].contains { SolverBoard.sees(cell, $0) }
                }
                if !trapped.isEmpty {
                    steps.append(TechniqueStep(
                        technique: .simpleColoring, digits: [digit], houses: [], cells: cells,
                        eliminations: trapped.map { CellDigit(cell: $0, digit: digit) }
                    ))
                }
            }
        }
        return steps
    }
}

/// Unique Rectangles and BUG+1 (Advanced tier). These assume the puzzle has exactly one
/// solution; the solver runs them only when it may (CODESPEC 2.1).
enum UniquenessDetector {
    /// Four cells in two rows, two columns and two boxes that could all hold only {A,B} would
    /// allow two solutions. Types 1, 2 and 4 remove what would complete that deadly pattern.
    static func uniqueRectangles(_ board: SolverBoard, type: Int) -> [TechniqueStep] {
        let technique: Technique = [1: .uniqueRectangle1, 2: .uniqueRectangle2, 4: .uniqueRectangle4][type]!
        var steps: [TechniqueStep] = []
        for rows in combinations(Array(0..<9), size: 2) {
            for columns in combinations(Array(0..<9), size: 2) {
                let corners = [rows[0] * 9 + columns[0], rows[0] * 9 + columns[1], rows[1] * 9 + columns[0], rows[1] * 9 + columns[1]]
                guard corners.allSatisfy({ board.values[$0] == 0 }), Set(corners.map(SolverBoard.box(of:))).count == 2 else { continue }
                let shared = corners.reduce(SolverBoard.allDigits) { $0 & board.candidates[$1] }
                for pair in combinations(SolverBoard.digits(in: shared), size: 2) {
                    let pairMask = SolverBoard.mask(of: pair)
                    let floor = corners.filter { board.candidates[$0] == pairMask }
                    let roof = corners.filter { board.candidates[$0] != pairMask }
                    let cells = corners.map { TechniqueStep.RoleCell(cell: $0, role: roof.contains($0) ? .pincer : .defining) }
                    switch type {
                    case 1 where floor.count == 3:
                        steps.append(TechniqueStep(technique: technique, digits: pair, houses: [], cells: cells,
                                                   eliminations: pair.filter { board.has($0, at: roof[0]) }.map { CellDigit(cell: roof[0], digit: $0) }))
                    case 2 where floor.count == 2 && roof.count == 2 && sameLine(roof[0], roof[1]):
                        let extra = board.candidates[roof[0]] & ~pairMask
                        guard extra.nonzeroBitCount == 1, board.candidates[roof[1]] == board.candidates[roof[0]],
                              let digit = SolverBoard.digits(in: extra).first else { continue }
                        let removed = SingleDigitDetector.seeingBoth(roof[0], roof[1], digit: digit, board: board, excluding: corners)
                        steps.append(TechniqueStep(technique: technique, digits: pair + [digit], houses: [], cells: cells,
                                                   eliminations: removed.map { CellDigit(cell: $0, digit: digit) }))
                    case 4 where floor.count == 2 && roof.count == 2 && sameLine(roof[0], roof[1]):
                        for (locked, other) in [(pair[0], pair[1]), (pair[1], pair[0])] {
                            let lockedHouse = housesContaining(roof[0], roof[1]).first { board.cells(for: locked, in: $0) == roof.sorted() }
                            guard let house = lockedHouse else { continue }
                            steps.append(TechniqueStep(technique: technique, digits: [locked, other], houses: [.init(house: house, role: .base)], cells: cells,
                                                       eliminations: roof.filter { board.has(other, at: $0) }.map { CellDigit(cell: $0, digit: other) }))
                        }
                    default:
                        continue
                    }
                }
            }
        }
        return steps
    }

    /// Every empty cell has two candidates except one with three. That cell must take the digit
    /// that appears three times in its row, column and box, or the puzzle would have two solutions.
    static func bugPlusOne(_ board: SolverBoard) -> [TechniqueStep] {
        let empty = (0..<81).filter { board.values[$0] == 0 }
        // The BUG argument needs every unplaced digit to have at least two places in every house
        // (no hidden single waiting); don't rely on singles having run first.
        for house in House.all {
            let placed = Set(house.cells.map { board.values[$0] })
            if (1...9).contains(where: { !placed.contains($0) && board.cells(for: $0, in: house).count < 2 }) { return [] }
        }
        let triple = empty.filter { board.candidates[$0].nonzeroBitCount == 3 }
        guard triple.count == 1, let cell = triple.first,
              empty.allSatisfy({ $0 == cell || board.candidates[$0].nonzeroBitCount == 2 }) else { return [] }
        let houses = House.all.filter { $0.cells.contains(cell) }
        let digit = SolverBoard.digits(in: board.candidates[cell]).first { digit in
            houses.allSatisfy { board.cells(for: digit, in: $0).count == 3 }
        }
        guard let digit else { return [] }
        return [TechniqueStep(
            technique: .bugPlusOne, digits: [digit], houses: houses.map { .init(house: $0, role: .base) },
            cells: [.init(cell: cell, role: .defining)], placements: [CellDigit(cell: cell, digit: digit)]
        )]
    }

    private static func sameLine(_ a: Int, _ b: Int) -> Bool {
        SolverBoard.row(of: a) == SolverBoard.row(of: b) || SolverBoard.column(of: a) == SolverBoard.column(of: b)
    }

    private static func housesContaining(_ a: Int, _ b: Int) -> [House] {
        House.all.filter { $0.cells.contains(a) && $0.cells.contains(b) }
    }
}
