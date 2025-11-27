import Foundation

enum PuzzleRepositoryError: Error, LocalizedError {
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Unable to generate a Sudoku puzzle."
        }
    }
}

enum GenerationMode {
    case random
    case seeded(UInt64)
    case daily(Date)
}

final class SudokuPuzzleRepository {
    private let generator: SudokuGeneratorService
    private let validator: SudokuValidator
    private let persistence: PersistenceManager?
    private var telemetry: GeneratorTelemetry

    init(
        generator: SudokuGeneratorService = SudokuGeneratorService(),
        validator: SudokuValidator = SudokuValidator(),
        persistence: PersistenceManager? = nil
    ) {
        self.generator = generator
        self.validator = validator
        self.persistence = persistence
        if let persistence, let stored: GeneratorTelemetry = try? persistence.load(GeneratorTelemetry.self, from: File.telemetry.rawValue) {
            self.telemetry = stored
        } else {
            self.telemetry = GeneratorTelemetry()
        }
    }

    func randomPuzzle(for difficulty: Difficulty) throws -> SudokuPuzzle {
        let result = generate(for: difficulty, mode: .random)
        return result.puzzle
    }

    @discardableResult
    func generate(for difficulty: Difficulty, mode: GenerationMode) -> GeneratedPuzzleResult {
        let resolvedSeed: UInt64?
        switch mode {
        case .random:
            resolvedSeed = nil
        case let .seeded(value):
            resolvedSeed = value
        case let .daily(date):
            resolvedSeed = self.seed(for: date, difficulty: difficulty)
        }

        let result = generator.generatePuzzle(for: difficulty, seed: resolvedSeed)
        // Validate and log even if rating is negative to keep behavior deterministic.
        _ = validator.isValid(solution: result.puzzle.solutionGrid)
        recordTelemetry(for: difficulty, rating: result.rating)
        return result
    }

    func dailyPuzzle(for difficulty: Difficulty, date: Date = Date()) -> SudokuPuzzle {
        generate(for: difficulty, mode: .daily(date)).puzzle
    }

    func telemetryAverage(for difficulty: Difficulty) -> Double? {
        telemetry.average(for: difficulty)
    }

    // MARK: - Private helpers

    private func recordTelemetry(for difficulty: Difficulty, rating: Double) {
        guard let persistence else { return }
        var updated = telemetry
        updated.record(rating: rating, for: difficulty)
        telemetry = updated
        try? persistence.save(updated, to: File.telemetry.rawValue)
    }

    private func seed(for date: Date, difficulty: Difficulty) -> UInt64 {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var hasher = Hasher()
        hasher.combine(day.year)
        hasher.combine(day.month)
        hasher.combine(day.day)
        hasher.combine(difficulty.rawValue)
        let hashed = hasher.finalize()
        return UInt64(bitPattern: Int64(hashed))
    }
}

private enum File: String {
    case telemetry = "generator_telemetry.json"
}
