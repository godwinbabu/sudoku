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

    func testUndecodableFileIsMovedAsideNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = PersistenceManager(directory: dir)
        try manager.save(Settings(), to: "probe.json")
        let url = dir.appendingPathComponent("stats.json")
        try Data("{\"broken\": true}".utf8).write(to: url)

        XCTAssertThrowsError(try manager.load(Stats.self, from: "stats.json"))
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let backup = try XCTUnwrap(files.first { $0.hasPrefix("stats.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(backup)), Data("{\"broken\": true}".utf8))

        try manager.save(Stats(), to: "stats.json")
        XCTAssertEqual(try manager.load(Stats.self, from: "stats.json"), Stats())
    }

    func testUnreadableFileIsNeverOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = PersistenceManager(directory: dir)
        try manager.save(Settings(), to: "probe.json")
        // A folder where the file should be makes the read fail.
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("stats.json"), withIntermediateDirectories: true)
        XCTAssertThrowsError(try manager.load(Stats.self, from: "stats.json"))
        XCTAssertThrowsError(try manager.save(Stats(), to: "stats.json"))
    }
}
