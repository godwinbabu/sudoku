import Foundation

/// How hard a puzzle is for a person (CODESPEC 2.2): the techniques the logical solver needs.
struct PuzzleGrade: Codable, Equatable {
    let hardestTier: TechniqueTier
    /// Sum of step scores (HINT_STRATEGIES.md); orders puzzles within a level.
    let score: Int
    /// Techniques used, in curriculum order.
    let techniques: [Technique]
    /// Solver steps per tier, Basic to Expert (CODESPEC 2.2). Nil in grades saved before issue #92.
    var stepsPerTier: [Int]?
    /// Distinct cells any single fills on the starting board. Nil in grades saved before issue #92.
    var openingSingles: Int?

    /// The level of the hardest technique needed (CODESPEC 2.2).
    var difficulty: Difficulty { techniques.map(\.level).max() ?? .easy }

    /// Steps at `tier` or above (walls from Intermediate up); nil when unknown.
    func steps(atLeast tier: TechniqueTier) -> Int? {
        stepsPerTier.map { $0.dropFirst(tier.rawValue - 1).reduce(0, +) }
    }
}

extension Technique {
    /// The lowest level that may need this technique: singles → Easy, pointing and claiming →
    /// Medium, subsets → Hard, wings, fish and the rest of the Advanced tier → Expert, chains → Master.
    var level: Difficulty {
        switch tier {
        case .basic: return .easy
        case .intermediate: return [.pointing, .claiming].contains(self) ? .medium : .hard
        case .advanced: return .expert
        case .expert: return .master
        }
    }
}

enum PuzzleGrader {
    /// Solves step by step, always taking the simplest step. Nil if the solver gets stuck (the
    /// puzzle needs a technique the app does not know yet) — such a puzzle fits no level.
    static func grade(_ values: [Int], allowsUniqueness: Bool = true) -> (grade: PuzzleGrade, solution: [Int])? {
        let result = LogicalSolver(allowsUniqueness: allowsUniqueness).solve(SolverBoard(values: values))
        guard result.isSolved else { return nil }
        let used = Set(result.steps.map(\.technique))
        let start = SolverBoard(values: values)
        let opening = Set(Technique.allCases.filter { $0.tier == .basic }
            .flatMap { LogicalSolver.steps(for: $0, on: start) }.flatMap { $0.placements.map(\.cell) })
        let grade = PuzzleGrade(
            hardestTier: used.map(\.tier).max() ?? .basic,
            score: result.steps.reduce(0) { $0 + $1.technique.score },
            techniques: Technique.allCases.filter(used.contains),
            stepsPerTier: [TechniqueTier.basic, .intermediate, .advanced, .expert].map { tier in
                result.steps.filter { $0.technique.tier == tier }.count
            },
            openingSingles: opening.count
        )
        return (grade, result.board.values)
    }
}

extension PuzzleGrader {
    /// Adds digits from the solution until the board meets its level's targets (CODESPEC 2.2).
    /// Solution digits keep the puzzle unique. Cells go in random order, at most one pass; an added
    /// digit stays only if the level stays the same. Once the givens reach the range, every step is
    /// checked against all targets (opening singles and walls need not move one way), and the first
    /// board inside them all is returned. Nil if none is.
    static func addingGivens(to values: [Int], solution: [Int], level: Difficulty,
                             using rng: inout some RandomNumberGenerator) -> (values: [Int], grade: PuzzleGrade)? {
        let targets = level.targets
        var board = values
        var count = board.filter { $0 != 0 }.count
        func accepted() -> PuzzleGrade? {
            guard let graded = grade(board), graded.grade.difficulty == level, graded.solution == solution else { return nil }
            return graded.grade
        }
        if count >= targets.givens.lowerBound, let grade = accepted(), targets.isMet(by: grade, givens: count) {
            return (board, grade)
        }
        for cell in board.indices.filter({ board[$0] == 0 }).shuffled(using: &rng) where count < targets.givens.upperBound {
            board[cell] = solution[cell]
            // Easy cannot leave Easy by gaining givens; grading it waits for the range.
            if level == .easy && count + 1 < targets.givens.lowerBound {
                count += 1
                continue
            }
            guard let grade = accepted() else {
                board[cell] = 0
                continue
            }
            count += 1
            if count >= targets.givens.lowerBound, targets.isMet(by: grade, givens: count) { return (board, grade) }
        }
        return nil
    }
}

/// Counts solutions by backtracking, stopping at `limit` (CODESPEC 2.1: imports count to 2).
enum SolutionCounter {
    static func count(_ values: [Int], limit: Int = 2) -> Int {
        let board = SolverBoard(values: values)
        guard !board.hasContradiction else { return 0 }
        var count = 0
        search(board, limit: limit, count: &count)
        return count
    }

    private static func search(_ board: SolverBoard, limit: Int, count: inout Int) {
        // Branch on the empty cell with the fewest candidates.
        var best: Int?
        var fewest = 10
        for cell in 0..<81 where board.values[cell] == 0 {
            let options = board.candidates[cell].nonzeroBitCount
            if options == 0 { return }
            if options < fewest { fewest = options; best = cell }
        }
        guard let cell = best else {
            count += 1
            return
        }
        for digit in SolverBoard.digits(in: board.candidates[cell]) {
            var next = board
            next.place(digit, at: cell)
            search(next, limit: limit, count: &count)
            if count >= limit { return }
        }
    }
}
