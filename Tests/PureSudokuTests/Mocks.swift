import Foundation
@testable import PureSudoku

struct MockTimeProvider: TimeProvider {
    var date: Date = Date()
    func now() -> Date { date }
}
