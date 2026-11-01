import Foundation

/// One lesson per technique (CODESPEC 13.5): one worked example on a real board, then practice.
struct Lesson {
    let technique: Technique
    /// The board just before the example step, and the step itself.
    let board: SolverBoard
    let step: TechniqueStep
    /// Up to three practice puzzles that need the technique, easiest first.
    let practice: [BundledPuzzles.Entry]

    /// Techniques that have a lesson, in curriculum order. Hidden Single (box/line) is one lesson.
    static var techniques: [Technique] {
        Technique.allCases.filter { $0 != .hiddenSingleLine }
    }

    /// Builds the lesson from the bundled puzzles: solve a drill until this technique's step comes up.
    static func make(for technique: Technique) -> Lesson? {
        let drills = BundledPuzzles.drills(for: technique)
        for entry in drills {
            var board = SolverBoard(values: entry.initialGrid.map { Int(String($0)) ?? 0 })
            let solver = LogicalSolver()
            while let step = solver.nextStep(board) {
                if step.technique == technique || (technique == .hiddenSingleBox && step.technique == .hiddenSingleLine) {
                    // Practice uses other puzzles: the example's answer is already shown.
                    let practice = drills.filter { $0.initialGrid != entry.initialGrid }.prefix(3)
                    return Lesson(technique: technique, board: board, step: step, practice: Array(practice))
                }
                board.apply(step)
            }
        }
        return nil
    }

    /// Game cells for showing the example board (filled cells as givens, no notes).
    var cells: [SudokuCell] {
        (0..<81).map { index in
            let value = board.values[index]
            return SudokuCell(row: index / 9, col: index % 9, given: value != 0, value: value == 0 ? nil : value)
        }
    }

    /// The example drawn like a hint at its result rung: pattern, key digits, removals.
    var highlight: HintHighlight {
        var session = HintSession(content: .step(step, board: board))
        for _ in 0..<3 { _ = session.next(askFirst: false) }
        return session.highlight
    }
}
