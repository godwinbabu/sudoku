import XCTest
@testable import PureSudoku

final class ImportedGamePersistenceTests: XCTestCase {
    func testImportedGamesRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = PersistenceManager(directory: directory)
        let state = TestData.newGameState()
        let imported = ImportedGame(gameState: state)
        try manager.save([imported], to: "imported_games.json")
        let loaded = try manager.load([ImportedGame].self, from: "imported_games.json")
        XCTAssertEqual(loaded?.count, 1)
        XCTAssertEqual(loaded?.first?.id, imported.id)
    }
}
