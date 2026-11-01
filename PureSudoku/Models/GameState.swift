import Foundation

struct GameState: Codable, Equatable {
    var puzzle: SudokuPuzzle
    var cells: [SudokuCell]
    var elapsedSeconds: Int
    var isCompleted: Bool
    var usedReveal: Bool
    var lastUpdated: Date
    var hasContradiction: Bool
    /// True once a hint's result (rung 4) was shown; the solve then skips best time (CODESPEC 6.3.1).
    var usedHint: Bool = false
    /// One entry per hint session (CODESPEC 2.3).
    var hintLog: [HintLogEntry] = []

    init(puzzle: SudokuPuzzle, cells: [SudokuCell], elapsedSeconds: Int = 0, isCompleted: Bool = false, usedReveal: Bool = false, lastUpdated: Date = Date(), hasContradiction: Bool = false) {
        self.puzzle = puzzle
        self.cells = cells
        self.elapsedSeconds = elapsedSeconds
        self.isCompleted = isCompleted
        self.usedReveal = usedReveal
        self.lastUpdated = lastUpdated
        self.hasContradiction = hasContradiction
    }

    static func newGame(for puzzle: SudokuPuzzle, now: Date = Date()) -> GameState {
        var cells: [SudokuCell] = []
        cells.reserveCapacity(81)
        let initialChars = Array(puzzle.initialGrid)
        for index in 0..<81 {
            let row = index / 9
            let col = index % 9
            let char = initialChars[index]
            let digit = Int(String(char))
            let isGiven = digit != nil && digit != 0
            let cell = SudokuCell(row: row, col: col, given: isGiven, value: isGiven ? digit : nil)
            cells.append(cell)
        }
        return GameState(puzzle: puzzle, cells: cells, elapsedSeconds: 0, isCompleted: false, usedReveal: false, lastUpdated: now, hasContradiction: false)
    }

    mutating func resetToInitial(now: Date = Date()) {
        self = GameState.newGame(for: puzzle, now: now)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case puzzle, cells, elapsedSeconds, isCompleted, usedReveal, lastUpdated, hasContradiction, usedHint, hintLog
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try container.decode(SudokuPuzzle.self, forKey: .puzzle)
        cells = try container.decode([SudokuCell].self, forKey: .cells)
        elapsedSeconds = try container.decode(Int.self, forKey: .elapsedSeconds)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        usedReveal = try container.decode(Bool.self, forKey: .usedReveal)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        hasContradiction = try container.decodeIfPresent(Bool.self, forKey: .hasContradiction) ?? false
        usedHint = try container.decodeIfPresent(Bool.self, forKey: .usedHint) ?? false
        hintLog = try container.decodeIfPresent([HintLogEntry].self, forKey: .hintLog) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(puzzle, forKey: .puzzle)
        try container.encode(cells, forKey: .cells)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(usedReveal, forKey: .usedReveal)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(hasContradiction, forKey: .hasContradiction)
        try container.encode(usedHint, forKey: .usedHint)
        try container.encode(hintLog, forKey: .hintLog)
    }
}

/// What happened in one hint session.
struct HintLogEntry: Codable, Equatable {
    /// `Technique.rawValue`, or "mistake" / "noStep".
    let technique: String
    /// Deepest rung shown (0-4).
    let deepestRung: Int
    let applied: Bool
}
