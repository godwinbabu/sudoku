// Rebuilds BundledPuzzles.data (CODESPEC 2.2, issue #92). Deterministic.
// 1. Per level, a fresh set of 120 puzzles from this app's generator: a minimal puzzle of the
//    level, then PuzzleGrader.addingGivens to the level's targets (one RNG stream per level, seed
//    20261114 + level rank). Duplicates are skipped.
// 2. Practice-only lines: every board in the input file not in the new sets, deduplicated by grid
//    and regraded, so no drill is lost.
// Input: data lines (only the level, grid and solution fields are read). Run from the repo root:
//   sed -n '/data = """/,/^"""/p' PureSudoku/Engine/BundledPuzzles.swift | sed '1d;$d' > /tmp/old.txt
//   cp docs/audit/bundled-generate.swift /tmp/main.swift
//   swiftc -O -o /tmp/gen $(ls PureSudoku/Engine/*.swift | grep -v ImageDetector) \
//     PureSudoku/Models/{Difficulty,SudokuCell,SudokuPuzzle,GameSource}.swift /tmp/main.swift
//   /tmp/gen /tmp/old.txt > /tmp/lines.txt   # then paste the lines into BundledPuzzles.data
import Foundation

func line(_ level: Difficulty, _ values: [Int], _ solution: [Int], _ grade: PuzzleGrade, drill: Bool) -> String {
    let fields = [level.rawValue, values.map(String.init).joined(), solution.map(String.init).joined(), String(grade.score),
                  grade.techniques.map(\.rawValue).joined(separator: ","),
                  (grade.stepsPerTier ?? []).map(String.init).joined(separator: ","), String(grade.openingSingles ?? 0)]
    return (fields + (drill ? ["drill"] : [])).joined(separator: "|")
}

var fresh = Set<String>()
for level in Difficulty.allCases {
    var rng = SeededRandomNumberGenerator(seed: 20_261_114 + UInt64(level.rank))
    var found = 0
    while found < 120 {
        let minimal = makePuzzle(using: &rng).map { ($0 ?? -1) + 1 }
        guard let (first, solution) = PuzzleGrader.grade(minimal), first.difficulty == level,
              let (values, grade) = PuzzleGrader.addingGivens(to: minimal, solution: solution, level: level, using: &rng),
              fresh.insert(values.map(String.init).joined()).inserted else { continue }
        print(line(level, values, solution, grade, drill: false))
        found += 1
    }
}

let input = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
var seen = fresh
for row in input.split(separator: "\n") {
    let fields = row.split(separator: "|").map(String.init)
    guard fields.count >= 3, seen.insert(fields[1]).inserted else { continue }
    let values = fields[1].map { Int(String($0))! }
    guard let (grade, solution) = PuzzleGrader.grade(values), solution.map(String.init).joined() == fields[2] else {
        fatalError("old board no longer grades: \(fields[1])")
    }
    print(line(grade.difficulty, values, solution, grade, drill: true))
}
