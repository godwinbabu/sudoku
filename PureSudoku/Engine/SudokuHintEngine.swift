import Foundation

enum HintTechnique: String, Codable {
    case nakedSingle = "Naked Single"
    case nakedTriple = "Naked Triple"
    case nakedQuad = "Naked Quad"
    case hiddenSingleRow = "Hidden Single (Row)"
    case hiddenSingleCol = "Hidden Single (Column)"
    case hiddenSingleBox = "Hidden Single (Box)"
    case hiddenTripleRow = "Hidden Triple (Row)"
    case hiddenTripleCol = "Hidden Triple (Column)"
    case hiddenTripleBox = "Hidden Triple (Box)"
    case hiddenQuadRow = "Hidden Quad (Row)"
    case hiddenQuadCol = "Hidden Quad (Column)"
    case hiddenQuadBox = "Hidden Quad (Box)"
    case invalid = "Invalid"
}

struct GeneratorHint: Equatable, Codable {
    let technique: HintTechnique
    let positions: [Int] // linear 0...80
    let digit: Int? // 0...8 represents 1...9
    let message: String
}

/// Returns a lightweight hint for the current board (no guessing; only singles).
/// - Returns: `GeneratorHint` if a deterministic move is found; `nil` if none or board is solved.
func nextHint(for board: GeneratorBoard) -> GeneratorHint? {
    // Reject invalid positions early
    if hasContradiction(board) {
        return GeneratorHint(technique: .invalid, positions: [], digit: nil, message: "Board has a contradiction (duplicate in a row/column/box).")
    }

    let info = figureBits(board)

    // Naked singles
    for pos in 0..<81 where board[pos] == nil {
        let nums = listBits(info.allowed[pos])
        if nums.count == 1 {
            let d = nums[0]
            let (r, c) = rowCol(from: pos)
            return GeneratorHint(
                technique: .nakedSingle,
                positions: [pos],
                digit: d,
                message: "Cell r\(r + 1)c\(c + 1) must be \(d + 1) (naked single)."
            )
        }
    }

    // Hidden singles in each unit
    for axis in 0..<3 {
        for x in 0..<9 {
            let needed = listBits(info.needed[axis * 9 + x])
            for n in needed {
                let bit = 1 << n
                var spots: [Int] = []
                for y in 0..<9 {
                    let pos = posFor(x: x, y: y, axis: axis)
                    if info.allowed[pos] & bit != 0 {
                        spots.append(pos)
                    }
                }
                if spots.count == 1 {
                    let pos = spots[0]
                    let (r, c) = rowCol(from: pos)
                    let tech: HintTechnique = (axis == 0 ? .hiddenSingleRow : axis == 1 ? .hiddenSingleCol : .hiddenSingleBox)
                    return GeneratorHint(
                        technique: tech,
                        positions: [pos],
                        digit: n,
                        message: "Digit \(n + 1) fits only at r\(r + 1)c\(c + 1) in this \(axisName(axis))."
                    )
                }
            }
        }
    }

    // Naked triples/quads
    if let nakedTriple = findNakedSet(of: 3, info: info, board: board) {
        return nakedTriple
    }
    if let nakedQuad = findNakedSet(of: 4, info: info, board: board) {
        return nakedQuad
    }

    // Hidden triples/quads
    if let hiddenTriple = findHiddenSet(of: 3, info: info, board: board) {
        return hiddenTriple
    }
    if let hiddenQuad = findHiddenSet(of: 4, info: info, board: board) {
        return hiddenQuad
    }

    return nil
}

func hasContradiction(_ board: GeneratorBoard) -> Bool {
    var rowMask = Array(repeating: 0, count: 9)
    var colMask = Array(repeating: 0, count: 9)
    var boxMask = Array(repeating: 0, count: 9)

    for pos in 0..<81 {
        guard let val = board[pos] else { continue }
        let bit = 1 << val
        let row = pos / 9
        let col = pos % 9
        let box = (pos / 27) * 3 + (pos / 3) % 3

        if rowMask[row] & bit != 0 { return true }
        if colMask[col] & bit != 0 { return true }
        if boxMask[box] & bit != 0 { return true }

        rowMask[row] |= bit
        colMask[col] |= bit
        boxMask[box] |= bit
    }

    return false
}

