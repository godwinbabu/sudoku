import Foundation

/// The coach (CODESPEC 6.3.3): every pattern on the player's board, simplest first. Each one is
/// named, highlighted and explained, and the player is asked to find the move. "Show me" reveals it,
/// like step 3 of a hint.
struct CoachSession: Equatable {
    /// The solver's view of the board when the coach opened.
    let board: SolverBoard
    /// Never empty.
    let patterns: [TechniqueStep]
    private(set) var index = 0
    /// The current pattern's move is shown.
    private(set) var revealed = false
    /// The body shows what the technique is, in general, instead of this board's pattern.
    private(set) var showsDefinition = false
    /// Every pattern the player has revealed, in order; each counts as one hint when the coach closes.
    private(set) var revealedSteps: [TechniqueStep] = []

    init?(board: SolverBoard, patterns: [TechniqueStep]) {
        guard !patterns.isEmpty else { return nil }
        self.board = board
        self.patterns = patterns
    }

    var current: TechniqueStep { patterns[index] }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < patterns.count - 1 }

    mutating func forward() { move(by: 1) }
    mutating func back() { move(by: -1) }

    private mutating func move(by delta: Int) {
        let target = index + delta
        guard patterns.indices.contains(target) else { return }
        index = target
        showsDefinition = false
        syncReveal()
    }

    mutating func reveal() {
        revealed = true
        showsDefinition = false
        if !revealedSteps.contains(current) { revealedSteps.append(current) }
    }

    mutating func toggleDefinition() { showsDefinition.toggle() }

    /// The current pattern as a hint at step 2 (pattern marks), or step 3 once revealed. Its
    /// highlight, action and log entry are the hint's.
    var hint: HintSession { HintSession(content: .step(current, board: board), level: revealed ? 3 : 2) }

    var highlight: HintHighlight { hint.highlight }

    // MARK: - Text

    /// "2 of 5"
    var position: String { "\(index + 1) of \(patterns.count)" }
    var title: String { current.technique.displayName }
    var tierLabel: String { current.technique.learnTier.displayName }

    /// Paging back to a revealed pattern shows it revealed again.
    private mutating func syncReveal() { revealed = revealedSteps.contains(current) }

    func text(_ names: CellNotation) -> String {
        if showsDefinition { return current.technique.definition }
        if revealed { return hint.text(names) }
        let ask = current.placements.isEmpty ? "Can you see which candidates it rules out?" : "Can you find the digit it places?"
        return "\(current.reason(names)) \(ask)"
    }

    func accessibilityText(_ names: CellNotation) -> String {
        revealed && !showsDefinition ? hint.accessibilityText(names) : text(names)
    }
}
