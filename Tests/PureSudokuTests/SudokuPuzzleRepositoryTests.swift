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

    private func board(from string: String) -> GeneratorBoard {
        GeneratorBoard(string.map { char -> Int? in
            guard let intVal = Int(String(char)), intVal > 0 else { return nil }
            return intVal - 1
        })
    }
}
