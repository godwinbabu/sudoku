import SwiftUI

/// The board: 3×3 boxes on a `lineMajor` ground, each 3×3 cells on a `line` ground (CODESPEC 7.2).
/// Line widths follow Clarity; every state shows by shape or weight, never hue alone.
struct SudokuGridView: View {
    let cells: [SudokuCell]
    let selectedCellID: UUID?
    let theme: PSPalette
    /// Open hint's marks (CODESPEC 7.3).
    var highlight = HintHighlight()
    /// VoiceOver value for ringed (evidence) cells, e.g. "Unsure" on Check the grid. Nil reads nothing extra.
    var ringedCellValue: String?
    var onSelect: (SudokuCell) -> Void

    @Environment(\.psType) private var type
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What VoiceOver adds after the cell's label: given, mistake, and a hard-to-read import digit.
    /// The label itself stays "Row r column c value N" (UI tests rely on it).
    static func stateText(_ cell: SudokuCell, ringed: String?) -> String {
        var parts: [String] = []
        if cell.given { parts.append("given") }
        if cell.isError { parts.append("mistake") }
        if let ringed { parts.append(ringed) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        GeometryReader { geometry in
            let box = type.boxLine, minor = type.minorLine
            // Whole pixels, so every line lands on the same pixel row across the board.
            let raw = (min(geometry.size.width, geometry.size.height) - 4 * box - 6 * minor) / 9
            let cellSide = (raw * displayScale).rounded(.down) / displayScale
            let side = 9 * cellSide + 6 * minor + 4 * box
            let selected = cells.first { $0.id == selectedCellID }
            let marks = BoardMarks(highlight)
            VStack(spacing: box) {
                ForEach(0..<3, id: \.self) { boxRow in
                    HStack(spacing: box) {
                        ForEach(0..<3, id: \.self) { boxCol in
                            let layout = BoxLayout(minor: minor, cellSide: cellSide, selected: selected, marks: marks)
                            boxView(boxRow * 3 + boxCol, layout: layout)
                        }
                    }
                }
            }
            .padding(box)
            .background(theme.lineMajor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: highlight)
    }

    private struct BoxLayout {
        let minor: CGFloat
        let cellSide: CGFloat
        let selected: SudokuCell?
        let marks: BoardMarks
    }

    private func boxView(_ box: Int, layout: BoxLayout) -> some View {
        let boxRow = box / 3, boxCol = box % 3, minor = layout.minor
        return VStack(spacing: minor) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: minor) {
                    ForEach(0..<3, id: \.self) { c in
                        let index = (boxRow * 3 + r) * 9 + boxCol * 3 + c
                        if cells.indices.contains(index) {
                            let cell = cells[index]
                            Button { onSelect(cell) } label: {
                                SudokuCellView(cell: cell, state: state(of: cell, selected: layout.selected, marks: layout.marks),
                                               hint: CellHintMark(highlight, cell: index), theme: theme, side: layout.cellSide)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("cell_\(cell.row)_\(cell.col)")
                            .accessibilityValue(Self.stateText(cell, ringed: ringedText(index)))
                            .accessibilityAddTraits(cell.id == layout.selected?.id ? .isSelected : [])
                            .accessibilityHint(ringedText(index) == nil ? "" : "Hard to read. Double-tap to confirm.")
                        }
                    }
                }
            }
        }
        .background(theme.line)
    }

    private func ringedText(_ index: Int) -> String? {
        highlight.evidenceCells.contains(index) ? ringedCellValue : nil
    }

    private func state(of cell: SudokuCell, selected: SudokuCell?, marks: BoardMarks) -> CellState {
        var state = CellState()
        state.isSelected = cell.id == selected?.id
        if let selected, !state.isSelected {
            let seesSelected = cell.row == selected.row || cell.col == selected.col
                || (cell.row / 3 == selected.row / 3 && cell.col / 3 == selected.col / 3)
            state.isPeer = seesSelected && !marks.spotlight
            state.isSameDigit = selected.value != nil && cell.value == selected.value
        }
        state.selectedDigit = selected?.value
        state.inFocus = !marks.spotlight || marks.focus.contains(cell.index)
        state.isPattern = highlight.patternCells.contains(cell.index)
        state.isEvidence = highlight.evidenceCells.contains(cell.index)
        state.isTarget = highlight.ghostDigits[cell.index] != nil || highlight.targetCells.contains(cell.index)
        state.isRuledOut = highlight.struckDigits[cell.index] != nil
        return state
    }
}

/// The spotlight: with a hint open, everything outside its cells fades to `focusDim`.
private struct BoardMarks {
    let focus: Set<Int>
    var spotlight: Bool { !focus.isEmpty }

