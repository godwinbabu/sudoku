import Foundation

/// Curriculum tiers (HINT_STRATEGIES.md).
enum TechniqueTier: Int, Codable, Comparable {
    case basic = 1, intermediate, advanced, expert

    /// Shown on hint cards and in Learn.
    var displayName: String {
        switch self {
        case .basic: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
    static func < (lhs: TechniqueTier, rhs: TechniqueTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Techniques the logical solver knows, declared in solver order (HINT_STRATEGIES.md). The solver
/// tries them top to bottom and returns the first step it finds.
enum Technique: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

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
    case skyscraper
    case twoStringKite
    case emptyRectangle
    case swordfish
    case xyWing
    case xyzWing
    case wWing
    case simpleColoring
    case uniqueRectangle1
    case uniqueRectangle2
    case uniqueRectangle4
    case bugPlusOne

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
        case .skyscraper: return "Skyscraper"
        case .twoStringKite: return "2-String Kite"
        case .emptyRectangle: return "Empty Rectangle"
        case .xyzWing: return "XYZ-Wing"
        case .wWing: return "W-Wing"
        case .simpleColoring: return "Simple Coloring"
        case .uniqueRectangle1: return "Unique Rectangle"
        case .uniqueRectangle2: return "Unique Rectangle (Type 2)"
        case .uniqueRectangle4: return "Unique Rectangle (Type 4)"
        case .bugPlusOne: return "BUG+1"
        }
    }

    var tier: TechniqueTier {
        switch self {
        case .fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle: return .basic
        case .xWing, .swordfish, .xyWing, .skyscraper, .twoStringKite, .emptyRectangle, .xyzWing, .wWing, .simpleColoring,
             .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4, .bugPlusOne: return .advanced
        default: return .intermediate
        }
    }

    /// Assumes the puzzle has exactly one solution (CODESPEC 2.1).
    var needsUniqueSolution: Bool {
        [.uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4, .bugPlusOne].contains(self)
    }

    /// One-line definition, shown at hint step 2 ("short").
    var definition: String {
        switch self {
        case .fullHouse: return "A row, column or box with one empty cell left."
        case .hiddenSingleBox, .hiddenSingleLine: return "A digit with only one possible home in a row, column or box."
        case .nakedSingle: return "A cell that can only hold one digit."
        case .pointing: return "In a box, a digit is confined to one line, so it leaves the rest of that line."
        case .claiming: return "In a line, a digit is confined to one box, so it leaves the rest of that box."
        case .lockedPair, .lockedTriple: return "A naked pair or triple inside one box and one line: it clears both."
        case .nakedPair, .nakedTriple, .nakedQuad: return "Some cells hold only the same few digits, so those digits leave the rest of the house."
        case .hiddenPair, .hiddenTriple, .hiddenQuad: return "Some digits fit only in the same few cells, so those cells drop their other candidates."
        case .xWing: return "A digit in two rows (or columns) lines up in two columns (or rows)."
        case .swordfish: return "An X-Wing across three rows and three columns."
        case .xyWing: return "Three two-candidate cells that force a digit out of the cells they both see."
        case .skyscraper: return "Two strong links on one digit that share one end line; the cells seeing both free ends lose it."
        case .twoStringKite: return "A row link and a column link on one digit, joined in a box."
        case .emptyRectangle: return "A digit confined to a cross in one box, used with a strong link outside the box."
        case .xyzWing: return "Like an XY-Wing, but the pivot also holds the shared digit."
        case .wWing: return "Two cells with the same pair, joined by a strong link on one of the digits."
        case .simpleColoring: return "Color one digit's strong links in two colors: exactly one color is true."
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4:
            return "Four cells that would allow two solutions; a one-solution puzzle must avoid that."
        case .bugPlusOne: return "All cells but one have two candidates; that one must break the tie."
        }
    }

    var tierName: String { tier.displayName }

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
        case .emptyRectangle: return 120
        case .skyscraper: return 130
        case .twoStringKite, .wWing, .simpleColoring: return 150
        case .xyzWing: return 180
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4, .bugPlusOne: return 100
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
/// The hint card draws from this (see the graduated hint fields below); one text template per technique.
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

    /// Where to look, for techniques without their own nudge.
    func whereText(_ names: CellNotation = .plain) -> String {
        let looked = houses.map { names.house($0.house) }
        if !looked.isEmpty { return "Look at \(Self.list(looked))." }
        let anchor = cells.first { $0.role == .pivot } ?? cells.first
        guard let anchor else { return "" }
        let suffix = technique == .xyWing ? " and the cells it sees" : ""
        return "Look at \(names.cell(anchor.cell))\(suffix)."
    }

    /// Why the step works, without giving the result away.
    func reason(_ names: CellNotation = .plain) -> String {
        let cellNames = Self.list(cells.map { names.cell($0.cell) })
        let baseNames = Self.list(houses.filter { $0.role == .base }.map { names.house($0.house) })
        let coverNames = Self.list(houses.filter { $0.role == .cover }.map { names.house($0.house) })
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
        case .xyWing, .xyzWing:
            let pivot = cells.first { $0.role == .pivot }.map { names.cell($0.cell) } ?? ""
            let pincers = Self.list(cells.filter { $0.role == .pincer }.map { names.cell($0.cell) })
            let z = digits.last.map(String.init) ?? ""
            let seers = technique == .xyzWing ? "all three" : "both"
            return "Whatever \(pivot) turns out to be, one of \(technique == .xyzWing ? pivot + ", " : "")\(pincers) must be \(z). "
                + "So a cell that sees \(seers) can't be \(z)."
        case .skyscraper:
            return "In \(baseNames), \(digitList) has only two places each, and one end of each lines up. "
                + "So one of the other two ends is \(digitList), and a cell that sees both can't be."
        case .twoStringKite:
            return "In \(baseNames), \(digitList) has only two places each, and the two links meet in \(coverNames). "
                + "So one of the far ends is \(digitList), and the cell where their lines cross can't be."
        case .emptyRectangle:
            let box = houses.first.map { names.house($0.house) } ?? ""
            let link = houses.dropFirst().first.map { names.house($0.house) } ?? ""
            return "In \(box), \(digitList) sits only on one row and one column. "
                + "Together with the strong link in \(link), that rules out one cell."
        case .wWing:
            let ends = Self.list(cells.filter { $0.role == .pincer }.map { names.cell($0.cell) })
            let (link, other) = (digits.first.map(String.init) ?? "", digits.last.map(String.init) ?? "")
            return "\(ends.capitalizedFirst) both hold only \(link) and \(other). A strong link on \(link) in \(baseNames) "
                + "means one of them is \(other), so a cell that sees both can't be \(other)."
        case .simpleColoring:
            return "Color \(digitList)'s strong links in two colors: one color is all \(digitList), the other has none. "
                + "That rules out \(digitList) where the colors clash or meet."
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4:
            return "\(cellNames.capitalizedFirst) form a rectangle that could hold only \(Self.list(digits.prefix(2).map(String.init))). "
                + "That would allow two solutions, and the puzzle has one, so something must break it."
        case .bugPlusOne:
            return "Every other empty cell has two candidates. If \(cellNames) weren't the right digit, the puzzle would have two solutions."
        }
    }

