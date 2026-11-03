import Foundation

/// XY-Chain (Expert tier).
enum ChainDetector {
    /// A chain of two-candidate cells, each seeing the next and sharing one digit with it. If the
    /// first cell is not X, each link forces the next cell, and the last cell becomes X. So one end
    /// is X, and a cell that sees both ends can't be. The shortest chain to each end is used.
    static func xyChains(_ board: SolverBoard) -> [TechniqueStep] {
        let bivalue = (0..<81).filter { board.values[$0] == 0 && board.candidates[$0].nonzeroBitCount == 2 }
        var steps: [TechniqueStep] = []
        for start in bivalue {
            for x in SolverBoard.digits(in: board.candidates[start]) {
                steps += chains(from: start, digit: x, bivalue: bivalue, board: board)
            }
        }
        return steps
    }

    /// Breadth-first over (cell, digit the cell must be if `start` is not `x`).
    private static func chains(from start: Int, digit x: Int, bivalue: [Int], board: SolverBoard) -> [TechniqueStep] {
        struct Node: Hashable { let cell: Int, forced: Int }
        func other(_ digit: Int, in cell: Int) -> Int { SolverBoard.digits(in: board.candidates[cell] & ~SolverBoard.bit(digit))[0] }

        let first = Node(cell: start, forced: other(x, in: start))
        var parent: [Node: Node] = [:]
        var seen: Set<Node> = [first]
        var queue = [first]
        var steps: [TechniqueStep] = []
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            for next in bivalue where next != start && SolverBoard.sees(node.cell, next) && board.has(node.forced, at: next) {
                let nextNode = Node(cell: next, forced: other(node.forced, in: next))
                guard seen.insert(nextNode).inserted else { continue }
                parent[nextNode] = node
                queue.append(nextNode)
                guard nextNode.forced == x else { continue }
                var path = [nextNode.cell]
                var walk = node
                while true {
                    path.append(walk.cell)
                    guard let up = parent[walk] else { break }
                    walk = up
                }
                path.reverse()
                // A chain that passes a cell twice is still sound, but too confusing to teach.
                guard path.count >= 3, Set(path).count == path.count else { continue }
                let removed = (0..<81).filter { cell in
                    !path.contains(cell) && board.has(x, at: cell) && SolverBoard.sees(cell, start) && SolverBoard.sees(cell, next)
                }
                guard !removed.isEmpty else { continue }
                steps.append(TechniqueStep(
                    technique: .xyChain, digits: [x], houses: [],
                    cells: path.enumerated().map { .init(cell: $1, role: $0 == 0 || $0 == path.count - 1 ? .pincer : .defining) },
                    eliminations: removed.map { CellDigit(cell: $0, digit: x) }
                ))
            }
        }
        return steps
    }
}
