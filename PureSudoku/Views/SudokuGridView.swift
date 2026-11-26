import SwiftUI

/// The board (HANDOFF 6.2): cells on `surface` with 12 pt corners and a 1 pt `edge` outline; `line`
/// between cells and `lineMajor` between boxes, no outer frame. Line widths follow Clarity; every state
/// shows by shape or weight, never hue alone.
struct SudokuGridView: View {
    let cells: [SudokuCell]
    let selectedCellID: UUID?
    let theme: PSPalette
    /// Open hint's marks (CODESPEC 7.3).
    var highlight = HintHighlight()
    /// VoiceOver value for ringed (evidence) cells, e.g. "Unsure" on Check the grid. Nil reads "proof".
    var ringedCellValue: String?
    /// Fades cells outside an open hint's cells (lessons). The game keeps every cell at full strength.
    var dimsOutsideFocus = true
    var onSelect: (SudokuCell) -> Void

    @Environment(\.psType) private var type
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What VoiceOver adds after the cell's label: given, mistake, a hard-to-read import digit, and the
    /// hint rings ("hint target", "proof"). The label itself stays "Row r column c value N" (UI tests rely on it).
    static func stateText(_ cell: SudokuCell, ringed: String?, isTarget: Bool = false) -> String {
        var parts: [String] = []
        if cell.given { parts.append("given") }
        if cell.isError { parts.append("mistake") }
        if let ringed { parts.append(ringed) }
        if isTarget { parts.append("hint target") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        GeometryReader { geometry in
            let box = type.boxLine, minor = type.minorLine
            // Whole pixels, so every line lands on the same pixel row across the board.
            let raw = (min(geometry.size.width, geometry.size.height) - 2 * box - 6 * minor) / 9
            let cellSide = (raw * displayScale).rounded(.down) / displayScale
            let side = 9 * cellSide + 6 * minor + 2 * box
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
            .background(theme.lineMajor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.edge, lineWidth: 1))
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
                            .accessibilityValue(Self.stateText(cell, ringed: ringedText(index), isTarget: isTarget(index)))
                            .accessibilityAddTraits(cell.id == layout.selected?.id ? .isSelected : [])
                            // Import review only: hint proof rings are not something to confirm.
                            .accessibilityHint(ringedCellValue != nil && ringedText(index) != nil
                                               ? "Hard to read. Double-tap to confirm." : "")
                        }
                    }
                }
            }
        }
        .background(theme.line)
    }

    private func isTarget(_ index: Int) -> Bool {
        highlight.ghostDigits[index] != nil || highlight.targetCells.contains(index)
    }

    private func ringedText(_ index: Int) -> String? {
        highlight.evidenceCells.contains(index) ? (ringedCellValue ?? "proof") : nil
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
        state.inFocus = !dimsOutsideFocus || !marks.spotlight || marks.focus.contains(cell.index)
        state.isUnit = highlight.areaCells.contains(cell.index)
        state.isPattern = highlight.patternCells.contains(cell.index)
        state.isEvidence = highlight.evidenceCells.contains(cell.index)
        state.isTarget = highlight.ghostDigits[cell.index] != nil || highlight.targetCells.contains(cell.index)
        state.isRuledOut = highlight.struckDigits[cell.index] != nil
        return state
    }
}

