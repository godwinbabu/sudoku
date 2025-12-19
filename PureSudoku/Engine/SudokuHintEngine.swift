import Foundation

enum HintTechnique: String, Codable {
    case fullHouse = "Full House"
    case nakedSingle = "Naked Single"
    case hiddenSingleRow = "Hidden Single (Row)"
    case hiddenSingleCol = "Hidden Single (Column)"
    case hiddenSingleBox = "Hidden Single (Box)"
    case lockedCandidatesPointing = "Locked Candidates (Pointing)"
    case lockedCandidatesClaiming = "Locked Candidates (Claiming)"
    case nakedPair = "Naked Pair"
    case nakedTriple = "Naked Triple"
    case nakedQuad = "Naked Quad"
    case xWing = "X-Wing"
    case yWing = "Y-Wing"
    case swordfish = "Swordfish"
    case xyChain = "XY-Chain"
    case uniqueRectangle = "Unique Rectangle"
    case medusa = "Medusa"
    case exocet = "Exocet"
    case sueDeCoq = "Sue de Coq"
    case bowmansBingo = "Bowman's Bingo"
    case invalid = "Invalid"
}

struct GeneratorHint: Equatable, Codable {
    let technique: HintTechnique
    let positions: [Int] // linear 0...80
    let digit: Int? // 0...8 represents 1...9
    let message: String
}

