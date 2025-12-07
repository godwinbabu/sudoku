import XCTest
@testable import PureSudoku

final class SudokuHintEngineTests: XCTestCase {

    private func board(from string: String) -> GeneratorBoard {
        precondition(string.count == 81, "Board string must be 81 characters.")
        return string.map { char -> Int? in
            guard let value = Int(String(char)) else { return nil }
            return value - 1
        }
    }

    func testFindsNakedTriple() {
        // Row 1 has three empties whose allowed digits are exactly {1,2,3}, with overlap elsewhere.
        let rows = [
            "...456789",
            "4........",
            "567......",
            "6........",
            "7........",
            "8........",
            "9........",
            ".........",
            "........."
        ]
        let hint = nextHint(for: board(from: rows.joined()))
        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.technique, .nakedTriple)
        XCTAssertEqual(hint?.positions.count, 3)
    }

    func testFindsHiddenTriple() {
        // Digits 1,2,3 only fit in the first three cells of row 1, but those cells have extra candidates.
        let rows = [
            ".....6789",
            "678......",
            "9........",
            "...1.....",
            "...2.....",
            "...3.....",
            "....1....",
            "....2....",
            "....3...."
        ]
        let hint = nextHint(for: board(from: rows.joined()))
        XCTAssertNotNil(hint)
        XCTAssertTrue([HintTechnique.hiddenTripleRow, .hiddenTripleCol, .hiddenTripleBox].contains(hint?.technique ?? .invalid))
        XCTAssertEqual(hint?.positions.count, 3)
    }
}
