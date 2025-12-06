import SwiftUI

struct SudokuGridView: View {
    let cells: [SudokuCell]
    let selectedCellID: UUID?
    let theme: ThemeColors
    var candidateOverlay: [UUID: Set<Int>] = [:]
    var onSelect: (SudokuCell) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        let selectedCell = cells.first(where: { $0.id == selectedCellID })
        let selectedValue = selectedCell?.value
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.gridBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.gridLine.opacity(0.6), lineWidth: 2)
                )
            GeometryReader { geometry in
                let rawLength = min(geometry.size.width, geometry.size.height)
                let scale = UIScreen.main.scale
                let length = floor(rawLength * scale) / scale
                let cellSide = floor((length / 9) * scale) / scale
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(cells) { cell in
                        let isSelected = cell.id == selectedCellID
                        let isHighlighted = {
                            guard let target = selectedCell, target.id != cell.id else { return false }
                            return target.row == cell.row || target.col == cell.col
                        }()
                        let isNumberMatch: Bool = {
                            guard let value = selectedValue, !isSelected else { return false }
                            return cell.value == value
                        }()
                        let displayCandidates = displayCandidates(for: cell)
                        Button {
                            onSelect(cell)
                        } label: {
                            SudokuCellView(
                                cell: cell,
                                displayCandidates: displayCandidates,
                                isSelected: isSelected,
                                isHighlighted: isHighlighted,
                                isNumberMatch: isNumberMatch,
                                theme: theme,
                                cellSize: cellSide
                            )
                                .frame(height: cellSide)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cell_\(cell.row)_\(cell.col)")
                    }
                }
                .frame(width: cellSide * 9, height: cellSide * 9)
                .padding(4)
            }
            gridGuides
        }
    }

    private var gridGuides: some View {
        GeometryReader { geometry in
            let rawLength = min(geometry.size.width, geometry.size.height)
            let scale = UIScreen.main.scale
            let length = floor(rawLength * scale) / scale
            let cellSize = floor((length / 9) * scale) / scale
            let gridLength = cellSize * 9
            let originX = (geometry.size.width - gridLength) / 2
            let originY = (geometry.size.height - gridLength) / 2
            ZStack {
                ForEach(0...9, id: \.self) { index in
                    let lineWidth: CGFloat = index % 3 == 0 ? 3.2 : 1.2
                    Path { path in
                        let offset = CGFloat(index) * cellSize
                        path.move(to: CGPoint(x: originX + offset, y: originY))
                        path.addLine(to: CGPoint(x: originX + offset, y: originY + length))
                    }
                    .stroke(theme.gridLine.opacity(index % 3 == 0 ? 0.9 : 0.45), lineWidth: lineWidth)

                    Path { path in
                        let offset = CGFloat(index) * cellSize
                        path.move(to: CGPoint(x: originX, y: originY + offset))
                        path.addLine(to: CGPoint(x: originX + length, y: originY + offset))
                    }
                    .stroke(theme.gridLine.opacity(index % 3 == 0 ? 0.9 : 0.45), lineWidth: lineWidth)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func displayCandidates(for cell: SudokuCell) -> Set<Int> {
        guard let overlay = candidateOverlay[cell.id] else {
            return cell.candidates
        }
        return cell.candidates.union(overlay)
    }
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let displayCandidates: Set<Int>
    let isSelected: Bool
    let isHighlighted: Bool
    let isNumberMatch: Bool
    let theme: ThemeColors
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellFillColor)
            if let value = cell.value {
                Text("\(value)")
                    .font(cell.given ? .title.bold() : .title)
                    .foregroundColor(cell.given ? theme.primaryText : theme.accent)
            } else if !displayCandidates.isEmpty {
                candidateGrid
            }
        }
        .frame(height: cellSize)
        .overlay(borderOverlay)
        .accessibilityLabel(accessibilityText)
    }

    private var cellFillColor: Color {
        if cell.isVerifiedCorrect {
            return theme.success.opacity(0.2)
        } else if isSelected {
            return theme.selection
        } else if isNumberMatch {
            return theme.sameNumberHighlight
        } else if isHighlighted {
            return theme.selection.opacity(0.4)
        } else {
            return theme.cardBackground
        }
    }

    @ViewBuilder
    private var candidateGrid: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ForEach(displayCandidates.sorted(), id: \.self) { number in
                let position = candidatePosition(for: number, in: size)
                Text("\(number)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.secondaryText)
                    .position(position)
            }
        }
        .allowsHitTesting(false)
    }

    private func candidatePosition(for number: Int, in size: CGSize) -> CGPoint {
        let safeNumber = min(max(number, 1), 9)
        let row = CGFloat((safeNumber - 1) / 3)
        let col = CGFloat((safeNumber - 1) % 3)
        let inset = min(size.width, size.height) * 0.08
        let availableWidth = size.width - inset * 2
        let availableHeight = size.height - inset * 2
        let cellWidth = availableWidth / 3
        let cellHeight = availableHeight / 3
        let bias = min(size.width, size.height) * 0.01
        return CGPoint(
            x: inset + col * cellWidth + cellWidth / 2 - bias,
            y: inset + row * cellHeight + cellHeight / 2 - bias
        )
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if cell.isError || cell.isVerifiedCorrect || isSelected {
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: cell.isError ? 2 : 1.5)
        }
    }

    private var borderColor: Color {
        if cell.isError { return theme.error }
        if cell.isVerifiedCorrect { return theme.success }
        return theme.selection
    }

    private var accessibilityText: String {
        if let value = cell.value {
            return "Row \(cell.row + 1) column \(cell.col + 1) value \(value)"
        } else if !displayCandidates.isEmpty {
            let candidates = displayCandidates.sorted().map(String.init).joined(separator: ", ")
            return "Row \(cell.row + 1) column \(cell.col + 1) candidates \(candidates)"
        } else {
            return "Row \(cell.row + 1) column \(cell.col + 1) empty"
        }
    }
}
