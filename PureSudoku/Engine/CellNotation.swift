import Foundation

/// How hint and lesson text names cells and houses (CODESPEC 3.3). Every message goes through it.
enum CellNotation: String, Codable, CaseIterable, Identifiable {
    /// "row 5, column 2", "box 4"
    case plain
    /// "R5C2", "B4"
    case grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plain: return "row 5, column 2"
        case .grid: return "R5C2"
        }
    }

    /// A cell, 0...80.
    func cell(_ index: Int) -> String {
        let row = SolverBoard.row(of: index) + 1, column = SolverBoard.column(of: index) + 1
        switch self {
        case .plain: return "row \(row), column \(column)"
        case .grid: return "R\(row)C\(column)"
        }
    }

    func house(_ house: House) -> String {
        let number = house.index + 1
        switch (self, house.kind) {
        case (.plain, .row): return "row \(number)"
        case (.plain, .column): return "column \(number)"
        case (.plain, .box): return "box \(number)"
        case (.grid, .row): return "R\(number)"
        case (.grid, .column): return "C\(number)"
        case (.grid, .box): return "B\(number)"
        }
    }

    /// A box, 0...8.
    func box(_ index: Int) -> String { house(House(kind: .box, index: index)) }

    /// "a 5", "an 8".
    static func withArticle(_ digit: Int) -> String { "\(digit == 8 ? "an" : "a") \(digit)" }
}
