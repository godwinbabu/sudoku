import Foundation

/// One open hint (CODESPEC 6.3.1): three free steps, then one action. 1 = where to look,
/// 2 = technique (or "Mistake"), 3 = why. The board never changes while a session is open, except
/// through the step-3 action.
struct HintSession: Equatable {
    enum MistakeKind: Equatable {
        /// A placed digit is wrong.
        case wrongDigit(Int)
        /// A cell's notes leave out its correct digit.
        case missingNote
        /// Imported puzzle: the entries fit no solution, and no single cell can be blamed.
        case entriesConflict
    }

    enum Content: Equatable {
        case mistake(cell: Int?, kind: MistakeKind)
        /// `board` is the solver's view of the board when the hint opened (shows candidates).
        case step(TechniqueStep, board: SolverBoard)
        /// No known technique applies: place the answer in `cell`.
        case noStep(cell: Int?, digit: Int?)
    }

    static let stepCount = 3

    let content: Content
    private(set) var level: Int
    private(set) var deepestLevel: Int

    /// Hints with nothing to step through (no step found, entries that clash) open at step 3.
    init(content: Content, level: Int = 1) {
        self.content = content
        switch content {
        case .noStep, .mistake(cell: nil, kind: _): self.level = Self.stepCount
        default: self.level = min(max(level, 1), Self.stepCount)
        }
        deepestLevel = self.level
    }

    var step: TechniqueStep? {
        if case let .step(step, _) = content { return step }
        return nil
    }

    var isMistake: Bool {
        if case .mistake = content { return true }
        return false
    }

    var canGoNext: Bool { level < Self.stepCount }

    /// Step 3's action: place, remove or clear. Clashing entries offer Undo instead.
    var canApply: Bool {
        guard level == Self.stepCount else { return false }
        switch content {
        case .mistake(let cell, _): return cell != nil
        case .step: return true
        case .noStep(let cell, let digit): return cell != nil && digit != nil
        }
    }

    mutating func next() {
        guard canGoNext else { return }
        level += 1
        deepestLevel = max(deepestLevel, level)
    }

    // MARK: - Text

    /// The small caps label next to the progress pills.
    var stepLabel: String {
        switch level {
        case 1: return "Where to look"
        case 2: return isMistake ? "Mistake" : "Technique"
        default: return "Why"
        }
    }

    /// "· Beginner", from step 2, for technique hints.
    var tierLabel: String? { level >= 2 ? step?.technique.tierName : nil }

    /// The technique name, shown in serif above the text at step 2.
    var title: String? { level == 2 ? step?.technique.displayName : nil }

    /// The technique whose lesson "Lesson →" opens, from step 2.
    var lessonTechnique: Technique? { level >= 2 ? step?.technique : nil }

    func text(_ names: CellNotation) -> String {
        switch content {
        case let .mistake(cell, kind):
            return mistakeText(cell: cell, kind: kind, names: names)
        case let .step(step, board):
            switch level {
            case 1: return step.nudge(names)
            case 2: return step.technique.definition
            default: return step.why(names, on: board)
            }
        case let .noStep(cell, digit):
            guard let cell, let digit else { return "There's no step I can explain here." }
            return "This step needs a technique beyond what hints explain yet. Placing \(digit) in \(names.cell(cell))."
        }
    }

    private func mistakeText(cell: Int?, kind: MistakeKind, names: CellNotation) -> String {
        guard let cell else { return "Some of your entries don't fit together. Try undoing recent moves." }
        if level == 1 { return "Something in \(names.box(SolverBoard.box(of: cell))) doesn't fit." }
        if case .wrongDigit(let digit) = kind {
            return "The \(digit) in \(names.cell(cell)) can't be right — the puzzle doesn't solve with it."
        }
        return "The notes in \(names.cell(cell)) leave out its digit."
    }

    /// The card's main button.
    var actionLabel: String? {
        switch (content, level) {
        case (.mistake(cell: nil, kind: _), _): return nil
        case (.mistake, 1): return "Show me"
        case (_, 1): return "Which technique?"
        case (_, 2): return "Show me why"
        case (.mistake, _): return "Clear it"
        case let (.noStep(_, digit?), _): return "Place \(digit) · assisted"
        case (.noStep, _): return nil
        case let (.step(step, _), _):
            if let target = step.target { return "Place \(target.digit) · assisted" }
            let digits = Set(step.eliminations.map(\.digit))
            return digits.count == 1 ? "Remove \(digits.first!) · assisted" : "Apply · assisted"
        }
    }

    // MARK: - Highlights

    /// What the grid draws for this session (CODESPEC 7.3: shape, not color alone).
    /// Step 1 spotlights the focus; 2 adds the pattern fill; 3 adds evidence rings, the dashed
    /// target with its ghost digit, and the struck candidates.
    var highlight: HintHighlight {
        var result = HintHighlight()
        switch content {
        case let .mistake(cell, _):
            guard let cell else { return result }
            result.areaCells = Set(House(kind: .box, index: SolverBoard.box(of: cell)).cells)
            if level >= 2 { result.targetCells = [cell] }
        case let .step(step, board):
            result.areaCells = step.focus
            if level >= 2 {
                result.patternCells = step.pattern
                for cell in result.patternCells where board.values[cell] == 0 {
                    result.shownCandidates[cell] = Set(SolverBoard.digits(in: board.candidates[cell]))
                    result.ringedDigits[cell] = Set(step.digits).intersection(result.shownCandidates[cell] ?? [])
                }
            }
            if level >= 3 {
                result.evidenceCells = step.evidence(on: board)
                for elimination in step.eliminations {
                    let shown = Set(SolverBoard.digits(in: board.candidates[elimination.cell]))
                    result.shownCandidates[elimination.cell, default: shown].formUnion(shown)
                    result.struckDigits[elimination.cell, default: []].insert(elimination.digit)
                }
                for placement in step.placements { result.ghostDigits[placement.cell] = placement.digit }
            }
        case let .noStep(cell, digit):
            guard let cell else { return result }
            result.areaCells = [cell]
            if let digit { result.ghostDigits[cell] = digit }
        }
        return result
    }
}

/// Grid overlay for an open hint. Cells are 0...80.
struct HintHighlight: Equatable {
    /// The spotlight: everything else fades to `focusDim`.
    var areaCells: Set<Int> = []
    /// Pattern cells (filled like same-digit cells).
    var patternCells: Set<Int> = []
    /// Cells that prove the step (solid ring).
    var evidenceCells: Set<Int> = []
    /// Dashed target ring without a ghost digit (a mistake to clear).
    var targetCells: Set<Int> = []
    /// Candidates to draw in cells that have no notes of their own.
    var shownCandidates: [Int: Set<Int>] = [:]
    /// Key digits (ringed).
    var ringedDigits: [Int: Set<Int>] = [:]
    /// Candidates the step removes (struck through).
    var struckDigits: [Int: Set<Int>] = [:]
    /// Digits the step places (dashed target, faint ghost digit).
    var ghostDigits: [Int: Int] = [:]

    var isEmpty: Bool { self == HintHighlight() }
}
