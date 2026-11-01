import Foundation

/// One open hint (CODESPEC 6.3.1). The board never changes while a session is open, except through
/// Apply. `rung` is the ladder step: 0 = mistake check (with narrowing), 1 = name, 2 = where,
/// 3 = why, 4 = result.
struct HintSession: Equatable {
    enum MistakeKind: Equatable {
        /// A placed digit is wrong.
        case wrongDigit
        /// A cell's notes leave out its correct digit.
        case missingNote
        /// Imported puzzle: the entries fit no solution, and no single cell can be blamed.
        case entriesConflict
    }

    enum Content: Equatable {
        case mistake(cell: Int?, kind: MistakeKind)
        /// `board` is the solver's view of the board when the hint opened (shows candidates).
        case step(TechniqueStep, board: SolverBoard)
        /// No known technique applies. `cell` is the cell Reveal would fill.
        case noStep(cell: Int?)
    }

    let content: Content
    /// Mistake: narrowing level 0-2. Step: rung 1-4.
    private(set) var rung: Int
    /// Waiting for "Try it yourself first?" before rung 4.
    private(set) var isAskingBeforeResult = false
    /// Rung 4 toggle: show the board as it will be after Apply.
    var showsAfter = false
    private(set) var deepestRung: Int

    init(content: Content) {
        self.content = content
        switch content {
        case .mistake, .noStep: rung = 0
        case .step: rung = 1
        }
        deepestRung = rung
    }

    var step: TechniqueStep? {
        if case let .step(step, _) = content { return step }
        return nil
    }

    var canGoBack: Bool {
        if isAskingBeforeResult { return true }
        switch content {
        case .mistake: return rung > 0
        case .step: return rung > 1
        case .noStep: return false
        }
    }

    var canGoNext: Bool {
        guard !isAskingBeforeResult else { return false }
        switch content {
        case .mistake(let cell, _): return cell != nil && rung < 2
        case .step: return rung < 4
        case .noStep: return false
        }
    }

    var canApply: Bool { step != nil && rung == 4 }

    /// Moves one rung on. Returns true if the result (rung 4) was just shown.
    mutating func next(askFirst: Bool) -> Bool {
        guard canGoNext else { return false }
        if step != nil, rung == 3, askFirst {
            isAskingBeforeResult = true
            return false
        }
        rung += 1
        deepestRung = max(deepestRung, rung)
        return step != nil && rung == 4
    }

    /// Answers "Show result" to "Try it yourself first?". Returns true (rung 4 is now shown).
    mutating func showResult() -> Bool {
        guard isAskingBeforeResult else { return false }
        isAskingBeforeResult = false
        rung = 4
        deepestRung = 4
        return true
    }

    mutating func back() {
        if isAskingBeforeResult {
            isAskingBeforeResult = false
            return
        }
        guard canGoBack else { return }
        rung -= 1
        showsAfter = false
    }

    // MARK: - Text

    var title: String {
        switch content {
        case .mistake: return "Check your board"
        case .step(let step, _): return step.technique.displayName
        case .noStep: return "No step found"
        }
    }

    /// Tier badge text, for technique hints.
    var badge: String? { step?.technique.tierName }

    func text(_ names: CellNameStyle) -> String {
        if isAskingBeforeResult { return "Try it yourself first? The highlighted cells hold the answer." }
        switch content {
        case let .mistake(cell, kind):
            return mistakeText(cell: cell, kind: kind, names: names)
        case let .step(step, _):
            switch rung {
            case 1: return "A \(step.technique.displayName) is available. \(step.technique.definition)"
            case 2: return step.whereText(names)
            case 3: return step.reason(names)
            default: return step.resultText(names)
            }
        case .noStep:
            return "I can't find a step I can explain. Reveal this cell?"
        }
    }

    private func mistakeText(cell: Int?, kind: MistakeKind, names: CellNameStyle) -> String {
        guard let cell else { return "Some of your entries don't fit together. Try undoing recent moves." }
        switch rung {
        case 0: return "There's a mistake on the board. Fix it before the next hint."
        case 1: return "Look at \(House(kind: .box, index: SolverBoard.box(of: cell)).name)."
        default:
            let name = SolverBoard.name(of: cell, names)
            return kind == .wrongDigit ? "\(name.capitalizedFirst) is wrong." : "The notes in \(name) leave out its digit."
        }
    }

    // MARK: - Highlights

    /// What the grid draws for this session (CODESPEC 7.3: shape, not color alone).
    var highlight: HintHighlight {
        var result = HintHighlight()
        switch content {
        case let .mistake(cell, _):
            guard let cell else { return result }
            if rung >= 1 { result.areaCells = Set(House(kind: .box, index: SolverBoard.box(of: cell)).cells) }
            if rung >= 2 { result.patternCells = [cell] }
        case let .step(step, board):
            let isPlacement = !step.placements.isEmpty
            if rung >= 2 {
                result.areaCells = Set(step.houses.flatMap(\.house.cells))
                if result.areaCells.isEmpty, let anchor = step.cells.first { result.areaCells = [anchor.cell] }
            }
            // For singles the pattern cell is the answer, so it is shown only with the result.
            if rung >= 3 && !isPlacement || rung >= 4 {
                result.patternCells = Set(step.cells.map(\.cell))
                for cell in result.patternCells where board.values[cell] == 0 {
                    result.shownCandidates[cell] = Set(SolverBoard.digits(in: board.candidates[cell]))
                    result.ringedDigits[cell] = Set(step.digits).intersection(result.shownCandidates[cell] ?? [])
                }
            }
            if rung >= 4 {
                for elimination in step.eliminations {
                    let shown = Set(SolverBoard.digits(in: board.candidates[elimination.cell]))
                    result.shownCandidates[elimination.cell, default: shown].formUnion(shown)
                    result.struckDigits[elimination.cell, default: []].insert(elimination.digit)
                }
                for placement in step.placements { result.ghostDigits[placement.cell] = placement.digit }
                if showsAfter {
                    result.hiddenDigits = result.struckDigits
                    result.struckDigits = [:]
                }
            }
        case .noStep(let cell):
            if let cell { result.patternCells = [cell] }
        }
        return result
    }
}

/// Grid overlay for an open hint. Cells are 0...80.
struct HintHighlight: Equatable {
    /// Houses to look at (soft tint).
    var areaCells: Set<Int> = []
    /// Pattern cells (heavy outline).
    var patternCells: Set<Int> = []
    /// Candidates to draw in cells that have no notes of their own.
    var shownCandidates: [Int: Set<Int>] = [:]
    /// Key digits (ringed).
    var ringedDigits: [Int: Set<Int>] = [:]
    /// Candidates the step removes (struck through).
    var struckDigits: [Int: Set<Int>] = [:]
    /// Candidates to hide, whatever their source ("Show after" view of eliminations).
    var hiddenDigits: [Int: Set<Int>] = [:]
    /// Digits the step places (shown faint).
    var ghostDigits: [Int: Int] = [:]

    var isEmpty: Bool { self == HintHighlight() }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
