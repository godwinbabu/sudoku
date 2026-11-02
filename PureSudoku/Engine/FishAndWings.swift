import Foundation

/// X-Wing and Swordfish (Advanced tier).
enum FishDetector {
    /// For one digit: `size` base lines whose candidates all lie in `size` cover lines. The digit
    /// must sit at the crossings, so it leaves the rest of the cover lines.
    static func fish(_ board: SolverBoard, size: Int) -> [TechniqueStep] {
        let technique: Technique = size == 2 ? .xWing : .swordfish
        var steps: [TechniqueStep] = []
        for digit in 1...9 {
            for (baseKind, coverKind) in [(House.Kind.row, House.Kind.column), (.column, .row)] {
                let coverIndex: (Int) -> Int = coverKind == .column ? SolverBoard.column(of:) : SolverBoard.row(of:)
                let bases = (0..<9).map { House(kind: baseKind, index: $0) }.filter {
                    (2...size).contains(board.cells(for: digit, in: $0).count)
                }
                for group in combinations(bases, size: size) {
                    let spots = group.flatMap { board.cells(for: digit, in: $0) }
                    let covers = Set(spots.map(coverIndex)).sorted()
                    guard covers.count == size else { continue }
                    let coverHouses = covers.map { House(kind: coverKind, index: $0) }
                    let removed = coverHouses.flatMap(\.cells).filter { !spots.contains($0) && board.has(digit, at: $0) }
                    steps.append(TechniqueStep(
                        technique: technique, digits: [digit],
                        houses: group.map { .init(house: $0, role: .base) } + coverHouses.map { .init(house: $0, role: .cover) },
                        cells: spots.sorted().map { .init(cell: $0, role: .defining) },
                        eliminations: removed.sorted().map { CellDigit(cell: $0, digit: digit) }
                    ))
                }
            }
        }
        return steps
    }
}

/// XY-Wing (Advanced tier).
enum WingDetector {
    /// A pivot with candidates {X, Y} sees two pincers {X, Z} and {Y, Z}. Either way the pivot
    /// goes, one pincer is Z, so a cell that sees both pincers cannot be Z.
    static func xyWings(_ board: SolverBoard) -> [TechniqueStep] {
        let bivalue = (0..<81).filter { board.values[$0] == 0 && board.candidates[$0].nonzeroBitCount == 2 }
        var steps: [TechniqueStep] = []
        for pivot in bivalue {
            let pivotMask = board.candidates[pivot]
            let wings = bivalue.filter { cell in
                SolverBoard.sees(pivot, cell) && (board.candidates[cell] & pivotMask).nonzeroBitCount == 1
            }
            for pair in combinations(wings, size: 2) {
                let (a, b) = (pair[0], pair[1])
                let maskA = board.candidates[a], maskB = board.candidates[b]
                // The pincers share pivot digits X and Y between them, and one extra digit Z.
                guard maskA & pivotMask != maskB & pivotMask else { continue }
                let zMask = (maskA & ~pivotMask)
                guard zMask != 0, zMask == maskB & ~pivotMask, let z = SolverBoard.digits(in: zMask).first else { continue }
                let x = SolverBoard.digits(in: maskA & pivotMask)[0], y = SolverBoard.digits(in: maskB & pivotMask)[0]
                let removed = (0..<81).filter { cell in
                    cell != pivot && SolverBoard.sees(cell, a) && SolverBoard.sees(cell, b) && board.has(z, at: cell)
                }
                steps.append(TechniqueStep(
                    technique: .xyWing, digits: [x, y, z], houses: [],
                    cells: [.init(cell: pivot, role: .pivot), .init(cell: a, role: .pincer), .init(cell: b, role: .pincer)],
                    eliminations: removed.map { CellDigit(cell: $0, digit: z) }
                ))
            }
        }
        return steps
    }
}
