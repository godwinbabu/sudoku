import Foundation

/// The five Learn tiers (Design/v2/README.md "Learn"). Separate from `TechniqueTier`, which also
/// sets puzzle levels: moving a technique between Learn tiers must not change grading.
enum LearnTier: Int, CaseIterable, Identifiable {
    case beginner, intermediate, advanced, expert, esoteric

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        case .esoteric: return "Esoteric"
        }
    }
}

extension Technique {
    /// Where the technique sits in Learn and on the hint card. Uniqueness techniques are Esoteric:
    /// they only work because the puzzle has one solution.
    var learnTier: LearnTier {
        switch self {
        case .xyChain, .simpleColoring: return .expert
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4, .bugPlusOne: return .esoteric
        default:
            switch tier {
            case .basic: return .beginner
            case .intermediate: return .intermediate
            case .advanced: return .advanced
            case .expert: return .expert
            }
        }
    }
}

/// One lesson per technique (CODESPEC 13.5): a board you step through, then practice.
/// Four lessons are written by hand (`LessonScript`); the rest use the template, built from the
/// solver's own step on a bundled puzzle.
struct Lesson {
    struct Step: Equatable {
        let text: String
        let highlight: HintHighlight
    }

    let technique: Technique
    let intro: String
    /// The board: filled cells as givens, no notes.
    let cells: [SudokuCell]
    let steps: [Step]
    /// Up to three practice puzzles that need the technique, easiest first.
    let practice: [BundledPuzzles.Entry]
    let isScripted: Bool

    /// Techniques that have a lesson, in curriculum order. Hidden Single (box/line) is one lesson.
    static var techniques: [Technique] {
        Technique.allCases.filter { $0 != .hiddenSingleLine }
    }

    /// Steps a lesson has, without building it (the template has one per hint step).
    static func stepCount(for technique: Technique) -> Int {
        LessonScript.all[technique]?.steps.count ?? HintSession.stepCount
    }

    static func make(for technique: Technique, names: CellNotation = .plain) -> Lesson? {
        let drills = BundledPuzzles.drills(for: technique)
        if let script = LessonScript.all[technique] {
            return Lesson(technique: technique, intro: script.intro, cells: cells(script.values),
                          steps: script.steps.map { Step(text: $0.text, highlight: $0.highlight) },
                          practice: Array(drills.prefix(3)), isScripted: true)
        }
        // The template: the solver's own step, shown as the three hint steps (where to look, why,
        // what changes).
        guard let example = example(for: technique) else { return nil }
        let step = example.step, board = example.board
        let texts = [step.nudge(names), step.reason(names), step.resultText(names)]
        let steps = texts.enumerated().map { index, text in
            Step(text: text, highlight: HintSession(content: .step(step, board: board), level: index + 1).highlight)
        }
        // Practice uses other puzzles: the example's answer is already shown.
        let practice = drills.filter { $0.initialGrid != example.puzzle.initialGrid }.prefix(3)
        return Lesson(technique: technique, intro: technique.definition, cells: cells(board.values),
                      steps: steps, practice: Array(practice), isScripted: false)
    }

    struct Example {
        let puzzle: BundledPuzzles.Entry
        let board: SolverBoard
        let step: TechniqueStep
    }

    /// Solves the bundled drills until this technique's step comes up: the board just before it,
    /// and the step.
    static func example(for technique: Technique) -> Example? {
        for entry in BundledPuzzles.drills(for: technique) {
            var board = SolverBoard(values: entry.initialGrid.map { Int(String($0)) ?? 0 })
            let solver = LogicalSolver()
            while let step = solver.nextStep(board) {
                if step.technique == technique || (technique == .hiddenSingleBox && step.technique == .hiddenSingleLine) {
                    return Example(puzzle: entry, board: board, step: step)
                }
                board.apply(step)
            }
        }
        return nil
    }

    private static func cells(_ values: [Int]) -> [SudokuCell] {
        (0..<81).map { index in
            let value = values[index]
            return SudokuCell(row: index / 9, col: index % 9, given: value != 0, value: value == 0 ? nil : value)
        }
    }
}

