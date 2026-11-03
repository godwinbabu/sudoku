import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable, Comparable {
    case easy
    case medium
    case hard
    case expert
    // swiftlint:disable:next inclusive_language
    case master

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        case .master: return "Master"
        }
    }

    /// The hardest technique a level needs (CODESPEC 1, 2.2), shown under its row on Home.
    var techniqueSummary: String {
        switch self {
        case .easy: return "Singles only"
        case .medium: return "Pointing & claiming"
        case .hard: return "Pairs & triples"
        case .expert: return "Wings & fish"
        case .master: return "Chains & beyond"
        }
    }

    /// 1...5, the lit bars of the tier glyph on Home.
    var rank: Int { Self.allCases.firstIndex(of: self)! + 1 }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rank < rhs.rank }
}