    init(_ highlight: HintHighlight) {
        focus = highlight.areaCells.union(highlight.patternCells).union(highlight.evidenceCells)
            .union(highlight.ghostDigits.keys).union(highlight.struckDigits.keys).union(highlight.targetCells)
    }
}

struct CellState: Equatable {
    var isSelected = false
    var isPeer = false
    var isSameDigit = false
    var selectedDigit: Int?
    var inFocus = true
    var isPattern = false
    var isEvidence = false
    var isTarget = false
    var isRuledOut = false
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let state: CellState
    var hint = CellHintMark()
    let theme: PSPalette
    let side: CGFloat

    @Environment(\.psType) private var type

    var body: some View {
        ZStack {
            if state.isSelected { Rectangle().strokeBorder(theme.accent, lineWidth: 2) }
            if state.isEvidence { Rectangle().strokeBorder(theme.accent, lineWidth: 1.5) }
            if state.isTarget {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .padding(3)
            }
            if state.isRuledOut {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(theme.ink3, style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                    .padding(4)
            }
            content.opacity(state.inFocus ? 1 : theme.focusDim)
        }
        .frame(width: side, height: side)
        .background(fill)
        .clipped()
        .contentShape(Rectangle())
        // One element: otherwise each of the nine note slots carries the label (issue #58).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var fill: Color {
        if state.isPattern { return theme.same }
        if state.isSelected { return theme.sel }
        if state.isSameDigit { return theme.same }
        if state.isPeer { return theme.peer }
        return theme.bg
    }

    @ViewBuilder
    private var content: some View {
        let digitSize = side * 0.6 * type.digitScale
        if let value = cell.value {
            Text("\(value)")
                .font(.system(size: digitSize, weight: cell.given ? type.givenWeight(night: theme.isNight) : type.userWeight)
                    .monospacedDigit())
                .foregroundColor(cell.isError ? theme.err : cell.given ? theme.ink : theme.accent)
                .overlay(alignment: .bottom) {
                    // A mistake also gets a bar under the digit, so it never depends on hue (CODESPEC 7.2).
                    if cell.isError {
                        GeometryReader { proxy in
                            // In ink at night: err and accent are nearly the same there (QA #29).
                            Capsule().fill(theme.isNight ? theme.ink : theme.err)
                                .frame(width: proxy.size.width * 1.2, height: 3)
                                .position(x: proxy.size.width / 2, y: proxy.size.height + side * 0.06)
                        }
                        .accessibilityHidden(true)
                    }
                }
        } else if let ghost = hint.ghost {
            Text("\(ghost)")
                .font(.system(size: digitSize, weight: type.userWeight).monospacedDigit())
                .foregroundColor(theme.accent.opacity(theme.isNight ? 0.75 : 0.55))
                .accessibilityIdentifier("hintGhost")
        } else if !hint.candidates(cell).isEmpty {
            notes
        }
    }

    private var notes: some View {
        let shown = hint.candidates(cell)
        let size = side * 0.25 * type.candidateScale
        let pad = side * 0.06, slot = (side - 2 * pad) / 3
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { c in
                        let digit = r * 3 + c
                        let isKey = hint.ringed.contains(digit) || state.selectedDigit == digit
                        let isStruck = hint.struck.contains(digit)
                        Text(shown.contains(digit) ? "\(digit)" : " ")
                            .font(.system(size: size, weight: isKey ? .bold : .medium).monospacedDigit())
                            .strikethrough(isStruck, color: theme.err)
                            .foregroundColor(isKey ? theme.accent : isStruck ? theme.ink3 : theme.ink2)
                            .frame(width: slot, height: slot)
                    }
                }
            }
        }
    }

    private var accessibilityText: String {
        let name = "Row \(cell.row + 1) column \(cell.col + 1)"
        if let value = cell.value { return "\(name) value \(value)" }
        let shown = hint.candidates(cell)
        if !shown.isEmpty { return "\(name) candidates \(shown.sorted().map(String.init).joined(separator: ", "))" }
        return "\(name) empty"
    }
}

/// One cell's share of an open hint's highlight.
struct CellHintMark: Equatable {
    var ringed: Set<Int> = []
    var struck: Set<Int> = []
    var shown: Set<Int>?
    var ghost: Int?

    init() {}

    init(_ highlight: HintHighlight, cell: Int) {
        ringed = highlight.ringedDigits[cell] ?? []
        struck = highlight.struckDigits[cell] ?? []
        shown = highlight.shownCandidates[cell]
        ghost = highlight.ghostDigits[cell]
    }

    /// The player's notes; a hint shows the candidates it reasons about in cells without notes.
    func candidates(_ cell: SudokuCell) -> Set<Int> {
        cell.candidates.isEmpty ? (shown ?? []) : cell.candidates
    }
}
