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

    init(
        id: String,
        difficulty: Difficulty,
        initialGrid: String,
        solutionGrid: String,
        rating: Double? = nil,
        generatorSeed: UInt64? = nil,
        generatorBucket: PuzzleRatingBucket? = nil,
        generationAttempts: Int? = nil,
        generatedAt: Date? = nil
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
    }
}