/// A hand-written lesson, ported from Design/v2/ui_kits/puresudoku-2/Learn.jsx. Cells are 0...80.
struct LessonScript {
    enum Mark { case plain, key, struck }

    struct Step {
        let text: String
        var focus: [Int] = []
        var evidence: [Int] = []
        /// Cells the digit can't go in (dotted ring, no notes).
        var ruledOut: [Int] = []
        var pattern: [Int] = []
        var target: Int?
        var ghost: Int?
        /// Notes to draw, per cell and digit.
        var notes: [Int: [Int: Mark]] = [:]

        var highlight: HintHighlight {
            var result = HintHighlight()
            result.areaCells = Set(focus)
            result.evidenceCells = Set(evidence)
            result.patternCells = Set(pattern)
            for cell in ruledOut { result.struckDigits[cell] = [] }
            if let target, let ghost { result.ghostDigits[target] = ghost }
            for (cell, digits) in notes {
                result.shownCandidates[cell] = Set(digits.keys)
                let keys = digits.filter { $0.value == .key }.keys, struck = digits.filter { $0.value == .struck }.keys
                if !keys.isEmpty { result.ringedDigits[cell] = Set(keys) }
                if !struck.isEmpty { result.struckDigits[cell] = Set(struck) }
            }
            return result
        }
    }

    let intro: String
    let values: [Int]
    let steps: [Step]

    init(intro: String, givens: [Int: Int], steps: [Step]) {
        self.intro = intro
        self.values = (0..<81).map { givens[$0] ?? 0 }
        self.steps = steps
    }

    private static let box1 = [0, 1, 2, 9, 10, 11, 18, 19, 20]
    private static func row(_ index: Int) -> [Int] { (0..<9).map { index * 9 + $0 } }
    private static func column(_ index: Int) -> [Int] { (0..<9).map { $0 * 9 + index } }

    static let all: [Technique: LessonScript] = [
        .hiddenSingleBox: hiddenSingle, .pointing: pointing, .nakedPair: nakedPair, .xWing: xWing
    ]

    static let hiddenSingle = LessonScript(
        intro: "The most useful move in Sudoku. Instead of asking “what goes in this cell?”, ask “where does this digit go?”",
        givens: [0: 7, 9: 3, 20: 8, 13: 5, 25: 5, 37: 5, 6: 2, 50: 9, 60: 4, 75: 6, 31: 3, 66: 1],
        steps: [
            Step(text: "Pick one box and one digit. Where can 5 go in box 1?", focus: box1),
            Step(text: "The 5 in row 2 covers all of row 2 — so not the middle row of this box.",
                 focus: box1 + [13], evidence: [13], ruledOut: [10, 11]),
            Step(text: "The 5 in row 3 rules out the bottom row as well.",
                 focus: box1 + [13, 25], evidence: [13, 25], ruledOut: [10, 11, 18, 19]),
            Step(text: "And the 5 in column 2 rules out the top-middle cell.",
                 focus: box1 + [13, 25, 37], evidence: [13, 25, 37], ruledOut: [10, 11, 18, 19, 1]),
            Step(text: "One cell is left. 5 must go here — the digit was hidden among other possibilities, but it has only one home.",
                 focus: box1 + [13, 25, 37], evidence: [13, 25, 37], target: 2, ghost: 5)
        ]
    )

