import Foundation
@testable import PureSudoku

struct MockTimeProvider: TimeProvider {
    var date: Date = Date()
    func now() -> Date { date }
}

/// A clock the test can move forward.
final class AdvancingTimeProvider: TimeProvider {
    var date: Date
    init(date: Date = Date(timeIntervalSince1970: 1_000_000)) { self.date = date }
    func now() -> Date { date }
    func advance(_ seconds: TimeInterval) { date += seconds }
}

@MainActor
func makeTestController(timeProvider: TimeProvider = MockTimeProvider()) -> (AppController, URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let controller = AppController(
        persistence: PersistenceManager(directory: dir),
        timeProvider: timeProvider,
        imageStore: ImportedImageStore(directory: dir.appendingPathComponent("ImportedImages", isDirectory: true))
    )
    return (controller, dir)
}
