import Foundation

struct SudokuGeneratorConfiguration {
    /// Generated puzzles tried before falling back to a bundled one. About 12 ms each on a Mac;
    /// Hard (3-6% of generated puzzles) succeeds within 30 tries about 80% of the time.
    var maxAttempts: Int = 30
}

struct GeneratedPuzzleResult {
    let puzzle: SudokuPuzzle
    let grade: PuzzleGrade
    let attempts: Int
    /// True when no generated puzzle fit in time and a pre-graded bundled one was used.
    let isBundled: Bool
}

/// Generates puzzles graded by the techniques a person needs (CODESPEC 2.2), then adds givens up
/// to the level's target. A puzzle is only offered at the level its grade maps to; there is no
/// silent fallback to another level.
struct SudokuGeneratorService {
    private let config: SudokuGeneratorConfiguration

    init(config: SudokuGeneratorConfiguration = .init()) {
        self.config = config
    }

    func generatePuzzle(for difficulty: Difficulty, seed: UInt64? = nil) -> GeneratedPuzzleResult {
        var rng = seed.map { AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: $0)) } ?? AnyRandomNumberGenerator(SystemRandomNumberGenerator())
        let id = seed.map { "seed-\(difficulty.rawValue)-\($0)" } ?? UUID().uuidString
        for attempt in stride(from: 1, through: config.maxAttempts, by: 1) {
            let minimal = makePuzzle(using: &rng).map { ($0 ?? -1) + 1 }
            guard let (first, solution) = PuzzleGrader.grade(minimal), first.difficulty == difficulty,
                  let (values, grade) = PuzzleGrader.addingGivens(to: minimal, solution: solution, level: difficulty, using: &rng)
            else { continue }
            let puzzle = SudokuPuzzle(
                id: id, difficulty: difficulty,
                initialGrid: values.map(String.init).joined(), solutionGrid: solution.map(String.init).joined(),
                grade: grade, generatorSeed: seed, generationAttempts: attempt, generatedAt: Date(), hasUniqueSolution: true
            )
            return GeneratedPuzzleResult(puzzle: puzzle, grade: grade, attempts: attempt, isBundled: false)
        }
        let options = BundledPuzzles.puzzles(for: difficulty)
        let entry = options[Int(rng.next() % UInt64(options.count))]
        let grade = PuzzleGrade(hardestTier: entry.techniques.map(\.tier).max() ?? .basic, score: entry.score, techniques: entry.techniques)
        let puzzle = SudokuPuzzle(
            id: id, difficulty: difficulty, initialGrid: entry.initialGrid, solutionGrid: entry.solutionGrid,
            grade: grade, generatorSeed: seed, generationAttempts: config.maxAttempts, generatedAt: Date(), hasUniqueSolution: true
        )
        return GeneratedPuzzleResult(puzzle: puzzle, grade: grade, attempts: config.maxAttempts, isBundled: true)
    }

    func solve(board: GeneratorBoard) -> GeneratorBoard? {
        var rng = SystemRandomNumberGenerator()
        return solvePuzzle(board, using: &rng)
    }

    func solve(initialGrid: String) -> String? {
        guard initialGrid.count == 81 else { return nil }
        let board = Board.from(grid: initialGrid)
        guard !Board.hasContradiction(board), let solved = solve(board: board) else { return nil }
        return stringify(board: solved, blanksAsZero: false)
    }

    // MARK: - Private helpers

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