    static let pointing = LessonScript(
        intro: "Your first elimination. It doesn’t place a digit on its own — it removes candidates so a single appears.",
        givens: [0: 5, 1: 8, 10: 4, 18: 6, 19: 2, 20: 9, 6: 3, 12: 7, 14: 1, 17: 6],
        steps: [
            Step(text: "Look at 3 in box 1. It has two possible cells — and both sit in row 2.",
                 focus: box1, notes: [9: [3: .key], 11: [3: .key]]),
            Step(text: "Whichever cell it takes, box 1’s 3 lives in row 2. That claims row 2’s 3.",
                 focus: box1 + row(1), pattern: [9, 11], notes: [9: [3: .key], 11: [3: .key], 13: [3: .plain], 16: [3: .plain]]),
            Step(text: "So 3 can’t go anywhere else in row 2. Cross it off.",
                 focus: box1 + row(1), pattern: [9, 11], notes: [9: [3: .key], 11: [3: .key], 13: [3: .struck], 16: [3: .struck]]),
            Step(text: "The box points along a line. Its mirror image, Claiming, is when a line confines a digit to one box.",
                 focus: box1 + row(1), pattern: [9, 11], notes: [9: [3: .key], 11: [3: .key]])
        ]
    )

    static let nakedPair: LessonScript = {
        let pencilled: [Int: [Int: Mark]] = [
            37: [2: .plain, 7: .plain], 38: [2: .plain, 4: .plain, 7: .plain], 40: [2: .plain, 7: .plain],
            41: [3: .plain, 4: .plain, 5: .plain, 7: .plain], 43: [3: .plain, 6: .plain], 44: [2: .plain, 4: .plain, 5: .plain, 6: .plain]
        ]
        var paired = pencilled
        paired[37] = [2: .key, 7: .key]
        paired[40] = [2: .key, 7: .key]
        var crossed = paired
        crossed[38] = [2: .struck, 4: .plain, 7: .struck]
        crossed[41] = [3: .plain, 4: .plain, 5: .plain, 7: .struck]
        crossed[44] = [2: .struck, 4: .plain, 5: .plain, 6: .plain]
        let single: [Int: [Int: Mark]] = [
            37: [2: .key, 7: .key], 40: [2: .key, 7: .key], 41: [3: .plain, 4: .plain, 5: .plain],
            43: [3: .plain, 6: .plain], 44: [4: .plain, 5: .plain, 6: .plain]
        ]
        return LessonScript(
            intro: "When two cells in a unit can only be the same two digits, those digits are taken — "
                + "even before you know which is which.",
            givens: [36: 9, 39: 1, 42: 8],
            steps: [
                Step(text: "Row 5, with its candidates pencilled in.", focus: row(4), notes: pencilled),
                Step(text: "Two cells can only be 2 or 7. Between them, they’ll use both.",
                     focus: row(4), pattern: [37, 40], notes: paired),
                Step(text: "So no other cell in row 5 can be 2 or 7. Cross them out.", focus: row(4), pattern: [37, 40], notes: crossed),
                Step(text: "The third cell is left with only 4. A Naked Single drops out.",
                     focus: row(4), pattern: [37, 40], target: 38, ghost: 4, notes: single)
            ]
        )
    }()

    static let xWing: LessonScript = {
        let corners: [Int: [Int: Mark]] = [11: [4: .key], 16: [4: .key], 56: [4: .key], 61: [4: .key]]
        var cleared = corners
        for cell in [29, 74, 43, 25] { cleared[cell] = [4: .struck] }
        for cell in [32, 48] { cleared[cell] = [4: .plain] }
        return LessonScript(
            intro: "Your first “fish”. One digit, two lines, and a rectangle that locks it in place.",
            givens: [9: 6, 10: 1, 12: 8, 14: 2, 15: 9, 17: 5, 54: 3, 55: 9, 57: 5, 59: 7, 60: 1, 62: 8],
            steps: [
                Step(text: "Follow one digit: 4. In row 2 it has only two possible cells.",
                     focus: row(1), notes: [11: [4: .key], 16: [4: .key]]),
                Step(text: "Row 7 is the same — two cells, and in the same two columns.", focus: row(1) + row(6), notes: corners),
                Step(text: "Whichever way they fall, one 4 lands in each column at these corners. That’s the X.",
                     focus: row(1) + row(6), pattern: [11, 16, 56, 61], notes: corners),
                Step(text: "So every other 4 in columns 3 and 8 can go.",
                     focus: column(2) + column(7), pattern: [11, 16, 56, 61], notes: cleared)
            ]
        )
    }()
}
