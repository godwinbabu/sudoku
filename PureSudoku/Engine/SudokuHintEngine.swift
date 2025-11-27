import Foundation

enum HintTechnique: String, Codable {
    case nakedSingle = "Naked Single"
    case hiddenSingleRow = "Hidden Single (Row)"
    case hiddenSingleCol = "Hidden Single (Column)"
    case hiddenSingleBox = "Hidden Single (Box)"
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
