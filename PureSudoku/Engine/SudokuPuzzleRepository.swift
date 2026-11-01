import Foundation

enum GenerationMode {
    case random
    case seeded(UInt64)
}

/// Immutable after init, so it is safe to use from a background task.
final class SudokuPuzzleRepository: @unchecked Sendable {
    private let generator: SudokuGeneratorService
    private let validator: SudokuValidator
    private let maxValidationRetries = 3

    init(
        generator: SudokuGeneratorService = SudokuGeneratorService(),
        validator: SudokuValidator = SudokuValidator()
    ) {
        self.generator = generator
        self.validator = validator
    }

    /// Generates a puzzle and rejects any whose solution is not a valid grid.
    @discardableResult
    func generate(for difficulty: Difficulty, mode: GenerationMode) -> GeneratedPuzzleResult {
        var seed: UInt64?
        if case let .seeded(value) = mode { seed = value }

        var result = generator.generatePuzzle(for: difficulty, seed: seed)
        var retries = 0
        while !validator.isValid(solution: result.puzzle.solutionGrid), retries < maxValidationRetries {
            retries += 1
            seed = seed.map { $0 &+ 1 }
            result = generator.generatePuzzle(for: difficulty, seed: seed)
        }
        return result
    }
}
