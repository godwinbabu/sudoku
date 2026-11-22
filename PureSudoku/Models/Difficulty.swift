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

    /// The hardest techniques a level's puzzles need (CODESPEC 1, 2.2), shown under its row on Home. Worded
    /// from what the generator's puzzles actually use: Expert is mostly Skyscraper, XY-Wing and X-Wing.
    var techniqueSummary: String {
        switch self {
        case .easy: return "Singles"
        case .medium: return "Pointing and claiming"
        case .hard: return "Naked and hidden pairs"
        case .expert: return "Skyscraper, XY-Wing, X-Wing"
        case .master: return "XY-Chain and beyond"
        }
    }

    /// What a puzzle of this level must look like (CODESPEC 2.2, issue #92).
    var targets: LevelTargets {
        switch self {
        case .easy: return LevelTargets(givens: 38...44, openingSingles: 15...81, minWalls: 0, minAdvancedWalls: 0)
        case .medium: return LevelTargets(givens: 30...34, openingSingles: 5...14, minWalls: 2, minAdvancedWalls: 0)
        case .hard: return LevelTargets(givens: 26...30, openingSingles: 3...7, minWalls: 2, minAdvancedWalls: 0)
        case .expert: return LevelTargets(givens: 24...27, openingSingles: 0...5, minWalls: 4, minAdvancedWalls: 1)
        case .master: return LevelTargets(givens: 22...26, openingSingles: 0...7, minWalls: 6, minAdvancedWalls: 2)
        }
    }

    /// 1...5, the lit bars of the tier glyph on Home.
    var rank: Int { Self.allCases.firstIndex(of: self)! + 1 }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.rank < rhs.rank }
}

/// Per-level targets (CODESPEC 2.2). The hardest technique still sets the level; these shape how
/// the puzzle plays inside it. Walls are solver steps at Intermediate tier or above: points where no
/// single exists anywhere.
struct LevelTargets: Equatable {
    let givens: ClosedRange<Int>
    /// Distinct cells any single fills on the starting board.
    let openingSingles: ClosedRange<Int>
    /// Steps at Intermediate tier or above.
    let minWalls: Int
    /// Steps at Advanced tier or above.
    let minAdvancedWalls: Int

    func isMet(by grade: PuzzleGrade, givens: Int) -> Bool {
        guard let opening = grade.openingSingles, let walls = grade.steps(atLeast: .intermediate),
              let advanced = grade.steps(atLeast: .advanced) else { return false }
        return self.givens.contains(givens) && openingSingles.contains(opening)
            && walls >= minWalls && advanced >= minAdvancedWalls
    }
}