/// The spotlight: in a lesson, digits outside the hint's cells step back to ink2 at 500.
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
    /// In the unit an open hint is about (focus tint).
    var isUnit = false
    var isEvidence = false
    var isTarget = false
    var isRuledOut = false

    /// At Night a same-digit cell is also ringed, so it shows by shape; the selection and hint rings win.
    func showsSameDigitRing(enabled: Bool) -> Bool {
        enabled && isSameDigit && !isSelected && !isEvidence && !isTarget
    }
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
            if state.showsSameDigitRing(enabled: theme.ringsSameDigit) {
                // Thinner and squarer, so it never reads as the selection ring (CODESPEC 7.3).
                RoundedRectangle(cornerRadius: 4).strokeBorder(theme.accent, lineWidth: 1.5).padding(3)
            }
            // Selection and proof: a 2 pt solid ring; the hint target: dashed (HANDOFF 6.2).
            if state.isSelected || state.isEvidence { ring(dashed: false) }
            if state.isTarget { ring(dashed: true) }
            if state.isRuledOut {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.ink3, style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                    .padding(4)
            }
            content
        }
        .frame(width: side, height: side)
        .background(fill)
        .background(theme.surface)
        .clipped()
        .contentShape(Rectangle())
        // One element: otherwise each of the nine note slots carries the label (issue #58).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func ring(dashed: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9)
            .strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
            .padding(3)
    }

    /// Light and Dark mark the selection's row, column and box and a hint's unit with the `focus` tint,
    /// and the selected digit elsewhere with `same` (owner's choice, after v3). Night keeps its stepped
    /// fills (sel > same > peer), which read where hue can't.
    private var fill: Color {
        if theme.isNight {
            if state.isPattern { return theme.same }
            if state.isSelected { return theme.sel }
            if state.isSameDigit { return theme.same }
            if state.isPeer { return theme.peer }
            if state.isUnit { return theme.focus }
            return .clear
        }
        if state.isSameDigit { return theme.same }
        return state.isPattern || state.isUnit || state.isSelected || state.isPeer ? theme.focus : .clear
    }

    @ViewBuilder
    private var content: some View {
        // Digit ≈ 0.62 × cell (HANDOFF 4); givens and the selected digit 800, entries 500.
        let digitSize = side * 0.62 * type.digitScale
        if let value = cell.value {
            // Outside a lesson's spotlight digits step back to ink2 at 500 (HANDOFF 6.6), never faded.
            let heavy = state.inFocus && (cell.given || value == state.selectedDigit)
            Text("\(value)")
                .font(PSFont.fixed(digitSize, weight: heavy ? .heavy : type.userWeight).monospacedDigit())
                .foregroundStyle(cell.isError ? theme.err : !state.inFocus ? theme.ink2 : cell.given ? theme.ink : theme.accent)
                .overlay(alignment: .bottom) {
                    // A mistake also gets a bar under the digit, so it never depends on hue (CODESPEC 7.2).
                    if cell.isError {
                        GeometryReader { proxy in
                            // In ink at night: err and accent are nearly the same there (QA #29).
                            Capsule().fill(theme.isNight ? theme.ink : theme.err)
                                .frame(width: proxy.size.width * 1.2, height: 3)
                                .position(x: proxy.size.width / 2, y: proxy.size.height + side * 0.04)
                        }
                        .accessibilityHidden(true)
                    }
                }
        } else if let ghost = hint.ghost {
            // The answer at the Why step: accent, 800, inside the dashed ring.
            Text("\(ghost)")
                .font(PSFont.fixed(digitSize, weight: .heavy).monospacedDigit())
                .foregroundStyle(theme.accent)
                .accessibilityIdentifier("hintGhost")
        } else if !hint.candidates(cell).isEmpty {
            notes
        }
    }

    /// A 3×3 mini grid inset 3 pt top and bottom, 4 pt left and right; each digit keeps its place
    /// (1 top-left … 9 bottom-right). Notes matching the selected digit go bold.
    private var notes: some View {
        let shown = hint.candidates(cell)
        let size = side * 0.24 * type.candidateScale
        let slotWidth = (side - 8) / 3, slotHeight = (side - 6) / 3
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { c in
                        let digit = r * 3 + c
                        let isKey = hint.ringed.contains(digit)
                        let isStruck = hint.struck.contains(digit)
                        let bold = isKey || state.selectedDigit == digit
                        Text(shown.contains(digit) ? "\(digit)" : " ")
                            .font(PSFont.fixed(size, weight: bold ? .bold : .semibold, display: false).monospacedDigit())
                            .strikethrough(isStruck, color: theme.err)
                            .foregroundStyle(isKey ? theme.accent : isStruck ? theme.ink3 : theme.ink2)
                            .frame(width: slotWidth, height: slotHeight)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
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
