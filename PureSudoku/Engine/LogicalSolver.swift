import Foundation

/// Solves like a person, one step at a time (CODESPEC 13.3). Tries techniques in curriculum order
/// (`Technique.allCases`) and returns the simplest step that changes the board. The same loop
/// drives hints, grading and drills.
struct LogicalSolver {
    /// The simplest step available on `board`, or nil if the board is solved, contradictory, or
    /// needs a technique the solver does not know yet.
    func nextStep(_ board: SolverBoard) -> TechniqueStep? {
        guard !board.isSolved, !board.hasContradiction else { return nil }
        for technique in Technique.allCases {
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
        switch technique {
        case .fullHouse: return SinglesDetector.fullHouses(board)
        case .hiddenSingleBox: return SinglesDetector.hiddenSingles(board, in: House.boxes, technique: .hiddenSingleBox)
        case .hiddenSingleLine: return SinglesDetector.hiddenSingles(board, in: House.lines, technique: .hiddenSingleLine)
        case .nakedSingle: return SinglesDetector.nakedSingles(board)
        case .pointing: return IntersectionDetector.pointing(board)
        case .claiming: return IntersectionDetector.claiming(board)
        case .lockedPair: return SubsetDetector.locked(board, size: 2)
        case .lockedTriple: return SubsetDetector.locked(board, size: 3)
        case .nakedPair: return SubsetDetector.naked(board, size: 2)
        case .hiddenPair: return SubsetDetector.hidden(board, size: 2)
        case .nakedTriple: return SubsetDetector.naked(board, size: 3)
        case .hiddenTriple: return SubsetDetector.hidden(board, size: 3)
        case .nakedQuad: return SubsetDetector.naked(board, size: 4)
        case .hiddenQuad: return SubsetDetector.hidden(board, size: 4)
        case .xWing: return FishDetector.fish(board, size: 2)
        case .swordfish: return FishDetector.fish(board, size: 3)
        case .xyWing: return WingDetector.xyWings(board)
        }
    }

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
