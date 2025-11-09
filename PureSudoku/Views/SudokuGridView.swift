import SwiftUI

struct SudokuGridView: View {
    let cells: [SudokuCell]
    let selectedCellID: UUID?
    let theme: ThemeColors
    var onSelect: (SudokuCell) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        let selectedCell = cells.first(where: { $0.id == selectedCellID })
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.gridBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.gridLine.opacity(0.6), lineWidth: 1.5)
                )
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(cells) { cell in
                    let isSelected = cell.id == selectedCellID
                    let isHighlighted = {
                        guard let target = selectedCell, target.id != cell.id else { return false }
                        return target.row == cell.row || target.col == cell.col
                    }()
                    Button {
                        onSelect(cell)
                    } label: {
                        SudokuCellView(cell: cell, isSelected: isSelected, isHighlighted: isHighlighted, theme: theme)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cell_\(cell.row)_\(cell.col)")
                }
            }
            .padding(4)
            gridGuides
        }
    }

    private var gridGuides: some View {
        GeometryReader { geometry in
            let length = min(geometry.size.width, geometry.size.height)
            let originX = (geometry.size.width - length) / 2
            let originY = (geometry.size.height - length) / 2
            let cellSize = length / 9
            ZStack {
                ForEach(0...9, id: \.self) { index in
                    let lineWidth: CGFloat = index % 3 == 0 ? 2 : 1
                    Path { path in
                        let offset = CGFloat(index) * cellSize
                        path.move(to: CGPoint(x: originX + offset, y: originY))
                        path.addLine(to: CGPoint(x: originX + offset, y: originY + length))
                    }
                    .stroke(theme.gridLine.opacity(index % 3 == 0 ? 0.7 : 0.25), lineWidth: lineWidth)

                    Path { path in
                        let offset = CGFloat(index) * cellSize
                        path.move(to: CGPoint(x: originX, y: originY + offset))
                        path.addLine(to: CGPoint(x: originX + length, y: originY + offset))
                    }
                    .stroke(theme.gridLine.opacity(index % 3 == 0 ? 0.7 : 0.25), lineWidth: lineWidth)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let isSelected: Bool
    let isHighlighted: Bool
    let theme: ThemeColors

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellFillColor)
            if let value = cell.value {
                Text("\(value)")
                    .font(cell.given ? .title.bold() : .title)
                    .foregroundColor(cell.given ? theme.primaryText : theme.accent)
            } else if !cell.candidates.isEmpty {
                Text(candidateString)
                    .font(.footnote)
                    .foregroundColor(theme.secondaryText)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(height: 38)
        .overlay(borderOverlay)
        .accessibilityLabel(accessibilityText)
    }

    private var candidateString: String {
        cell.candidates.sorted().map(String.init).joined(separator: " ")
    }

    private var cellFillColor: Color {
        if cell.isVerifiedCorrect {
            return theme.success.opacity(0.2)
        } else if isSelected {
            return theme.selection
        } else if isHighlighted {
            return theme.selection.opacity(0.4)
        } else {
            return theme.cardBackground
        }
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
        } else if !cell.candidates.isEmpty {
            let candidates = cell.candidates.sorted().map(String.init).joined(separator: ", ")
            return "Row \(cell.row + 1) column \(cell.col + 1) candidates \(candidates)"
        } else {
            return "Row \(cell.row + 1) column \(cell.col + 1) empty"
        }
    }
}