    /// What the step changes.
    func resultText(_ names: CellNotation = .plain) -> String {
        var parts: [String] = []
        for placement in placements {
            parts.append("Place \(placement.digit) in \(names.cell(placement.cell)).")
        }
        let byDigit = Dictionary(grouping: eliminations, by: \.digit)
        for digit in byDigit.keys.sorted() {
            let cellsText = Self.list(byDigit[digit]!.map { names.cell($0.cell) })
            parts.append("Remove \(digit) from \(cellsText).")
        }
        return parts.joined(separator: " ")
    }

    /// Full explanation: reason plus result.
    var explanation: String { reason() + " " + resultText() }
}

// MARK: - Graduated hint fields (CODESPEC 6.3, matching the design's engine.js)

extension TechniqueStep {
    /// The cell and digit the step places, if it places one (the dashed target at step 3).
    var target: CellDigit? { placements.first }

    /// Step 1 spotlight: the houses to look at (a Naked Single lights its row, column and box).
    var focus: Set<Int> {
        if technique == .nakedSingle, let cell = cells.first?.cell { return Set(SolverBoard.peers[cell]).union([cell]) }
        let houseCells = Set(houses.flatMap(\.house.cells))
        if !houseCells.isEmpty { return houseCells }
        return Set((cells.first { $0.role == .pivot } ?? cells.first).map { [$0.cell] } ?? [])
    }

