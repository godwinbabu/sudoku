import Foundation

/// Solves like a person, one step at a time (CODESPEC 13.3). Tries techniques in curriculum order
/// (`Technique.allCases`) and returns the simplest step that changes the board. The same loop
/// drives hints, grading and drills.
struct LogicalSolver {
    /// False for puzzles that may have several solutions: uniqueness techniques are skipped
    /// (CODESPEC 2.1).
    var allowsUniqueness = true

    /// The simplest step available on `board`, or nil if the board is solved, contradictory, or
    /// needs a technique the solver does not know yet.
    func nextStep(_ board: SolverBoard) -> TechniqueStep? {
        guard !board.isSolved, !board.hasContradiction else { return nil }
        for technique in Technique.allCases where allowsUniqueness || !technique.needsUniqueSolution {
            let found = Self.steps(for: technique, on: board).filter { $0.changeCount > 0 }
            if let best = found.min(by: Self.isPreferred) { return best }
        }
        return nil
    }

    struct Result {
        let steps: [TechniqueStep]
        let board: SolverBoard
        var isSolved: Bool { board.isSolved }
    }

    /// Applies steps until the board is solved or no known technique applies.
    func solve(_ board: SolverBoard) -> Result {
        var board = board
        var steps: [TechniqueStep] = []
        while let step = nextStep(board) {
            board.apply(step)
            steps.append(step)
        }
        return Result(steps: steps, board: board)
    }

    static func steps(for technique: Technique, on board: SolverBoard) -> [TechniqueStep] {
        detectors[technique]?(board) ?? []
    }

    /// One detector per technique (HINT_STRATEGIES.md gives the order, `Technique.allCases`).
    static let detectors: [Technique: (SolverBoard) -> [TechniqueStep]] = [
        .fullHouse: SinglesDetector.fullHouses,
        .hiddenSingleBox: { SinglesDetector.hiddenSingles($0, in: House.boxes, technique: .hiddenSingleBox) },
        .hiddenSingleLine: { SinglesDetector.hiddenSingles($0, in: House.lines, technique: .hiddenSingleLine) },
        .nakedSingle: SinglesDetector.nakedSingles,
        .pointing: IntersectionDetector.pointing,
        .claiming: IntersectionDetector.claiming,
        .lockedPair: { SubsetDetector.locked($0, size: 2) },
        .lockedTriple: { SubsetDetector.locked($0, size: 3) },
        .nakedPair: { SubsetDetector.naked($0, size: 2) },
        .hiddenPair: { SubsetDetector.hidden($0, size: 2) },
        .nakedTriple: { SubsetDetector.naked($0, size: 3) },
        .hiddenTriple: { SubsetDetector.hidden($0, size: 3) },
        .nakedQuad: { SubsetDetector.naked($0, size: 4) },
        .hiddenQuad: { SubsetDetector.hidden($0, size: 4) },
        .xWing: { FishDetector.fish($0, size: 2) },
        .skyscraper: SingleDigitDetector.skyscrapers,
        .twoStringKite: SingleDigitDetector.twoStringKites,
        .emptyRectangle: SingleDigitDetector.emptyRectangles,
        .swordfish: { FishDetector.fish($0, size: 3) },
        .xyWing: WingDetector.xyWings,
        .xyzWing: MoreWingsDetector.xyzWings,
        .wWing: MoreWingsDetector.wWings,
        .simpleColoring: ColoringDetector.simpleColoring,
        .uniqueRectangle1: { UniquenessDetector.uniqueRectangles($0, type: 1) },
        .uniqueRectangle2: { UniquenessDetector.uniqueRectangles($0, type: 2) },
        .uniqueRectangle4: { UniquenessDetector.uniqueRectangles($0, type: 4) },
        .bugPlusOne: UniquenessDetector.bugPlusOne
    ]

    /// Deterministic choice between steps of one technique: fewest pattern cells, then most changes,
    /// then lowest cells, then lowest houses. Never depends on Set or Dictionary order.
    static func isPreferred(_ a: TechniqueStep, over b: TechniqueStep) -> Bool {
        if a.cells.count != b.cells.count { return a.cells.count < b.cells.count }
        if a.changeCount != b.changeCount { return a.changeCount > b.changeCount }
        let aTargets = (a.placements + a.eliminations).map(\.cell).sorted()
        let bTargets = (b.placements + b.eliminations).map(\.cell).sorted()
        if aTargets != bTargets { return aTargets.lexicographicallyPrecedes(bTargets) }
        let aCells = a.cells.map(\.cell).sorted(), bCells = b.cells.map(\.cell).sorted()
        if aCells != bCells { return aCells.lexicographicallyPrecedes(bCells) }
        if a.digits != b.digits { return a.digits.lexicographicallyPrecedes(b.digits) }
        return a.houses.map(\.house).lexicographicallyPrecedes(b.houses.map(\.house))
    }
}

/// All size-`k` combinations of `items`, in lexicographic order.
func combinations<T>(_ items: [T], size k: Int) -> [[T]] {
    guard k > 0, items.count >= k else { return k == 0 ? [[]] : [] }
    var result: [[T]] = []
    var indices = Array(0..<k)
    while true {
        result.append(indices.map { items[$0] })
        var i = k - 1
        while i >= 0 && indices[i] == items.count - k + i { i -= 1 }
        if i < 0 { return result }
        indices[i] += 1
        for j in (i + 1)..<k { indices[j] = indices[j - 1] + 1 }
    }
}
