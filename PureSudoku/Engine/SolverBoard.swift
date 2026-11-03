import Foundation

/// A row, column or box. Cells are listed in reading order.
struct House: Hashable, Codable, Comparable {
    enum Kind: Int, Codable, Comparable {
        case row, column, box
        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let kind: Kind
    let index: Int // 0...8

    var cells: [Int] { SolverBoard.houseCells[kind.rawValue * 9 + index] }

    static func < (lhs: House, rhs: House) -> Bool {
        (lhs.kind, lhs.index) < (rhs.kind, rhs.index)
    }

    static let all: [House] = [Kind.row, .column, .box].flatMap { kind in (0..<9).map { House(kind: kind, index: $0) } }
    static let lines: [House] = all.filter { $0.kind != .box }
    static let boxes: [House] = all.filter { $0.kind == .box }
    static let rows: [House] = all.filter { $0.kind == .row }
    static let columns: [House] = all.filter { $0.kind == .column }
}

/// Board for the logical solver (CODESPEC 13.3): a value per cell and a 9-bit candidate mask.
/// Cells are 0...80 in reading order. Digits are 1...9; bit (d - 1) set means d is still possible.
/// Filled cells have an empty mask.
struct SolverBoard: Equatable {
    private(set) var values: [Int] // 0 = empty
    private(set) var candidates: [UInt16]

    static let allDigits: UInt16 = 0x1FF

    /// Candidates computed from the placed values.
    init(values: [Int]) {
        precondition(values.count == 81, "a board has 81 cells")
        self.values = values
        candidates = (0..<81).map { cell in
            guard values[cell] == 0 else { return 0 }
            var mask = SolverBoard.allDigits
            for peer in SolverBoard.peers[cell] where values[peer] != 0 {
                mask &= ~SolverBoard.bit(values[peer])
            }
            return mask
        }
    }

    /// Uses the player's notes where a cell has any (CODESPEC 6.3.1). Notes that conflict with a
    /// placed digit are ignored; cells without notes get computed candidates.
    init(values: [Int], notes: [Set<Int>]) {
        self.init(values: values)
        for cell in 0..<81 where values[cell] == 0 && !notes[cell].isEmpty {
            candidates[cell] &= SolverBoard.mask(of: notes[cell])
        }
    }

    /// Exact candidate masks, for tests and lessons that need a specific pattern.
    init(values: [Int], candidates: [UInt16]) {
        precondition(values.count == 81 && candidates.count == 81, "a board has 81 cells")
        self.values = values
        self.candidates = candidates.enumerated().map { values[$0.offset] == 0 ? $0.element & SolverBoard.allDigits : 0 }
    }

    /// From an 81-character grid ("0" or "." for empty). Returns nil for a malformed grid.
    init?(grid: String) {
        let values = grid.map { Int(String($0)) ?? 0 }
        guard values.count == 81, values.allSatisfy({ (0...9).contains($0) }) else { return nil }
        self.init(values: values)
    }

    /// From game cells, using the player's notes.
    init(cells: [SudokuCell]) {
        var values = Array(repeating: 0, count: 81)
        var notes = Array(repeating: Set<Int>(), count: 81)
        for cell in cells {
            let index = cell.row * 9 + cell.col
            values[index] = cell.value ?? 0
            notes[index] = cell.candidates
        }
        self.init(values: values, notes: notes)
    }

    var isSolved: Bool { !values.contains(0) }

    /// True if a digit repeats in a house, or an empty cell has no candidates left.
    var hasContradiction: Bool {
        for cell in 0..<81 {
            if values[cell] == 0 {
                if candidates[cell] == 0 { return true }
            } else if SolverBoard.peers[cell].contains(where: { values[$0] == values[cell] }) {
                return true
            }
        }
        return false
    }

    func has(_ digit: Int, at cell: Int) -> Bool {
        candidates[cell] & SolverBoard.bit(digit) != 0
    }

    /// Empty cells of `house` that still allow `digit`.
    func cells(for digit: Int, in house: House) -> [Int] {
        house.cells.filter { has(digit, at: $0) }
    }

    mutating func apply(_ step: TechniqueStep) {
        for placement in step.placements {
            place(placement.digit, at: placement.cell)
        }
        for elimination in step.eliminations {
            candidates[elimination.cell] &= ~SolverBoard.bit(elimination.digit)
        }
    }

    mutating func place(_ digit: Int, at cell: Int) {
        values[cell] = digit
        candidates[cell] = 0
        for peer in SolverBoard.peers[cell] {
            candidates[peer] &= ~SolverBoard.bit(digit)
        }
    }

    // MARK: - Tables and bit helpers

    static func bit(_ digit: Int) -> UInt16 { 1 << UInt16(digit - 1) }

    static func digits(in mask: UInt16) -> [Int] {
        (1...9).filter { mask & bit($0) != 0 }
    }

    static func mask(of digits: some Sequence<Int>) -> UInt16 {
        digits.reduce(0) { (1...9).contains($1) ? $0 | bit($1) : $0 }
    }

    static func row(of cell: Int) -> Int { cell / 9 }
    static func column(of cell: Int) -> Int { cell % 9 }
    static func box(of cell: Int) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }

    static func sees(_ a: Int, _ b: Int) -> Bool { a != b && peerSets[a].contains(b) }

    /// Cells of the 27 houses: rows 0-8, columns 9-17, boxes 18-26.
    static let houseCells: [[Int]] = (0..<9).map { r in (0..<9).map { r * 9 + $0 } }
        + (0..<9).map { c in (0..<9).map { $0 * 9 + c } }
        + (0..<9).map { b in (0..<9).map { ((b / 3) * 3 + $0 / 3) * 9 + (b % 3) * 3 + $0 % 3 } }

    static let peerSets: [Set<Int>] = Board.peers
    static let peers: [[Int]] = Board.peers.map { $0.sorted() }
}
