import Foundation

enum InputMode: String, Codable, CaseIterable {
    case normal
    case candidate

    mutating func toggle() {
        self = self == .normal ? .candidate : .normal
    }
}
