import Foundation

struct GameState: Codable, Equatable {
    var puzzle: SudokuPuzzle
    var cells: [SudokuCell]
    var elapsedSeconds: Int
    var isCompleted: Bool
    var usedReveal: Bool
    var lastUpdated: Date
    var hasContradiction: Bool
    /// True once a hint placed a digit or removed candidates. The solve keeps the streak but sets no
    /// best time (CODESPEC 6.3.1). Hint steps 1-3 and clearing a mistake are free.
    var assisted: Bool = false
    /// True once this puzzle's completion reached the stats. Restart keeps it, so solving the same
    /// puzzle again never counts twice (CODESPEC 6.5).
    var counted: Bool = false
    /// The solve time of an import solved before its solution count finished: its best and typical
    /// time wait for the count (CODESPEC 3.3). Saved, so a relaunch or a replay in between keeps it.
    var timeAwaitingCount: Int?
    /// Cells that Check Cell / Check Puzzle found wrong. Saved so the marks keep their source:
    /// a Check mark stays until the cell is edited, a duplicate mark clears when fixed (CODESPEC 7.1).
    var checkedWrong: Set<UUID> = []
    /// One entry per hint session (CODESPEC 2.3).
    var hintLog: [HintLogEntry] = []
    /// Hints opened in this puzzle (the Solved summary).
    var hints: Int { hintLog.count }

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

    /// Back to the givens. `counted` survives, so a restarted solve doesn't count again.
    mutating func resetToInitial(now: Date = Date()) {
        let counted = counted
        self = GameState.newGame(for: puzzle, now: now)
        self.counted = counted
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case puzzle, cells, elapsedSeconds, isCompleted, usedReveal, lastUpdated, hasContradiction, assisted, hintLog, counted, timeAwaitingCount, checkedWrong
        case usedHint // read only: the old name of `assisted`
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
        assisted = try container.decodeIfPresent(Bool.self, forKey: .assisted)
            ?? container.decodeIfPresent(Bool.self, forKey: .usedHint) ?? false
        hintLog = try container.decodeIfPresent([HintLogEntry].self, forKey: .hintLog) ?? []
        // Saves from before this field: a completed game reached the stats unless it was revealed.
        counted = try container.decodeIfPresent(Bool.self, forKey: .counted) ?? (isCompleted && !usedReveal)
        timeAwaitingCount = try container.decodeIfPresent(Int.self, forKey: .timeAwaitingCount)
        checkedWrong = try container.decodeIfPresent(Set<UUID>.self, forKey: .checkedWrong) ?? []
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
        try container.encode(assisted, forKey: .assisted)
        try container.encode(hintLog, forKey: .hintLog)
        try container.encode(counted, forKey: .counted)
        try container.encodeIfPresent(timeAwaitingCount, forKey: .timeAwaitingCount)
        try container.encode(checkedWrong, forKey: .checkedWrong)
    }
}

/// What happened in one hint session.
struct HintLogEntry: Codable, Equatable {
    /// `Technique.rawValue`, or "mistake" / "noStep".
    let technique: String
    /// Deepest hint step shown (1-3; saves from before the three-step card hold 0-4).
    let deepestRung: Int
    let applied: Bool
}
