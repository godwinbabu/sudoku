import Foundation

struct SudokuPuzzle: Codable, Equatable, Identifiable {
    let id: String
    let difficulty: Difficulty
    let initialGrid: String
    let solutionGrid: String
    /// Logical grade (CODESPEC 2.2). Nil for puzzles saved before grading, or imports the solver can't finish.
    let grade: PuzzleGrade?
    let generatorSeed: UInt64?
    let generationAttempts: Int?
    let generatedAt: Date?
    let source: GameSource
    let importedAt: Date?
    let importImageID: String?
    /// Exactly one solution? Nil until counted (CODESPEC 2.1); see `isUnique`.
    var hasUniqueSolution: Bool?

    init(
        id: String,
        difficulty: Difficulty,
        initialGrid: String,
        solutionGrid: String,
        grade: PuzzleGrade? = nil,
        generatorSeed: UInt64? = nil,
        generationAttempts: Int? = nil,
        generatedAt: Date? = nil,
        source: GameSource = .generated,
        importedAt: Date? = nil,
        importImageID: String? = nil,
        hasUniqueSolution: Bool? = nil
    ) {
        self.id = id
        self.difficulty = difficulty
        self.initialGrid = initialGrid
        self.solutionGrid = solutionGrid
        self.grade = grade
        self.generatorSeed = generatorSeed
        self.generationAttempts = generationAttempts
        self.generatedAt = generatedAt
        self.source = source
        self.importedAt = importedAt
        self.importImageID = importImageID
        self.hasUniqueSolution = hasUniqueSolution
    }

    /// Uniqueness techniques may run only when this is true. Generated puzzles are unique; an
    /// import counts as unique only once its solutions were counted (CODESPEC 2.1).
    var isUnique: Bool { hasUniqueSolution ?? (source == .generated) }

    /// Same puzzle with a different answer (used when an imported puzzle has several solutions).
    func withSolution(_ grid: String) -> SudokuPuzzle {
        SudokuPuzzle(
            id: id, difficulty: difficulty, initialGrid: initialGrid, solutionGrid: grid,
            grade: grade, generatorSeed: generatorSeed,
            generationAttempts: generationAttempts, generatedAt: generatedAt,
            source: source, importedAt: importedAt, importImageID: importImageID,
            hasUniqueSolution: hasUniqueSolution
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case difficulty
        case initialGrid
        case solutionGrid
        case grade
        case generatorSeed
        case generationAttempts
        case generatedAt
        case source
        case importedAt
        case importImageID
        case hasUniqueSolution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        initialGrid = try container.decode(String.self, forKey: .initialGrid)
        solutionGrid = try container.decode(String.self, forKey: .solutionGrid)
        grade = try container.decodeIfPresent(PuzzleGrade.self, forKey: .grade)
        generatorSeed = try container.decodeIfPresent(UInt64.self, forKey: .generatorSeed)
        generationAttempts = try container.decodeIfPresent(Int.self, forKey: .generationAttempts)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        source = try container.decodeIfPresent(GameSource.self, forKey: .source) ?? .generated
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt)
        importImageID = try container.decodeIfPresent(String.self, forKey: .importImageID)
        hasUniqueSolution = try container.decodeIfPresent(Bool.self, forKey: .hasUniqueSolution)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(initialGrid, forKey: .initialGrid)
        try container.encode(solutionGrid, forKey: .solutionGrid)
        try container.encodeIfPresent(grade, forKey: .grade)
        try container.encodeIfPresent(generatorSeed, forKey: .generatorSeed)
        try container.encodeIfPresent(generationAttempts, forKey: .generationAttempts)
        try container.encodeIfPresent(generatedAt, forKey: .generatedAt)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(importedAt, forKey: .importedAt)
        try container.encodeIfPresent(importImageID, forKey: .importImageID)
        try container.encodeIfPresent(hasUniqueSolution, forKey: .hasUniqueSolution)
    }
}
