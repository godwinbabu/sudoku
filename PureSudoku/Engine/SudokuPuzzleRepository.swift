import Foundation

enum PuzzleRepositoryError: Error, LocalizedError {
    case missingResource(String)
    case decodeFailure
    case invalidSolution(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            return "Missing puzzle resource: \(name)"
        case .decodeFailure:
            return "Unable to decode puzzle file"
        case let .invalidSolution(id):
            return "Puzzle \(id) has invalid solution grid"
        }
    }
}

final class SudokuPuzzleRepository {
    private let bundle: Bundle
    private let validator: SudokuValidator
    private var cache: [Difficulty: [SudokuPuzzle]] = [:]
    private let decoder = JSONDecoder()

    init(bundle: Bundle = .main, validator: SudokuValidator = SudokuValidator()) {
        self.bundle = bundle
        self.validator = validator
    }

    func randomPuzzle(for difficulty: Difficulty) throws -> SudokuPuzzle {
        let puzzles = try loadPuzzles(for: difficulty)
        guard let puzzle = puzzles.randomElement() else {
            throw PuzzleRepositoryError.missingResource(difficulty.rawValue)
        }
        return puzzle
    }

    func loadPuzzles(for difficulty: Difficulty) throws -> [SudokuPuzzle] {
        if let cached = cache[difficulty] {
            return cached
        }

        guard let url = bundle.url(forResource: difficulty.rawValue, withExtension: "json", subdirectory: "Puzzles") else {
            throw PuzzleRepositoryError.missingResource("Puzzles/\(difficulty.rawValue).json")
        }

        let data = try Data(contentsOf: url)
        struct StoredPuzzle: Decodable {
            let id: String
            let initialGrid: String
            let solutionGrid: String
        }
        let stored = try decoder.decode([StoredPuzzle].self, from: data)
        let puzzles = try stored.map { item -> SudokuPuzzle in
            guard item.initialGrid.count == 81, item.solutionGrid.count == 81 else {
                throw PuzzleRepositoryError.decodeFailure
            }
            guard validator.isValid(solution: item.solutionGrid) else {
                throw PuzzleRepositoryError.invalidSolution(item.id)
            }
            return SudokuPuzzle(id: item.id, difficulty: difficulty, initialGrid: item.initialGrid, solutionGrid: item.solutionGrid)
        }
        cache[difficulty] = puzzles
        return puzzles
    }
}
