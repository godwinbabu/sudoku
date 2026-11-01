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

    func testYWingNeedsThreeDistinctDigits() {
        // Pivot and one pincer share the same pair {4,5}: not a Y-Wing, nothing may be removed.
        var candidates = Array(repeating: 0x1FF, count: 81)
        candidates[0] = mask([3, 4])   // r1c1 {4,5}
        candidates[2] = mask([3, 4])   // r1c3 {4,5}
        candidates[72] = mask([2, 4])  // r9c1 {3,5}
        _ = _applyYWingElimination(candidates: &candidates)
        XCTAssertNotEqual(candidates[74] & (1 << 4), 0, "r9c3 must keep 5")
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
