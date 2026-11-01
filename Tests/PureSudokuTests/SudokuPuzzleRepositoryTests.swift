import XCTest
@testable import PureSudoku

final class SudokuPuzzleRepositoryTests: XCTestCase {
    func testGeneratesSolvablePuzzleForAllDifficulties() {
        let repository = SudokuPuzzleRepository(generator: SudokuGeneratorService(), validator: SudokuValidator())
        for difficulty in Difficulty.allCases {
            let result = repository.generate(for: difficulty, mode: .random)
            XCTAssertEqual(result.puzzle.initialGrid.count, 81)
            XCTAssertEqual(result.puzzle.solutionGrid.count, 81)
            XCTAssertNotNil(solvePuzzle(board(from: result.puzzle.initialGrid)))
            XCTAssertNotNil(solvePuzzle(board(from: result.puzzle.solutionGrid)))
        }
    }

    func testSeededGenerationIsDeterministic() {
        let repository = SudokuPuzzleRepository(generator: SudokuGeneratorService())
        let seed: UInt64 = 42
        let first = repository.generate(for: .easy, mode: .seeded(seed)).puzzle
        let second = repository.generate(for: .easy, mode: .seeded(seed)).puzzle
        XCTAssertEqual(first.initialGrid, second.initialGrid)
        XCTAssertEqual(first.solutionGrid, second.solutionGrid)
    }

    /// Fixed seeds make this reproducible. Each level must land in its own rating band, and the
    /// average rating must rise from Easy to Hard (audit #3: levels used to be nearly the same).
    func testDifficultyLevelsAreSeparated() {
        let service = SudokuGeneratorService()
        var means: [Difficulty: Double] = [:]
        for difficulty in Difficulty.allCases {
            var total = 0.0
            for seed in UInt64(1)...UInt64(6) {
                let result = service.generatePuzzle(for: difficulty, seed: seed)
                XCTAssertEqual(service.difficulty(for: result.rating), difficulty, "seed \(seed) rating \(result.rating)")
                total += result.rating
            }
            means[difficulty] = total / 6
        }
        XCTAssertLessThan(means[.easy]!, means[.medium]!)
        XCTAssertLessThan(means[.medium]!, means[.hard]!)
    }

    private func board(from string: String) -> GeneratorBoard {
        GeneratorBoard(string.map { char -> Int? in
            guard let intVal = Int(String(char)), intVal > 0 else { return nil }
            return intVal - 1
        })
    }
}
