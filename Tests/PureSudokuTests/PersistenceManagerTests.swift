import XCTest
@testable import PureSudoku

final class PersistenceManagerTests: XCTestCase {
    func testSaveAndLoadSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = PersistenceManager(directory: directory)
        var settings = Settings()
        settings.showTimer = false
        try manager.save(settings, to: "test_settings.json")
        let loaded = try manager.load(Settings.self, from: "test_settings.json")
        XCTAssertEqual(loaded?.showTimer, false)
        manager.delete("test_settings.json")
    }
}