    /// Step 2 fill. For a single the pattern cell is the answer, so it waits for the target at step 3.
    var pattern: Set<Int> { placements.isEmpty ? Set(cells.map(\.cell)) : [] }

    /// Step 3 rings: the placed digits that prove a single. Empty for other techniques.
    func evidence(on board: SolverBoard) -> Set<Int> {
        guard let target else { return [] }
        switch technique {
        case .hiddenSingleBox, .hiddenSingleLine:
            let others = houses.first.map(\.house.cells)?.filter { $0 != target.cell && board.values[$0] == 0 } ?? []
            return Set(others.compactMap { Self.blocker(of: $0, digit: target.digit, on: board) })
        case .nakedSingle:
            return Set(Self.seenDigits(from: target.cell, on: board).values)
        default:
            return []
        }
    }

    /// Step 1 text.
    func nudge(_ names: CellNotation) -> String {
        guard let target, let house = houses.first?.house else {
            if technique == .nakedSingle, let target {
                return "One cell in \(names.box(SolverBoard.box(of: target.cell))) is nearly decided."
            }
            return whereText(names)
        }
        switch technique {
        case .fullHouse: return "Look at \(names.house(house))."
        case .hiddenSingleBox, .hiddenSingleLine: return "Look at \(names.house(house)). Where can \(target.digit) go?"
        default: return whereText(names)
        }
    }

    /// Step 3 text: why the step works and what it changes. Removals from several cells are not
    /// listed: the reason already says where the digit goes, and the board strikes them through
    /// (the card is 124 pt tall).
    func why(_ names: CellNotation, on board: SolverBoard) -> String {
        guard let target else {
            return Set(eliminations.map(\.cell)).count > 1 ? reason(names) : reason(names) + " " + resultText(names)
        }
        let digit = target.digit, cell = names.cell(target.cell)
        let house = houses.first.map { names.house($0.house) } ?? ""
        switch technique {
        case .fullHouse:
            return "\(house.capitalizedFirst) has one empty cell left, and the only digit missing is \(digit)."
        case .hiddenSingleBox, .hiddenSingleLine:
            let others = houses.first.map(\.house.cells)?.filter { $0 != target.cell && board.values[$0] == 0 } ?? []
            let allSee = others.allSatisfy { Self.blocker(of: $0, digit: digit, on: board) != nil }
            let sees = allSee ? "already sees" : "sees or has ruled out"
            return "Every other empty cell in \(house) \(sees) \(CellNotation.withArticle(digit)). So \(digit) can only go in \(cell)."
        case .nakedSingle:
            let seen = Self.seenDigits(from: target.cell, on: board).keys.sorted()
            guard seen.count == 8 else {
                return "\(cell.capitalizedFirst) has every digit but \(digit) ruled out. Only \(digit) is left."
            }
            return "\(cell.capitalizedFirst) already sees \(Self.list(seen.map(String.init))) in its row, column and box. "
                + "Only \(digit) is left."
        default:
            return reason(names) + " " + resultText(names)
        }
    }

    /// The first peer of `cell` that holds `digit`.
    private static func blocker(of cell: Int, digit: Int, on board: SolverBoard) -> Int? {
        SolverBoard.peers[cell].first { board.values[$0] == digit }
    }

    /// For each digit placed in a peer of `cell`, the first peer holding it.
    private static func seenDigits(from cell: Int, on board: SolverBoard) -> [Int: Int] {
        var seen: [Int: Int] = [:]
        for peer in SolverBoard.peers[cell] where board.values[peer] != 0 && seen[board.values[peer]] == nil {
            seen[board.values[peer]] = peer
        }
        return seen
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
