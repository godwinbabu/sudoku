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

    /// Plain-language explanation of the step (rung 3 text).
    var explanation: String {
        let cellNames = Self.list(cells.map { SolverBoard.name(of: $0.cell) })
        let baseNames = Self.list(houses.filter { $0.role == .base }.map(\.house.name))
        let coverNames = Self.list(houses.filter { $0.role == .cover }.map(\.house.name))
        let digitList = Self.list(digits.map(String.init))
        let removed = eliminations.map { SolverBoard.name(of: $0.cell) }.joined(separator: ", ")
        switch technique {
        case .fullHouse:
            return "\(baseNames.capitalizedFirst) has one empty cell left, so \(cellNames) is \(digitList)."
        case .hiddenSingleBox, .hiddenSingleLine:
            return "In \(baseNames), \(digitList) fits only in \(cellNames)."
        case .nakedSingle:
            return "\(cellNames) has only one candidate left: \(digitList)."
        case .pointing, .claiming, .xWing, .swordfish:
            return "In \(baseNames), \(digitList) can only go in \(coverNames). "
                + "So \(digitList) can be removed from the rest of \(coverNames): \(removed)."
        case .lockedPair, .lockedTriple, .nakedPair, .nakedTriple, .nakedQuad:
            return "\(cellNames) hold only \(digitList) between them, so these digits must go in those cells. "
                + "Remove them from the rest of \(baseNames): \(removed)."
        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            return "In \(baseNames), \(digitList) fit only in \(cellNames). "
                + "Those cells must hold them, so their other candidates can go."
        case .xyWing:
            let pivot = cells.first { $0.role == .pivot }.map { SolverBoard.name(of: $0.cell) } ?? ""
            let pincers = cells.filter { $0.role == .pincer }.map { SolverBoard.name(of: $0.cell) }.joined(separator: " and ")
            let z = digits.last.map(String.init) ?? ""
            return "Whatever \(pivot) turns out to be, one of \(pincers) must be \(z). "
                + "So any cell that sees both can't be \(z): \(removed)."
        }
    }
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
