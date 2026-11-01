import Foundation
var rng = SystemRandomNumberGenerator()
var rs: [Double] = []; var clues: [Int] = []
for _ in 0..<200 {
    let b = makePuzzle(using: &rng)
    rs.append(ratePuzzle(b, samples: 4, using: &rng)); clues.append(b.compactMap{$0}.count)
}
rs.sort(); clues.sort()
print("ratings min \(rs.first!) median \(rs[100]) p90 \(rs[180]) max \(rs.last!)")
print("clues min \(clues.first!) median \(clues[100]) max \(clues.last!)")
var best = 0.0
var r2 = SystemRandomNumberGenerator()
var maxOf25: [Double] = []
for _ in 0..<20 { var m = 0.0; for _ in 0..<25 { let b = makePuzzle(using: &r2); m = max(m, ratePuzzle(b, samples: 4, using: &r2)) }; maxOf25.append(m) }
maxOf25.sort(); print("best of 25 (what Hard gets): min \(maxOf25.first!) median \(maxOf25[10]) max \(maxOf25.last!)")