/// Returns a lightweight hint for the current board (no guessing; placement-only).
/// - Returns: `GeneratorHint` if a deterministic move is found; `nil` if none or board is solved.
func nextHint(for board: GeneratorBoard) -> GeneratorHint? {
    // Reject invalid positions early
    if hasContradiction(board) {
        return GeneratorHint(technique: .invalid, positions: [], digit: nil, message: "Board has a contradiction (duplicate in a row/column/box).")
    }
    guard board.contains(where: { $0 == nil }) else { return nil }

    let candidates = candidateMasks(for: board)

    if let hint = fullHouseHint(board: board) { return hint }
    if let hint = nakedSingleHint(candidates: candidates) { return hint }
    if let hint = hiddenSingleHint(candidates: candidates) { return hint }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .lockedCandidatesPointing,
        messagePrefix: "Locked Candidates (Pointing)",
        apply: { masks in
            applyLockedCandidatesPointing(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .lockedCandidatesClaiming,
        messagePrefix: "Locked Candidates (Claiming)",
        apply: { masks in
            applyLockedCandidatesClaiming(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .nakedPair,
        messagePrefix: "Naked Pair",
        apply: { masks in
            applyNakedSetElimination(size: 2, board: board, candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .nakedTriple,
        messagePrefix: "Naked Triple",
        apply: { masks in
            applyNakedSetElimination(size: 3, board: board, candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .nakedQuad,
        messagePrefix: "Naked Quad",
        apply: { masks in
            applyNakedSetElimination(size: 4, board: board, candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .xWing,
        messagePrefix: "X-Wing",
        apply: { masks in
            applyXWingElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .yWing,
        messagePrefix: "Y-Wing",
        apply: { masks in
            applyYWingElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .swordfish,
        messagePrefix: "Swordfish",
        apply: { masks in
            applySwordfishElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .xyChain,
        messagePrefix: "XY-Chain",
        apply: { masks in
            applyXYChainElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .uniqueRectangle,
        messagePrefix: "Unique Rectangle",
        apply: { masks in
            applyUniqueRectangleElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .medusa,
        messagePrefix: "Medusa",
        apply: { masks in
            applyMedusaElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .exocet,
        messagePrefix: "Exocet",
        apply: { masks in
            applyExocetElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = hintAfterElimination(
        candidates: candidates,
        technique: .sueDeCoq,
        messagePrefix: "Sue de Coq",
        apply: { masks in
            applySueDeCoqElimination(candidates: &masks)
        }
    ) {
        return hint
    }

    if let hint = bowmansBingoHint(board: board, candidates: candidates) {
        return hint
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

private func candidateMasks(for board: GeneratorBoard) -> [Int] {
    let info = figureBits(board)
    return info.allowed
}

private func fullHouseHint(board: GeneratorBoard) -> GeneratorHint? {
    for axis in 0..<3 {
        for x in 0..<9 {
            var emptyPos: Int?
            var emptyCount = 0
            var seenBits = 0
            for y in 0..<9 {
                let pos = posFor(x: x, y: y, axis: axis)
                if let value = board[pos] {
                    seenBits |= 1 << value
                } else {
                    emptyCount += 1
                    emptyPos = pos
                }
            }
            guard emptyCount == 1, let pos = emptyPos else { continue }
            let missingBits = 0x1FF ^ seenBits
            guard bitCount(missingBits) == 1, let digit = listBits(missingBits).first else { continue }
            let (r, c) = rowCol(from: pos)
            return GeneratorHint(
                technique: .fullHouse,
                positions: [pos],
                digit: digit,
                message: "Only r\(r + 1)c\(c + 1) is empty in this \(axisName(axis)); place \(digit + 1)."
            )
        }
    }
    return nil
}

private func nakedSingleHint(candidates: [Int]) -> GeneratorHint? {
    for pos in 0..<81 {
        let mask = candidates[pos]
        if bitCount(mask) == 1 {
            let digit = listBits(mask)[0]
            let (r, c) = rowCol(from: pos)
            return GeneratorHint(
                technique: .nakedSingle,
                positions: [pos],
                digit: digit,
                message: "Cell r\(r + 1)c\(c + 1) must be \(digit + 1) (naked single)."
            )
        }
    }
    return nil
}

private func hiddenSingleHint(candidates: [Int]) -> GeneratorHint? {
    for axis in 0..<3 {
        for x in 0..<9 {
            for digit in 0..<9 {
                let bit = 1 << digit
                var positions: [Int] = []
                for y in 0..<9 {
                    let pos = posFor(x: x, y: y, axis: axis)
                    if candidates[pos] & bit != 0 {
                        positions.append(pos)
                    }
                }
                if positions.count == 1 {
                    let pos = positions[0]
                    let (r, c) = rowCol(from: pos)
                    let technique: HintTechnique = axis == 0 ? .hiddenSingleRow : axis == 1 ? .hiddenSingleCol : .hiddenSingleBox
                    return GeneratorHint(
                        technique: technique,
                        positions: [pos],
                        digit: digit,
                        message: "Digit \(digit + 1) fits only at r\(r + 1)c\(c + 1) in this \(axisName(axis))."
                    )
                }
            }
        }
    }
    return nil
}

private func hintAfterElimination(
    candidates: [Int],
    technique: HintTechnique,
    messagePrefix: String,
    apply: (_ candidates: inout [Int]) -> Bool
) -> GeneratorHint? {
    var working = candidates
    let changed = apply(&working)
    guard changed else { return nil }
    if let hint = nakedSingleHint(candidates: working) {
        guard let digit = hint.digit else { return nil }
        return GeneratorHint(
            technique: technique,
            positions: hint.positions,
            digit: digit,
            message: "\(messagePrefix) reveals r\(rowCol(from: hint.positions[0]).0 + 1)c\(rowCol(from: hint.positions[0]).1 + 1) = \(digit + 1)."
        )
    }
    if let hint = hiddenSingleHint(candidates: working) {
        guard let digit = hint.digit else { return nil }
        return GeneratorHint(
            technique: technique,
            positions: hint.positions,
            digit: digit,
            message: "\(messagePrefix) reveals r\(rowCol(from: hint.positions[0]).0 + 1)c\(rowCol(from: hint.positions[0]).1 + 1) = \(digit + 1)."
        )
    }
    return nil
}

private func applyLockedCandidatesPointing(candidates: inout [Int]) -> Bool {
    var changed = false
    for box in 0..<9 {
        let boxRow = (box / 3) * 3
        let boxCol = (box % 3) * 3
        let positions = (0..<9).compactMap { idx -> Int in
            let r = boxRow + idx / 3
            let c = boxCol + idx % 3
            return r * 9 + c
        }
        for digit in 0..<9 {
            let bit = 1 << digit
            let digitPositions = positions.filter { candidates[$0] & bit != 0 }
            guard digitPositions.count >= 2 else { continue }
            let rows = Set(digitPositions.map { $0 / 9 })
            let cols = Set(digitPositions.map { $0 % 9 })
            if rows.count == 1, let row = rows.first {
                for col in 0..<9 where !(boxCol..<boxCol+3).contains(col) {
                    let pos = row * 9 + col
                    if candidates[pos] & bit != 0 {
                        candidates[pos] &= ~bit
                        changed = true
                    }
                }
            } else if cols.count == 1, let col = cols.first {
                for row in 0..<9 where !(boxRow..<boxRow+3).contains(row) {
                    let pos = row * 9 + col
                    if candidates[pos] & bit != 0 {
                        candidates[pos] &= ~bit
                        changed = true
                    }
                }
            }
        }
    }
    return changed
}

private func applyLockedCandidatesClaiming(candidates: inout [Int]) -> Bool {
    var changed = false
    for axis in 0..<2 {
        for x in 0..<9 {
            let positions = (0..<9).map { y -> Int in
                posFor(x: x, y: y, axis: axis)
            }
            for digit in 0..<9 {
                let bit = 1 << digit
                let digitPositions = positions.filter { candidates[$0] & bit != 0 }
                guard digitPositions.count >= 2 else { continue }
                let boxes = Set(digitPositions.map { ( ($0 / 27) * 3 + ($0 / 3) % 3 ) })
                guard boxes.count == 1, let box = boxes.first else { continue }
                let boxRow = (box / 3) * 3
                let boxCol = (box % 3) * 3
                for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        let pos = r * 9 + c
                        if axis == 0 && r == x { continue }
                        if axis == 1 && c == x { continue }
                        if candidates[pos] & bit != 0 {
                            candidates[pos] &= ~bit
                            changed = true
                        }
                    }
                }
            }
        }
    }
    return changed
}

private func applyNakedSetElimination(size: Int, board: GeneratorBoard, candidates: inout [Int]) -> Bool {
    var changed = false
    for axis in 0..<3 {
        for x in 0..<9 {
            let positions: [Int] = (0..<9).compactMap { y in
                let pos = posFor(x: x, y: y, axis: axis)
                return board[pos] == nil ? pos : nil
            }
            guard positions.count >= size else { continue }
            for combo in combinations(of: positions, taking: size) {
                let masks = combo.map { candidates[$0] }
                let union = masks.reduce(0, |)
                guard bitCount(union) == size else { continue }
                guard masks.allSatisfy({ ($0 & ~union) == 0 && bitCount($0) <= size }) else { continue }
                let others = positions.filter { !combo.contains($0) }
                for pos in others {
                    let before = candidates[pos]
                    let after = before & ~union
                    if after != before {
                        candidates[pos] = after
                        changed = true
                    }
                }
            }
        }
    }
    return changed
}

private func applyXWingElimination(candidates: inout [Int]) -> Bool {
    var changed = false
    for digit in 0..<9 {
        let bit = 1 << digit
        var rowCandidates: [(row: Int, cols: [Int])] = []
        for row in 0..<9 {
            let cols = (0..<9).filter { col in
                candidates[row * 9 + col] & bit != 0
            }
            if cols.count == 2 {
                rowCandidates.append((row, cols))
            }
        }
        for combo in combinations(of: rowCandidates, taking: 2) {
            guard combo.count == 2 else { continue }
            let cols1 = combo[0].cols
            let cols2 = combo[1].cols
            guard cols1 == cols2 else { continue }
            for row in 0..<9 where row != combo[0].row && row != combo[1].row {
                for col in cols1 {
                    let pos = row * 9 + col
                    if candidates[pos] & bit != 0 {
                        candidates[pos] &= ~bit
                        changed = true
                    }
                }
            }
        }

        var colCandidates: [(col: Int, rows: [Int])] = []
        for col in 0..<9 {
            let rows = (0..<9).filter { row in
                candidates[row * 9 + col] & bit != 0
            }
            if rows.count == 2 {
                colCandidates.append((col, rows))
            }
        }
        for combo in combinations(of: colCandidates, taking: 2) {
            guard combo.count == 2 else { continue }
            let rows1 = combo[0].rows
            let rows2 = combo[1].rows
            guard rows1 == rows2 else { continue }
            for col in 0..<9 where col != combo[0].col && col != combo[1].col {
                for row in rows1 {
                    let pos = row * 9 + col
                    if candidates[pos] & bit != 0 {
                        candidates[pos] &= ~bit
                        changed = true
                    }
                }
            }
        }
    }
    return changed
}

private func applyYWingElimination(candidates: inout [Int]) -> Bool {
    var changed = false
    let peers = peerMap()
    for pivot in 0..<81 {
        let pivotMask = candidates[pivot]
        guard bitCount(pivotMask) == 2 else { continue }
        let pivotDigits = listBits(pivotMask)
        let a = pivotDigits[0]
        let b = pivotDigits[1]
        let pivotPeers = peers[pivot]

        let pincerA = pivotPeers.filter { pos in
            bitCount(candidates[pos]) == 2 && candidates[pos] & (1 << a) != 0
        }
        let pincerB = pivotPeers.filter { pos in
            bitCount(candidates[pos]) == 2 && candidates[pos] & (1 << b) != 0
        }

        for p1 in pincerA {
            let digits1 = listBits(candidates[p1])
            guard digits1.contains(a) else { continue }
            let c = digits1.first { $0 != a }
            guard let c else { continue }
            for p2 in pincerB where p2 != p1 {
                let digits2 = listBits(candidates[p2])
                guard digits2.contains(b), digits2.contains(c) else { continue }
                for target in peers[p1].intersection(peers[p2]) where target != pivot {
                    let bit = 1 << c
                    if candidates[target] & bit != 0 {
                        candidates[target] &= ~bit
                        changed = true
                    }
                }
            }
        }
    }
    return changed
}

private func applySwordfishElimination(candidates: inout [Int]) -> Bool {
    var changed = false
    for digit in 0..<9 {
        let bit = 1 << digit
        var rowMap: [(row: Int, cols: [Int])] = []
        for row in 0..<9 {
            let cols = (0..<9).filter { col in candidates[row * 9 + col] & bit != 0 }
            if (2...3).contains(cols.count) {
                rowMap.append((row, cols))
            }
        }
        for combo in combinations(of: rowMap, taking: 3) {
            let unionCols = Set(combo.flatMap { $0.cols })
            guard unionCols.count == 3 else { continue }
            for row in 0..<9 where !combo.contains(where: { $0.row == row }) {
                for col in unionCols {
                    let pos = row * 9 + col
                    if candidates[pos] & bit != 0 {
                        candidates[pos] &= ~bit
                        changed = true
                    }
                }
            }
        }

        var colMap: [(col: Int, rows: [Int])] = []
        for col in 0..<9 {
            let rows = (0..<9).filter { row in candidates[row * 9 + col] & bit != 0 }
            if (2...3).contains(rows.count) {
                colMap.append((col, rows))
            }
        }
        for combo in combinations(of: colMap, taking: 3) {
            let unionRows = Set(combo.flatMap { $0.rows })
            guard unionRows.count == 3 else { continue }
            for col in 0..<9 where !combo.contains(where: { $0.col == col }) {
                for row in unionRows {
                    let pos = row * 9 + col
                    if candidates[pos] & bit != 0 {
                        candidates[pos] &= ~bit
                        changed = true
                    }
                }
            }
        }
    }
    return changed
}

private func applyXYChainElimination(candidates: inout [Int]) -> Bool {
    let peers = peerMap()
    var changed = false
    let bivalueCells = (0..<81).filter { bitCount(candidates[$0]) == 2 }

    func dfs(start: Int, startDigit: Int, current: Int, currentDigit: Int, depth: Int, visited: inout Set<Int>) {
        guard depth < 6 else { return }
        for next in bivalueCells where next != current && peers[current].contains(next) {
            let mask = candidates[next]
            guard mask & (1 << currentDigit) != 0 else { continue }
            let digits = listBits(mask)
            guard digits.count == 2 else { continue }
            let nextDigit = digits.first { $0 != currentDigit } ?? currentDigit
            if next == start && nextDigit == startDigit {
                continue
            }
            if peers[start].contains(next) && nextDigit == startDigit {
                let bit = 1 << startDigit
                for target in peers[start].intersection(peers[next]) {
                    if candidates[target] & bit != 0 {
                        candidates[target] &= ~bit
                        changed = true
                    }
                }
            }
            if visited.insert(next).inserted {
                dfs(start: start, startDigit: startDigit, current: next, currentDigit: nextDigit, depth: depth + 1, visited: &visited)
                visited.remove(next)
            }
        }
    }

    for start in bivalueCells {
        let digits = listBits(candidates[start])
        guard digits.count == 2 else { continue }
        for startDigit in digits {
            var visited: Set<Int> = [start]
            dfs(start: start, startDigit: startDigit, current: start, currentDigit: digits.first { $0 != startDigit } ?? startDigit, depth: 0, visited: &visited)
            if changed { return true }
        }
    }
    return changed
}

private func applyUniqueRectangleElimination(candidates: inout [Int]) -> Bool {
    var changed = false
    for r1 in 0..<8 {
        for r2 in (r1 + 1)..<9 {
            for c1 in 0..<8 {
                for c2 in (c1 + 1)..<9 {
                    let p11 = r1 * 9 + c1
                    let p12 = r1 * 9 + c2
                    let p21 = r2 * 9 + c1
                    let p22 = r2 * 9 + c2
                    let rect = [p11, p12, p21, p22]
                    let masks = rect.map { candidates[$0] }
                    let bivalueIndices = rect.indices.filter { bitCount(masks[$0]) == 2 }
                    guard bivalueIndices.count == 2 else { continue }
                    let pairMask = masks[bivalueIndices[0]]
                    guard masks[bivalueIndices[1]] == pairMask else { continue }
                    for idx in rect.indices where !bivalueIndices.contains(idx) {
                        let pos = rect[idx]
                        if candidates[pos] & pairMask == pairMask {
                            let before = candidates[pos]
                            let after = before & pairMask
                            if after != before {
                                candidates[pos] = after
                                changed = true
                            }
                        }
                    }
                }
            }
        }
    }
    return changed
}

private func applyMedusaElimination(candidates: inout [Int]) -> Bool {
    let peers = peerMap()
    var changed = false
    for digit in 0..<9 {
        let bit = 1 << digit
        var strongLinks: [Int: Set<Int>] = [:]
        for axis in 0..<3 {
            for x in 0..<9 {
                let positions = (0..<9).map { y -> Int in posFor(x: x, y: y, axis: axis) }
                let candidatesInUnit = positions.filter { candidates[$0] & bit != 0 }
                if candidatesInUnit.count == 2 {
                    strongLinks[candidatesInUnit[0], default: []].insert(candidatesInUnit[1])
                    strongLinks[candidatesInUnit[1], default: []].insert(candidatesInUnit[0])
                }
            }
        }

        var color: [Int: Int] = [:]
        for start in strongLinks.keys where color[start] == nil {
            var queue: [Int] = [start]
            color[start] = 0
            while let current = queue.popLast() {
                for next in strongLinks[current] ?? [] {
                    if color[next] == nil {
                        color[next] = 1 - (color[current] ?? 0)
                        queue.append(next)
                    }
                }
            }
        }

        // Rule 1: same color in a unit -> remove all of that color for the digit
        for axis in 0..<3 {
            for x in 0..<9 {
                let positions = (0..<9).map { y -> Int in posFor(x: x, y: y, axis: axis) }
                for colorValue in [0, 1] {
                    let colored = positions.filter { color[$0] == colorValue }
                    if colored.count >= 2 {
                        for pos in color.keys where color[pos] == colorValue {
                            if candidates[pos] & bit != 0 {
                                candidates[pos] &= ~bit
                                changed = true
                            }
                        }
                    }
                }
            }
        }

        // Rule 2: any cell that sees both colors cannot contain the digit
        let coloredByColor: [[Int]] = [
            color.compactMap { $0.value == 0 ? $0.key : nil },
            color.compactMap { $0.value == 1 ? $0.key : nil }
        ]
        for pos in 0..<81 where candidates[pos] & bit != 0 && color[pos] == nil {
            let seesColor0 = coloredByColor[0].contains { peers[pos].contains($0) }
            let seesColor1 = coloredByColor[1].contains { peers[pos].contains($0) }
            if seesColor0 && seesColor1 {
                candidates[pos] &= ~bit
                changed = true
            }
        }
    }
    return changed
}

private func applyExocetElimination(candidates: inout [Int]) -> Bool {
    // Placeholder for full Exocet detection; currently no-op.
    return false
}

private func applySueDeCoqElimination(candidates: inout [Int]) -> Bool {
    // Placeholder for full Sue de Coq detection; currently no-op.
    return false
}

private func peerMap() -> [Set<Int>] {
    var peers: [Set<Int>] = Array(repeating: Set<Int>(), count: 81)
    for pos in 0..<81 {
        let row = pos / 9
        let col = pos % 9
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        var set: Set<Int> = []
        for c in 0..<9 where c != col { set.insert(row * 9 + c) }
        for r in 0..<9 where r != row { set.insert(r * 9 + col) }
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                let p = r * 9 + c
                if p != pos { set.insert(p) }
            }
        }
        peers[pos] = set
    }
    return peers
}

private func bowmansBingoHint(board: GeneratorBoard, candidates: [Int]) -> GeneratorHint? {
    let empties = (0..<81).filter { board[$0] == nil }
    guard !empties.isEmpty else { return nil }
    let sorted = empties.sorted { bitCount(candidates[$0]) < bitCount(candidates[$1]) }
    let target = sorted.first ?? empties[0]
    let options = listBits(candidates[target])
    guard options.count >= 2 else { return nil }

    for digit in options {
        var trial = board
        trial[target] = digit
        if solvePuzzle(trial) == nil {
            // This digit is impossible; the other candidate(s) must be true.
            let remaining = options.filter { $0 != digit }
            if remaining.count == 1 {
                let (r, c) = rowCol(from: target)
                return GeneratorHint(
                    technique: .bowmansBingo,
                    positions: [target],
                    digit: remaining[0],
                    message: "Trial shows r\(r + 1)c\(c + 1) cannot be \(digit + 1); place \(remaining[0] + 1)."
                )
            }
        }
    }
    return nil
}

#if DEBUG
func _applyXYChainElimination(candidates: inout [Int]) -> Bool {
    applyXYChainElimination(candidates: &candidates)
}

func _applyUniqueRectangleElimination(candidates: inout [Int]) -> Bool {
    applyUniqueRectangleElimination(candidates: &candidates)
}

func _applyMedusaElimination(candidates: inout [Int]) -> Bool {
    applyMedusaElimination(candidates: &candidates)
}

func _bowmansBingoHint(board: GeneratorBoard, candidates: [Int]) -> GeneratorHint? {
    bowmansBingoHint(board: board, candidates: candidates)
}
#endif

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
