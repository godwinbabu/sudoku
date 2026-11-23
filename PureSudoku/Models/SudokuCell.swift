import Foundation

struct SudokuCell: Identifiable, Codable, Equatable {
    let id: UUID
    var row: Int
    var col: Int
    var given: Bool
    var value: Int?
    var candidates: Set<Int> {
        // Generated notes are always a subset: a note the player removes, or one any edit takes away,
        // stops being "generated", so adding it back by hand makes it the player's own.
        didSet { generatedCandidates.formIntersection(candidates) }
    }
    /// The notes Fill all notes added (not the player's own); "Clear generated notes" removes just these.
    var generatedCandidates: Set<Int> = []
    var isError: Bool
    var isRevealed: Bool
    var isVerifiedCorrect: Bool

    init(id: UUID = UUID(), row: Int, col: Int, given: Bool, value: Int?, candidates: Set<Int> = [], isError: Bool = false, isRevealed: Bool = false) {
        self.id = id
        self.row = row
        self.col = col
        self.given = given
        self.value = value
        self.candidates = candidates
        self.isError = isError
        self.isRevealed = isRevealed
        self.isVerifiedCorrect = false
    }

    var index: Int {
        row * 9 + col
    }

    private enum CodingKeys: String, CodingKey {
        case id, row, col, given, value, candidates, generatedCandidates, isError, isRevealed, isVerifiedCorrect
    }

    /// Saves from before generated notes existed treat every note as the player's own.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        row = try c.decode(Int.self, forKey: .row)
        col = try c.decode(Int.self, forKey: .col)
        given = try c.decode(Bool.self, forKey: .given)
        value = try c.decodeIfPresent(Int.self, forKey: .value)
        candidates = try c.decode(Set<Int>.self, forKey: .candidates)
        generatedCandidates = try c.decodeIfPresent(Set<Int>.self, forKey: .generatedCandidates) ?? []
        isError = try c.decode(Bool.self, forKey: .isError)
        isRevealed = try c.decode(Bool.self, forKey: .isRevealed)
        isVerifiedCorrect = try c.decode(Bool.self, forKey: .isVerifiedCorrect)
    }
}
