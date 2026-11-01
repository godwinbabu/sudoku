import Foundation

struct SudokuPuzzle: Codable, Equatable, Identifiable {
    let id: String
    let difficulty: Difficulty
    let initialGrid: String
    let solutionGrid: String
    let rating: Double?
    let generatorSeed: UInt64?
    let generatorBucket: PuzzleRatingBucket?
    let generationAttempts: Int?
    let generatedAt: Date?
    let source: GameSource
    let importedAt: Date?
    let importImageID: String?

    init(
        id: String,
        difficulty: Difficulty,
        initialGrid: String,
        solutionGrid: String,
        rating: Double? = nil,
        generatorSeed: UInt64? = nil,
        generatorBucket: PuzzleRatingBucket? = nil,
        generationAttempts: Int? = nil,
        generatedAt: Date? = nil,
        source: GameSource = .generated,
        importedAt: Date? = nil,
        importImageID: String? = nil
    ) {
        self.id = id
        self.difficulty = difficulty
        self.initialGrid = initialGrid
        self.solutionGrid = solutionGrid
        self.rating = rating
        self.generatorSeed = generatorSeed
        self.generatorBucket = generatorBucket
        self.generationAttempts = generationAttempts
        self.generatedAt = generatedAt
        self.source = source
        self.importedAt = importedAt
        self.importImageID = importImageID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case difficulty
        case initialGrid
        case solutionGrid
        case rating
        case generatorSeed
        case generatorBucket
        case generationAttempts
        case generatedAt
        case source
        case importedAt
        case importImageID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        initialGrid = try container.decode(String.self, forKey: .initialGrid)
        solutionGrid = try container.decode(String.self, forKey: .solutionGrid)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        generatorSeed = try container.decodeIfPresent(UInt64.self, forKey: .generatorSeed)
        generatorBucket = try container.decodeIfPresent(PuzzleRatingBucket.self, forKey: .generatorBucket)
        generationAttempts = try container.decodeIfPresent(Int.self, forKey: .generationAttempts)
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        source = try container.decodeIfPresent(GameSource.self, forKey: .source) ?? .generated
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt)
        importImageID = try container.decodeIfPresent(String.self, forKey: .importImageID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(initialGrid, forKey: .initialGrid)
        try container.encode(solutionGrid, forKey: .solutionGrid)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(generatorSeed, forKey: .generatorSeed)
        try container.encodeIfPresent(generatorBucket, forKey: .generatorBucket)
        try container.encodeIfPresent(generationAttempts, forKey: .generationAttempts)
        try container.encodeIfPresent(generatedAt, forKey: .generatedAt)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(importedAt, forKey: .importedAt)
        try container.encodeIfPresent(importImageID, forKey: .importImageID)
    }
}
