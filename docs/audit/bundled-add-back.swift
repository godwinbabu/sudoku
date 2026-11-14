// Rebuilds BundledPuzzles.swift with target givens per level (CODESPEC 2.2, issue #60).
// Each bundled puzzle gets solution digits added back with PuzzleGrader.addingGivens, seeded by
// 20261113 + its index (then + 1000 per retry), so the output is deterministic. A puzzle that
// loses a technique keeps its original board as a drill-only line, so no drill disappears.
// Run from the repo root against the current file, then paste the lines into BundledPuzzles.data:
//   cp docs/audit/bundled-add-back.swift /tmp/main.swift
//   swiftc -O -o /tmp/addback $(ls PureSudoku/Engine/*.swift | grep -v ImageDetector) PureSudoku/Models/Difficulty.swift /tmp/main.swift
//   /tmp/addback > /tmp/lines.txt
import Foundation

func line(_ level: Difficulty, _ values: [Int], _ solution: String, _ grade: PuzzleGrade, drill: Bool) -> String {
    let fields = [level.rawValue, values.map(String.init).joined(), solution, String(grade.score),
                  grade.techniques.map(\.rawValue).joined(separator: ",")]
    return (fields + (drill ? ["drill"] : [])).joined(separator: "|")
}

var drills: [String] = []
for (index, entry) in BundledPuzzles.all.enumerated() where !entry.isDrillOnly {
    let values = entry.initialGrid.map { Int(String($0))! }
    let solution = entry.solutionGrid.map { Int(String($0))! }
    var result: (values: [Int], grade: PuzzleGrade)?
    for retry in 0..<20 where result == nil {
        var rng = SeededRandomNumberGenerator(seed: 20261113 + UInt64(index) + 1000 * UInt64(retry))
        result = PuzzleGrader.addingGivens(to: values, solution: solution, level: entry.difficulty, using: &rng)
    }
    guard let (board, grade) = result else { fatalError("no add-back for \(entry.initialGrid)") }
    print(line(entry.difficulty, board, entry.solutionGrid, grade, drill: false))
    if !Set(entry.techniques).isSubset(of: grade.techniques) {
        let original = PuzzleGrade(hardestTier: entry.techniques.map(\.tier).max() ?? .basic,
                                   score: entry.score, techniques: entry.techniques)
        drills.append(line(entry.difficulty, values, entry.solutionGrid, original, drill: true))
    }
}
drills.forEach { print($0) }
