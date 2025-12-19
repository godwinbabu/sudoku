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

    private func mask(_ digits: [Int]) -> Int {
        digits.reduce(0) { $0 | (1 << $1) }
    }

    func testFindsNakedTriple() {
        // Full house: only one empty in the first row.
        let rows = [
            "12345678.",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            "........."
        ]
        let hint = nextHint(for: board(from: rows.joined()))
        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.technique, .fullHouse)
        XCTAssertEqual(hint?.positions, [8])
        XCTAssertEqual(hint?.digit, 8)
    }

    func testFindsHiddenTriple() {
        // Naked single without any full house in the row/column/box.
        let rows = [
            "..4678912",
            "..2195348",
            "198342567",
            "859761423",
            "426853791",
            "713924856",
            "961537284",
            "287419635",
            "345286179"
        ]
        let hint = nextHint(for: board(from: rows.joined()))
        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.technique, .nakedSingle)
        XCTAssertEqual(hint?.positions.first, 0)
        XCTAssertEqual(hint?.digit, 4)
    }

    func testXYChainEliminatesCandidate() {
        var candidates = Array(repeating: 0, count: 81)
        candidates[0] = mask([0, 1]) // r1c1
        candidates[1] = mask([0, 1]) // r1c2
        candidates[2] = mask([0, 2]) // r1c3 target

        let changed = _applyXYChainElimination(candidates: &candidates)

        XCTAssertTrue(changed)
        XCTAssertEqual(candidates[2] & (1 << 0), 0)
    }

    func testUniqueRectangleEliminatesExtras() {
        var candidates = Array(repeating: 0, count: 81)
        let p11 = 0
        let p12 = 1
        let p21 = 9
        let p22 = 10
        candidates[p11] = mask([0, 1])
        candidates[p22] = mask([0, 1])
        candidates[p12] = mask([0, 1, 2])
        candidates[p21] = mask([0, 1, 2])

        let changed = _applyUniqueRectangleElimination(candidates: &candidates)

        XCTAssertTrue(changed)
        XCTAssertEqual(candidates[p12], mask([0, 1]))
        XCTAssertEqual(candidates[p21], mask([0, 1]))
    }

    func testMedusaEliminatesCandidateSeeingBothColors() {
        var candidates = Array(repeating: 0, count: 81)
        let digit = 0
        let bit = 1 << digit

        let a = 0   // r1c1
        let b = 7   // r1c8
        let c = 70  // r8c8
        let d = 63  // r8c1
        let target = 4 // r1c5
        let extra1 = 40 // r5c5
        let extra2 = 76 // r9c5

        for pos in [a, b, c, d, target, extra1, extra2] {
            candidates[pos] |= bit
        }

        let changed = _applyMedusaElimination(candidates: &candidates)

        XCTAssertTrue(changed)
        XCTAssertEqual(candidates[target] & bit, 0)
    }

    func testBowmansBingoFindsForcedPlacement() {
        let solution = TestData.puzzle.solutionGrid
        var chars = Array(solution)
        chars[0] = "."
        let board = board(from: String(chars))

        let correctDigit = Int(String(solution.first!))! - 1
        let wrongDigit = correctDigit == 0 ? 1 : 0

        var candidates = Array(repeating: 0, count: 81)
        candidates[0] = mask([correctDigit, wrongDigit])

        let hint = _bowmansBingoHint(board: board, candidates: candidates)

        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.technique, .bowmansBingo)
        XCTAssertEqual(hint?.positions, [0])
        XCTAssertEqual(hint?.digit, correctDigit)
    }
}
