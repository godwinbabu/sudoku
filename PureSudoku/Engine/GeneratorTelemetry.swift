import Foundation

struct GeneratorTelemetry: Codable, Equatable {
    private(set) var ratings: [Difficulty: [Double]] = [:]
    private let maxSamplesPerDifficulty = 50

    mutating func record(rating: Double, for difficulty: Difficulty) {
        guard rating >= 0 else { return }
        var bucket = ratings[difficulty, default: []]
        bucket.append(rating)
        if bucket.count > maxSamplesPerDifficulty {
            bucket.removeFirst(bucket.count - maxSamplesPerDifficulty)
        }
        ratings[difficulty] = bucket
    }

    func average(for difficulty: Difficulty) -> Double? {
        guard let values = ratings[difficulty], !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }
}
