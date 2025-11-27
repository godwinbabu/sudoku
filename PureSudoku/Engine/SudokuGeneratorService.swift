import Foundation

enum PuzzleRatingBucket: String, Codable {
    case easy
    case medium
    case hard
    case veryHard
    case unsolvable
}

struct RatingThresholds {
    var easyMax: Double = 20
    var mediumMax: Double = 60
    var hardMax: Double = 120
    var veryHardMin: Double = 120
}

struct SudokuGeneratorConfiguration {
    var ratingSamples: Int = 4
    var maxAttempts: Int = 25
    var thresholds: RatingThresholds = .init()
    /// If true, allow buckets above hard when requesting `.hard` (useful for an optional expert mode).
    var allowVeryHard: Bool = false
}

struct GeneratedPuzzleResult {
    let puzzle: SudokuPuzzle
    let board: GeneratorBoard
    let solution: GeneratorBoard
    let rating: Double
    let bucket: PuzzleRatingBucket
    let attempts: Int
    let seed: UInt64?
}

/// Adapter around the vendored solver/generator with deterministic seeding, difficulty bucketing, and telemetry.
struct SudokuGeneratorService {
    private let config: SudokuGeneratorConfiguration

    init(config: SudokuGeneratorConfiguration = .init()) {
        self.config = config
    }

    func generatePuzzle(for difficulty: Difficulty, seed: UInt64? = nil) -> GeneratedPuzzleResult {
        var rng = seed.map { AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: $0)) } ?? AnyRandomNumberGenerator(SystemRandomNumberGenerator())
        var bestCandidate: (board: GeneratorBoard, solution: GeneratorBoard, rating: Double, bucket: PuzzleRatingBucket, attempts: Int, seed: UInt64?)?

        for attempt in 1...config.maxAttempts {
            var localRng = rng
            let board = makePuzzle(using: &localRng)

            var ratingRng = localRng
            let rating = ratePuzzle(board, samples: config.ratingSamples, using: &ratingRng)
            let bucket = bucket(for: rating)

            var solutionRng = localRng
            let solution = solvePuzzle(board, using: &solutionRng) ?? []

            let candidate = (board, solution, rating, bucket, attempt, seed)

            if matchesTarget(bucket: bucket, requested: difficulty) {
                rng = localRng
                return makeResult(from: candidate, difficulty: difficulty)
            }

            if let current = bestCandidate {
                let targetRange = targetRange(for: difficulty)
                let currentDistance = distance(from: current.rating, to: targetRange)
                let candidateDistance = distance(from: rating, to: targetRange)
                if candidateDistance < currentDistance {
                    bestCandidate = candidate
                }
            } else {
                bestCandidate = candidate
            }

            rng = localRng
        }

        guard let fallback = bestCandidate else {
            return makeResult(from: ([], [], -1, .unsolvable, config.maxAttempts, seed), difficulty: difficulty)
        }
        return makeResult(from: fallback, difficulty: difficulty)
    }

    func solve(board: GeneratorBoard) -> GeneratorBoard? {
        var rng = SystemRandomNumberGenerator()
        return solvePuzzle(board, using: &rng)
    }

    func solve(initialGrid: String) -> String? {
        guard initialGrid.count == 81 else { return nil }
        let board = GeneratorBoard(initialGrid.map { char -> Int? in
            guard let intVal = Int(String(char)), intVal > 0 else { return nil }
            return intVal - 1
        })
        guard let solved = solve(board: board) else { return nil }
        return stringify(board: solved, blanksAsZero: false)
    }

    func hint(for cells: [SudokuCell]) -> GeneratorHint? {
        let board = GeneratorBoard(cells.map { cell in
            guard let value = cell.value, value > 0 else { return nil }
            return value - 1
        })
        return nextHint(for: board)
    }

    // MARK: - Private helpers

    private func makeResult(from tuple: (board: GeneratorBoard, solution: GeneratorBoard, rating: Double, bucket: PuzzleRatingBucket, attempts: Int, seed: UInt64?), difficulty: Difficulty) -> GeneratedPuzzleResult {
        let initialGrid = stringify(board: tuple.board, blanksAsZero: true)
        let solutionGrid = stringify(board: tuple.solution, blanksAsZero: false)
        let puzzleID = tuple.seed.map { "seed-\(difficulty.rawValue)-\($0)" } ?? UUID().uuidString
        let puzzle = SudokuPuzzle(
            id: puzzleID,
            difficulty: difficulty,
            initialGrid: initialGrid,
            solutionGrid: solutionGrid,
            rating: tuple.rating,
            generatorSeed: tuple.seed,
            generatorBucket: tuple.bucket,
            generationAttempts: tuple.attempts,
            generatedAt: Date()
        )
        return GeneratedPuzzleResult(puzzle: puzzle, board: tuple.board, solution: tuple.solution, rating: tuple.rating, bucket: tuple.bucket, attempts: tuple.attempts, seed: tuple.seed)
    }

    private func bucket(for rating: Double) -> PuzzleRatingBucket {
        if rating < 0 { return .unsolvable }
        if rating < config.thresholds.easyMax { return .easy }
        if rating < config.thresholds.mediumMax { return .medium }
        if rating < config.thresholds.hardMax { return .hard }
        return .veryHard
    }

    private func matchesTarget(bucket: PuzzleRatingBucket, requested: Difficulty) -> Bool {
        switch requested {
        case .easy: return bucket == .easy
        case .medium: return bucket == .medium
        case .hard:
            if bucket == .hard { return true }
            if bucket == .veryHard { return config.allowVeryHard }
            return false
        }
    }

    private func targetRange(for difficulty: Difficulty) -> ClosedRange<Double> {
        switch difficulty {
        case .easy:
            return 0...config.thresholds.easyMax
        case .medium:
            return config.thresholds.easyMax...config.thresholds.mediumMax
        case .hard:
            return config.thresholds.mediumMax...max(config.thresholds.hardMax, config.thresholds.veryHardMin)
        }
    }

    private func distance(from rating: Double, to target: ClosedRange<Double>) -> Double {
        if target.contains(rating) { return 0 }
        if rating < target.lowerBound { return target.lowerBound - rating }
        return rating - target.upperBound
    }

    private func stringify(board: GeneratorBoard, blanksAsZero: Bool) -> String {
        board.map { value -> String in
            if let value {
                return String(value + 1)
            }
            return blanksAsZero ? "0" : "."
        }.joined()
    }
}

// Minimal type-erased RNG wrapper to allow seeding
private struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var _next: () -> UInt64

    init<T: RandomNumberGenerator>(_ base: T) {
        var mutableBase = base
        _next = { mutableBase.next() }
    }

    mutating func next() -> UInt64 {
        _next()
    }
}