private func rowCol(from pos: Int) -> (Int, Int) {
    return (pos / 9, pos % 9)
}

private func axisName(_ axis: Int) -> String {
    switch axis {
    case 0: return "row"
    case 1: return "column"
    default: return "box"
    }
}

private func findNakedSet(of size: Int, info: (allowed: [Int], needed: [Int]), board: GeneratorBoard) -> GeneratorHint? {
    for axis in 0..<3 {
        for x in 0..<9 {
            // Collect empty positions in the unit
            let positions: [Int] = (0..<9).compactMap { y in
                let pos = posFor(x: x, y: y, axis: axis)
                return board[pos] == nil ? pos : nil
            }
            guard positions.count >= size else { continue }
            for combo in combinations(of: positions, taking: size) {
                let masks = combo.map { info.allowed[$0] }
                let union = masks.reduce(0, |)
                let unionDigits = listBits(union)
                // Naked set must exactly cover `size` digits and each member's candidates are subset of union with small size.
                guard unionDigits.count == size,
                      masks.allSatisfy({ bitCount($0) <= size && ($0 & ~union) == 0 }) else { continue }
                // Ensure there's something to eliminate elsewhere in the unit (an overlapping candidate).
                let others = positions.filter { !combo.contains($0) }
                let hasOverlap = others.contains { info.allowed[$0] & union != 0 }
                guard hasOverlap else { continue }

                let sortedPositions = combo.sorted()
                let digitsString = unionDigits.map { "\($0 + 1)" }.joined(separator: ", ")
                let label = axisName(axis)
                let technique: HintTechnique = size == 3 ? .nakedTriple : .nakedQuad
                return GeneratorHint(
                    technique: technique,
                    positions: sortedPositions,
                    digit: nil,
                    message: "Naked \(size) in \(label) \(x + 1): digits \(digitsString) are confined to these cells."
                )
            }
        }
    }
    return nil
}

private func findHiddenSet(of size: Int, info: (allowed: [Int], needed: [Int]), board: GeneratorBoard) -> GeneratorHint? {
    for axis in 0..<3 {
        for x in 0..<9 {
            let neededBits = info.needed[axis * 9 + x]
            let missingDigits = listBits(neededBits)
            guard missingDigits.count >= size else { continue }
            for digitCombo in combinations(of: missingDigits, taking: size) {
                var positionSet = Set<Int>()
                var valid = true
                for digit in digitCombo {
                    var positionsForDigit: [Int] = []
                    for y in 0..<9 {
                        let pos = posFor(x: x, y: y, axis: axis)
                        guard board[pos] == nil else { continue }
                        if info.allowed[pos] & (1 << digit) != 0 {
                            positionsForDigit.append(pos)
                        }
                    }
                    if positionsForDigit.isEmpty {
                        valid = false
                        break
                    }
                    positionSet.formUnion(positionsForDigit)
                }
                guard valid, positionSet.count == size else { continue }

                let sortedPositions = positionSet.sorted()
                let digitsString = digitCombo.sorted().map { "\($0 + 1)" }.joined(separator: ", ")
                let label = axisName(axis)
                let technique: HintTechnique
                switch size {
                case 3:
                    technique = axis == 0 ? .hiddenTripleRow : axis == 1 ? .hiddenTripleCol : .hiddenTripleBox
                default:
                    technique = axis == 0 ? .hiddenQuadRow : axis == 1 ? .hiddenQuadCol : .hiddenQuadBox
                }
                return GeneratorHint(
                    technique: technique,
                    positions: sortedPositions,
                    digit: nil,
                    message: "Hidden \(size) in \(label) \(x + 1): digits \(digitsString) appear only in these cells."
                )
            }
        }
    }
    return nil
}

private func combinations<T>(of array: [T], taking k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard array.count >= k else { return [] }
    if k == 1 { return array.map { [$0] } }

    var result: [[T]] = []
    func helper(start: Int, current: [T]) {
        if current.count == k {
            result.append(current)
            return
        }
        for i in start..<array.count {
            helper(start: i + 1, current: current + [array[i]])
        }
    }
    helper(start: 0, current: [])
    return result
}

private func bitCount(_ value: Int) -> Int {
    value.nonzeroBitCount
}
