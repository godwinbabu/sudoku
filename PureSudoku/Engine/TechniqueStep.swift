import Foundation

/// Curriculum tiers (HINT_STRATEGIES.md).
enum TechniqueTier: Int, Codable, Comparable {
    case basic = 1, intermediate, advanced, expert
    static func < (lhs: TechniqueTier, rhs: TechniqueTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Techniques the logical solver knows, declared in solver order (HINT_STRATEGIES.md). The solver
/// tries them top to bottom and returns the first step it finds.
enum Technique: String, Codable, CaseIterable {
    case fullHouse
    case hiddenSingleBox
    case hiddenSingleLine
    case nakedSingle
    case pointing
    case claiming
    case lockedPair
    case lockedTriple
    case nakedPair
    case hiddenPair
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing
    case swordfish
    case xyWing

    var displayName: String {
        switch self {
        case .fullHouse: return "Full House"
        case .hiddenSingleBox, .hiddenSingleLine: return "Hidden Single"
        case .nakedSingle: return "Naked Single"
        case .pointing: return "Pointing"
        case .claiming: return "Claiming"
        case .lockedPair: return "Locked Pair"
        case .lockedTriple: return "Locked Triple"
        case .nakedPair: return "Naked Pair"
        case .hiddenPair: return "Hidden Pair"
        case .nakedTriple: return "Naked Triple"
        case .hiddenTriple: return "Hidden Triple"
        case .nakedQuad: return "Naked Quad"
        case .hiddenQuad: return "Hidden Quad"
        case .xWing: return "X-Wing"
        case .swordfish: return "Swordfish"
        case .xyWing: return "XY-Wing"
        }
    }

    var tier: TechniqueTier {
        switch self {
        case .fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle: return .basic
        case .xWing, .swordfish, .xyWing: return .advanced
        default: return .intermediate
        }
    }

    /// One-line definition shown at rung 1.
    var definition: String {
        switch self {
        case .fullHouse: return "A row, column or box with one empty cell left."
        case .hiddenSingleBox, .hiddenSingleLine: return "A digit that fits in only one cell of a row, column or box."
        case .nakedSingle: return "A cell with only one candidate left."
        case .pointing: return "In a box, a digit is confined to one row or column, so it leaves the rest of that line."
        case .claiming: return "In a row or column, a digit is confined to one box, so it leaves the rest of that box."
        case .lockedPair, .lockedTriple: return "A naked pair or triple inside one box and one line: it clears both."
        case .nakedPair, .nakedTriple, .nakedQuad: return "Some cells hold only the same few digits, so those digits leave the rest of the house."
        case .hiddenPair, .hiddenTriple, .hiddenQuad: return "Some digits fit only in the same few cells, so those cells drop their other candidates."
        case .xWing: return "A digit in two rows (or columns) lines up in two columns (or rows)."
        case .swordfish: return "An X-Wing across three rows and three columns."
        case .xyWing: return "Three two-candidate cells that force a digit out of the cells they both see."
        }
    }

    var tierName: String {
        switch tier {
        case .basic: return "Basic"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }

    /// Step score for grading (HoDoKu defaults, HINT_STRATEGIES.md).
    var score: Int {
        switch self {
        case .fullHouse, .nakedSingle: return 4
        case .hiddenSingleBox, .hiddenSingleLine: return 14
        case .lockedPair: return 40
        case .pointing, .claiming: return 50
        case .lockedTriple, .nakedPair: return 60
        case .hiddenPair: return 70
        case .nakedTriple: return 80
        case .hiddenTriple: return 100
        case .nakedQuad: return 120
        case .xWing: return 140
        case .hiddenQuad, .swordfish: return 150
        case .xyWing: return 160
        }
    }
}

/// A digit placed in, or removed from, a cell. Digits are 1...9, cells 0...80.
struct CellDigit: Hashable, Codable, Comparable {
    let cell: Int
    let digit: Int

    static func < (lhs: CellDigit, rhs: CellDigit) -> Bool { (lhs.cell, lhs.digit) < (rhs.cell, rhs.digit) }
}

/// One solving step as data (CODESPEC 13.3): what it changes and the pattern that justifies it.
/// The hint panel draws from this; the text comes from `explanation`, one template per technique.
struct TechniqueStep: Equatable, Codable {
    enum HouseRole: String, Codable { case base, cover }
    enum CellRole: String, Codable { case defining, pivot, pincer }

    struct RoleHouse: Equatable, Codable {
        let house: House
        let role: HouseRole
    }

    struct RoleCell: Equatable, Codable {
        let cell: Int
        let role: CellRole
    }

    let technique: Technique
    /// The digits the pattern is about, e.g. the pair in a Naked Pair, or X, Y, Z in an XY-Wing.
    let digits: [Int]
    let houses: [RoleHouse]
    let cells: [RoleCell]
    let placements: [CellDigit]
    let eliminations: [CellDigit]

    init(
        technique: Technique, digits: [Int], houses: [RoleHouse], cells: [RoleCell],
        placements: [CellDigit] = [], eliminations: [CellDigit] = []
    ) {
        self.technique = technique
        self.digits = digits
        self.houses = houses
        self.cells = cells
        self.placements = placements.sorted()
        self.eliminations = eliminations.sorted()
    }

    var changeCount: Int { placements.count + eliminations.count }

    /// Rung 2: where to look.
    func whereText(_ names: CellNameStyle = .short) -> String {
        let looked = houses.map(\.house.name)
        if !looked.isEmpty { return "Look at \(Self.list(looked))." }
        let anchor = cells.first { $0.role == .pivot } ?? cells.first
        guard let anchor else { return "" }
        let suffix = technique == .xyWing ? " and the cells it sees" : ""
        return "Look at \(SolverBoard.name(of: anchor.cell, names))\(suffix)."
    }

    /// Rung 3: why the step works, without giving the result away.
    func reason(_ names: CellNameStyle = .short) -> String {
        let cellNames = Self.list(cells.map { SolverBoard.name(of: $0.cell, names) })
        let baseNames = Self.list(houses.filter { $0.role == .base }.map(\.house.name))
        let coverNames = Self.list(houses.filter { $0.role == .cover }.map(\.house.name))
        let digitList = Self.list(digits.map(String.init))
        switch technique {
        case .fullHouse:
            return "\(baseNames.capitalizedFirst) has one empty cell left: \(cellNames)."
        case .hiddenSingleBox, .hiddenSingleLine:
            return "In \(baseNames), \(digitList) can go in only one cell."
        case .nakedSingle:
            return "\(cellNames.capitalizedFirst) has only one candidate left."
        case .pointing, .claiming, .xWing, .swordfish:
            return "In \(baseNames), \(digitList) can only go in \(coverNames). "
                + "So \(digitList) can't go anywhere else in \(coverNames)."
        case .lockedPair, .lockedTriple, .nakedPair, .nakedTriple, .nakedQuad:
            return "\(cellNames.capitalizedFirst) hold only \(digitList) between them, so these digits must go in those cells "
                + "and nowhere else in \(baseNames)."
        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            return "In \(baseNames), \(digitList) fit only in \(cellNames). "
                + "Those cells must hold them, so their other candidates can go."
        case .xyWing:
            let pivot = cells.first { $0.role == .pivot }.map { SolverBoard.name(of: $0.cell, names) } ?? ""
            let pincers = Self.list(cells.filter { $0.role == .pincer }.map { SolverBoard.name(of: $0.cell, names) })
            let z = digits.last.map(String.init) ?? ""
            return "Whatever \(pivot) turns out to be, one of \(pincers) must be \(z). "
                + "So a cell that sees both can't be \(z)."
        }
    }

    /// Rung 4: what the step changes.
    func resultText(_ names: CellNameStyle = .short) -> String {
        var parts: [String] = []
        for placement in placements {
            parts.append("Place \(placement.digit) in \(SolverBoard.name(of: placement.cell, names)).")
        }
        let byDigit = Dictionary(grouping: eliminations, by: \.digit)
        for digit in byDigit.keys.sorted() {
            let cellsText = Self.list(byDigit[digit]!.map { SolverBoard.name(of: $0.cell, names) })
            parts.append("Remove \(digit) from \(cellsText).")
        }
        return parts.joined(separator: " ")
    }

    /// Full explanation: reason plus result.
    var explanation: String { reason() + " " + resultText() }
}

/// How cells are named in hint text (CODESPEC 3.3).
enum CellNameStyle: String, Codable {
    /// "r3c5"
    case short
    /// "row 3, column 5"
    case long
}

extension TechniqueStep {
    /// "a", "a and b", "a, b and c".
    static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + last
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
