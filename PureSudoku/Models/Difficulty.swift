import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// The techniques a level needs (CODESPEC 1, 2.2), shown under its button.
    var techniqueSummary: String {
        switch self {
        case .easy: return "Singles"
        case .medium: return "Singles, then pointing, pairs, triples"
        case .hard: return "Medium, then X-Wing, wings, more"
        }
    }
}
