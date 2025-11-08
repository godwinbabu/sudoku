import XCTest
@testable import PureSudoku

final class GameStateTests: XCTestCase {
    func testCreates81Cells() {
        let state = TestData.newGameState()
        XCTAssertEqual(state.cells.count, 81)
        let givens = state.cells.filter { $0.given }.count
        XCTAssertGreaterThan(givens, 0)
        XCTAssertLessThan(givens, 81)
    }

    func testCodableRoundTrip() throws {
        let state = TestData.newGameState()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(state.cells.count, decoded.cells.count)
        XCTAssertEqual(state.puzzle.id, decoded.puzzle.id)
    }
}
