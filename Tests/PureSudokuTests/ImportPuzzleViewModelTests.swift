import XCTest
import UIKit
@testable import PureSudoku

@MainActor
final class ImportPuzzleViewModelTests: XCTestCase {
    func testConflictsDetectedInRow() {
        let viewModel = makeViewModel()
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        viewModel.selectedIndex = 1
        viewModel.setDigit(5)

        XCTAssertTrue(viewModel.conflictIndices.contains(0))
        XCTAssertTrue(viewModel.conflictIndices.contains(1))
        XCTAssertFalse(viewModel.canStart)
    }

    func testSolvableStateUpdates() async throws {
        let viewModel = makeViewModel()
        let values = TestData.puzzle.initialGrid.map { char -> Int? in
            guard let value = Int(String(char)), value > 0 else { return nil }
            return value
        }
        viewModel.loadGrid(values)

        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(viewModel.solvableState, .solvable)
    }

    /// A solve that finishes after a newer grid's solve never overwrites the newer result (issue 73).
    func testStaleSolveResultIsDropped() async throws {
        let gate = Gate<Int>()
        let viewModel = ImportPuzzleViewModel(
            countSolutions: { _ in await gate.wait() }, createGame: { _, _, _ in nil }, saveImage: { _ in nil }, deleteImage: { _ in }
        )
        viewModel.loadGrid(Self.givens)
        await waitUntil { gate.pending.count == 1 }
        var edited = Self.givens
        edited[try XCTUnwrap(edited.firstIndex { $0 != nil })] = nil
        viewModel.loadGrid(edited)
        await waitUntil { gate.pending.count == 2 }
        XCTAssertEqual(viewModel.solvableState, .unknown, "Checking until the current grid's result arrives")

        gate.finish(1, with: 0) // the newer grid
        await waitUntil { viewModel.solvableState != .unknown }
        XCTAssertEqual(viewModel.solvableState, .unsolvable)
        gate.finish(0, with: 1) // the older grid, late
        for _ in 0..<5 { await Task.yield() }
        XCTAssertEqual(viewModel.solvableState, .unsolvable)
    }

    /// An edit while Start builds the game makes the build stale; no game comes back (issue 73).
    func testEditDuringStartDropsTheGame() async throws {
        let gate = Gate<Void>()
        let viewModel = ImportPuzzleViewModel(
            countSolutions: { _ in 1 },
            createGame: { _, _, isCurrent in
                await gate.wait()
                return isCurrent() ? Self.game() : nil
            },
            saveImage: { _ in nil }, deleteImage: { _ in }
        )
        viewModel.loadGrid(Self.givens)
        await waitUntil { viewModel.canStart }
        let start = Task { await viewModel.createImportedGame() }
        await waitUntil { gate.pending.count == 1 }
        XCTAssertFalse(viewModel.canStart, "no second Start while the game is built")
        viewModel.selectedIndex = 0
        viewModel.clearSelected()
        gate.finish(0, with: ())
        let game = await start.value
        XCTAssertNil(game)
        XCTAssertFalse(viewModel.isStarting)
    }

    /// Closing the screen while Start builds the game: no game, and the photo is deleted once (issue 73).
    func testCloseDuringStartDropsTheGameAndKeepsThePhotoDeleted() async throws {
        let gate = Gate<Void>()
        var deleted: [String] = []
        let viewModel = ImportPuzzleViewModel(
            countSolutions: { _ in 1 },
            createGame: { _, _, isCurrent in
                await gate.wait()
                return isCurrent() ? Self.game() : nil
            },
            saveImage: { _ in "photo-1" }, deleteImage: { deleted.append($0) }
        )
        viewModel.updateImage(UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in })
        await waitUntil { !viewModel.isDetecting }
        viewModel.loadGrid(Self.givens)
        await waitUntil { viewModel.canStart }
        let start = Task { await viewModel.createImportedGame() }
        await waitUntil { gate.pending.count == 1 }
        viewModel.discardIfUnused()
        XCTAssertEqual(deleted, ["photo-1"])
        gate.finish(0, with: ())
        let game = await start.value
        XCTAssertNil(game)
        viewModel.discardIfUnused()
        XCTAssertEqual(deleted, ["photo-1"])
    }

    /// The test puzzle's givens.
    private static let givens = TestData.puzzle.initialGrid.map { Int(String($0)).flatMap { $0 > 0 ? $0 : nil } }

    private static func game() -> ImportedGame {
        ImportedGame(gameState: GameState.newGame(for: TestData.puzzle, now: Date()), createdAt: Date(), lastOpened: Date())
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Two or more solutions: a note under the status, and Start stays enabled (issue 66, CODESPEC 2.1).
    func testMultipleSolutionsShowANoteButAllowStart() async {
        let viewModel = makeViewModel()
        // The test puzzle's first three rows only: valid, with many solutions.
        viewModel.loadGrid(Array(Self.givens.prefix(27)) + Array(repeating: nil, count: 54))
        await waitUntil { viewModel.solvableState != .unknown }
        XCTAssertEqual(viewModel.solvableState, .solvable)
        XCTAssertEqual(viewModel.ambiguityNote, "This grid has more than one solution. Check the digits against your photo.")
        XCTAssertTrue(viewModel.canStart)

        viewModel.loadGrid(Self.givens)
        XCTAssertNil(viewModel.ambiguityNote, "cleared while the new grid is checked")
        await waitUntil { viewModel.solvableState != .unknown }
        XCTAssertNil(viewModel.ambiguityNote)
    }

    func testRequiresMinimumClues() {
        let viewModel = makeViewModel()
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        viewModel.selectedIndex = 1
        viewModel.setDigit(3)

        XCTAssertFalse(viewModel.canStart)
    }

    /// Source until a photo or "Type it in"; then Check the grid (CODESPEC 3.4).
    func testStepsFromSourceToCheckTheGrid() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.step, .source)
        viewModel.enterByHand()
        XCTAssertEqual(viewModel.step, .review)
        let loaded = makeViewModel()
        loaded.loadGrid(Array(repeating: nil, count: 80) + [5])
        XCTAssertEqual(loaded.step, .review, "a read grid goes straight to the check")
    }

    func testConflictSummaryNamesTheFirstRepeatedDigit() {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.conflictSummary(names: .plain))
        var values = [Int?](repeating: nil, count: 81)
        values[27] = 4 // row 4
        values[31] = 4
        viewModel.loadGrid(values)
        XCTAssertEqual(viewModel.conflictSummary(names: .plain), "Two 4s in row 4.")
        XCTAssertEqual(viewModel.conflictSummary(names: .grid), "Two 4s in R4.")
    }

    /// Ringed cells clear when tapped (confirmed) or fixed.
    func testUnsureCellsClearWhenTappedOrFixed() {
        let viewModel = makeViewModel()
        var values = [Int?](repeating: nil, count: 81)
        values[5] = 3
        values[47] = 8
        viewModel.loadGrid(values, unsure: [5, 47])
        viewModel.selectCell(id: viewModel.cellIDs[5])
        XCTAssertEqual(viewModel.unsureIndices, [47])
        viewModel.selectedIndex = 47
        viewModel.setDigit(6)
        XCTAssertTrue(viewModel.unsureIndices.isEmpty)
    }

    /// A plain line, dots for blanks, and a text-drawn grid with | - + all read the same 81 cells.
    func testParseGridAcceptsCommonFormats() throws {
        let line = TestData.puzzle.initialGrid
        let expected = line.map { Int(String($0)).flatMap { $0 == 0 ? nil : $0 } }
        XCTAssertEqual(ImportPuzzleViewModel.parseGrid(line), expected)
        XCTAssertEqual(ImportPuzzleViewModel.parseGrid(line.replacingOccurrences(of: "0", with: ".")), expected)
        let rows = stride(from: 0, to: 81, by: 9).map { start -> String in
            let row = Array(line)[start..<start + 9].map(String.init)
            return "| " + row[0..<3].joined(separator: " ") + " | " + row[3..<6].joined(separator: " ")
                + " | " + row[6..<9].joined(separator: " ") + " |"
        }
        let drawn = "+-------+-------+-------+\n" + rows.joined(separator: "\n") + "\n+-------+-------+-------+"
        XCTAssertEqual(ImportPuzzleViewModel.parseGrid(drawn), expected)
        XCTAssertNil(ImportPuzzleViewModel.parseGrid(String(line.dropLast())))
        XCTAssertNil(ImportPuzzleViewModel.parseGrid("hello"))
    }

    func testPasteGridGoesToReviewOrExplains() {
        let viewModel = makeViewModel()
        viewModel.pasteGrid("not a grid")
        XCTAssertEqual(viewModel.step, .source)
        XCTAssertNotNil(viewModel.pasteMessage)
        viewModel.pasteGrid(nil)
        XCTAssertNotNil(viewModel.pasteMessage)

        viewModel.pasteGrid(TestData.puzzle.initialGrid)
        XCTAssertEqual(viewModel.step, .review)
        XCTAssertNil(viewModel.pasteMessage)
        XCTAssertEqual(viewModel.filledCount, TestData.puzzle.initialGrid.filter { $0 != "0" }.count)
    }

    /// A photo still loading when a grid is pasted is dropped, so it never replaces the pasted board.
    func testPasteDropsAPendingPhoto() {
        let viewModel = makeViewModel()
        let token = viewModel.beginPhotoRequest()
        viewModel.pasteGrid(TestData.puzzle.initialGrid)
        viewModel.applyPhoto(UIImage(), token: token)
        XCTAssertNil(viewModel.image)
        XCTAssertEqual(viewModel.step, .review)
    }

    /// Start over drops the photo, the digits and Type it in, and goes back to Source.
    func testStartOverReturnsToSourceAndDeletesThePhoto() {
        var deleted: [String] = []
        let viewModel = ImportPuzzleViewModel(createGame: { _, _, _ in nil }, saveImage: { _ in "photo-1" },
                                              deleteImage: { deleted.append($0) })
        viewModel.updateImage(UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in })
        XCTAssertEqual(viewModel.step, .reading, "Reading shows at once, never Check the grid first")
        var values = [Int?](repeating: nil, count: 81)
        values[0] = 5
        viewModel.loadGrid(values, unsure: [0])
        viewModel.startOver()
        XCTAssertEqual(viewModel.step, .source)
        XCTAssertNil(viewModel.image)
        XCTAssertEqual(viewModel.filledCount, 0)
        XCTAssertTrue(viewModel.unsureIndices.isEmpty)
        XCTAssertEqual(deleted, ["photo-1"])

        let typed = makeViewModel()
        typed.enterByHand()
        typed.startOver()
        XCTAssertEqual(typed.step, .source)
    }

    /// Unsure comes from the candidate's own confidence; 0.6 itself is sure.
    func testDetectorReadingUsesTheCandidateConfidence() {
        // A box Vision is sure of (observation 1.0) can still hold a doubtful read (candidate 0.3).
        let observationConfidence: Float = 1.0, candidateConfidence: Float = 0.3
        XCTAssertNotEqual(observationConfidence, candidateConfidence)
        XCTAssertEqual(SudokuImageDetector.reading(text: "7", confidence: candidateConfidence)?.unsure, true)
        XCTAssertEqual(SudokuImageDetector.reading(text: " 4 ", confidence: 0.6)?.digit, 4)
        XCTAssertEqual(SudokuImageDetector.reading(text: "4", confidence: 0.6)?.unsure, false)
        XCTAssertEqual(SudokuImageDetector.reading(text: "4", confidence: 0.59)?.unsure, true)
        XCTAssertNil(SudokuImageDetector.reading(text: "0", confidence: 1))
        XCTAssertNil(SudokuImageDetector.reading(text: "12", confidence: 1))
    }

    /// A printed puzzle with thin 1s and digits next to the thick outer border (issue 66).
    func testPrintedGridPhotoIsReadInFull() async throws {
        try await assertFixture("printed-grid", reads: "530070000600195000098000060800060003400803001700020006060000280000419005000080079")
    }

    /// NYT dark mode: white border on a near-black page, light digits on grey and amber fills, small
    /// pencil-mark notes that are not givens (issue 98).
    private static let nytDarkGrid = "073050048000824007000713069800000000040000005700001090006190002300402001010000000"

    func testDarkScreenshotIsReadInFull() async throws {
        try await assertFixture("nyt-dark-screenshot", reads: Self.nytDarkGrid)
    }

    /// The same board cropped to the grid, its border touching the image edges (issue 98).
    func testDarkCropIsReadInFull() async throws {
        try await assertFixture("nyt-dark-crop", reads: Self.nytDarkGrid)
    }

    /// NYT dark mode with a selected cell: olive row, column and box highlights, an orange same-digit
    /// fill with dark ink, and a thick white frame. The edge rows and columns must be read too (issue 103).
    private static let nytSelectedGrid = "801000900000000487000800003308000000500237000090008300782000005005710000003086700"

    func testSelectedDarkScreenshotIsReadInFull() async throws {
        try await assertFixture("nyt-dark-selected", reads: Self.nytSelectedGrid)
    }

    /// The same board cropped to its white frame (issue 103).
    func testSelectedDarkCropIsReadInFull() async throws {
        try await assertFixture("nyt-dark-selected-crop", reads: Self.nytSelectedGrid)
    }

    /// Wherever the found rectangle lands around the white frame (outside it, on it, or just inside it,
    /// so the outer lines are lost), the edge rows and columns are still read (issue 103).
    func testSelectedDarkGridIsReadWhereverTheRectangleLands() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "nyt-dark-selected", withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        let frame = CGRect(x: 28, y: 435, width: 863, height: 863) // the white frame's outer edge, in pixels
        for (outer, inner) in [(-12, -12), (-12, 14), (0, 0), (14, -12), (14, 14), (12, 12), (8, 8)] {
            let rect = CGRect(x: frame.minX + CGFloat(outer), y: frame.minY + CGFloat(outer),
                              width: frame.width - CGFloat(outer + inner), height: frame.height - CGFloat(outer + inner))
            let grid = try await SudokuImageDetector().readGrid(try XCTUnwrap(image.cropping(to: rect)))
            XCTAssertEqual(grid.values.map { String($0 ?? 0) }.joined(), Self.nytSelectedGrid, "rectangle \(rect)")
            XCTAssertEqual(grid.unsure, [], "rectangle \(rect)")
        }
    }

    /// A light sudoku.com screenshot with blue highlights, which already imported correctly (issue 103).
    func testLightWebScreenshotIsReadInFull() async throws {
        try await assertFixture("sudokucom-light",
                                reads: "900508007080302905054000080070680032100004008500219060000906001726001040001470056")
    }

    /// A lone thin stroke is a 1 (issue 98); other letters are not digits.
    func testThinStrokeReadsAsOne() {
        XCTAssertEqual(SudokuImageDetector.reading(text: "I", confidence: 0.6)?.digit, 1)
        XCTAssertEqual(SudokuImageDetector.reading(text: "I", confidence: 0.6)?.unsure, false)
        XCTAssertEqual(SudokuImageDetector.reading(text: "I", confidence: 0.1)?.unsure, true)
        XCTAssertEqual(SudokuImageDetector.reading(text: "l", confidence: 1)?.digit, 1)
        XCTAssertNil(SudokuImageDetector.reading(text: "ll", confidence: 1))
        XCTAssertNil(SudokuImageDetector.reading(text: "n", confidence: 1))
    }

    /// The grid lines fit a frame before the first line and a last line cut off by a crop (issue 98).
    func testGridLinesFitFrameAndCutEdge() {
        var profile = [Double](repeating: 1, count: 900)
        for line in 0...8 { profile[30 + line * 100] = 100 }
        let lines = SudokuImageDetector.gridLines(in: profile)
        XCTAssertEqual(lines.start, 30, accuracy: 1)
        XCTAssertEqual(lines.step, 100, accuracy: 0.5)

        // Ten lines, one rounded a pixel short: the fit keeps all nine cells, not a shifted eight.
        var rounded = [Double](repeating: 0, count: 900)
        for position in [0, 100, 200, 300, 400, 499, 599, 699, 799, 899] { rounded[position] = 255 }
        let fitted = SudokuImageDetector.gridLines(in: rounded)
        XCTAssertEqual(fitted.start, 0, accuracy: 1.5)
        XCTAssertEqual(fitted.step, 100, accuracy: 0.5)
    }

    /// The box around the grid on a plain page, touching the right edge; a wide box is no grid (issue 98).
    func testContentBoxFindsGridOnDarkPage() throws {
        func page(with box: CGRect) throws -> CGImage {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 100, height: 80), format: format).image { context in
                UIColor(white: 0.07, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
                UIColor.white.setFill()
                context.fill(box)
            }.cgImage)
        }
        let grid = CGRect(x: 40, y: 10, width: 60, height: 60)
        XCTAssertEqual(SudokuImageDetector.contentBox(in: try page(with: grid)), grid)
        XCTAssertNil(SudokuImageDetector.contentBox(in: try page(with: CGRect(x: 0, y: 30, width: 100, height: 20))))
    }

    /// White ink on a dark fill turns into dark ink on light paper; dark ink is left alone (issue 98).
    func testNormalizedInvertsLightInk() throws {
        func cell(fill: UIColor, ink: UIColor) -> UIImage {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: format).image { context in
                fill.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
                ink.setFill()
                context.fill(CGRect(x: 16, y: 8, width: 8, height: 24))
            }
        }
        func corner(_ image: UIImage) throws -> UInt8 {
            try XCTUnwrap(SudokuImageDetector.grayPixels(of: try XCTUnwrap(image.cgImage), width: 40, height: 40))[0]
        }
        func center(_ image: UIImage) throws -> UInt8 {
            try XCTUnwrap(SudokuImageDetector.grayPixels(of: try XCTUnwrap(image.cgImage), width: 40, height: 40))[20 * 40 + 20]
        }
        let dark = SudokuImageDetector.normalized(cell(fill: UIColor(white: 0.25, alpha: 1), ink: .white))
        XCTAssertGreaterThan(try corner(dark), try center(dark))
        let amber = SudokuImageDetector.normalized(cell(fill: .orange, ink: .black))
        XCTAssertGreaterThan(try corner(amber), try center(amber))
    }

    private func assertFixture(_ name: String, reads expected: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let start = Date()
        let grid = try await SudokuImageDetector().detectGrid(from: image)
        let read = grid.values.map { String($0 ?? 0) }.joined()
        let seconds = String(format: "%.2f", Date().timeIntervalSince(start))
        print("FIXTURE \(name) read in \(seconds)s: \(read), unsure \(grid.unsure.sorted())")
        XCTAssertEqual(read, expected, file: file, line: line)
        // Every given in a fixture is clear, so none is ringed (issue 103).
        XCTAssertEqual(grid.unsure, [], file: file, line: line)
    }

    /// Any pass that saw text but no digit keeps the cell ringed; any digit wins (issue 66).
    func testRetriesKeepRejectedText() {
        typealias Reading = SudokuImageDetector.CellReading
        XCTAssertEqual(SudokuImageDetector.settle([.empty, .empty, .rejected]), .rejected)
        XCTAssertEqual(SudokuImageDetector.settle([.rejected, .empty, .empty]), .rejected)
        XCTAssertEqual(SudokuImageDetector.settle([.rejected, .digit(1, unsure: false)]), Reading.digit(1, unsure: false))
        XCTAssertEqual(SudokuImageDetector.settle([.empty, .empty, .empty]), .empty)
        // A sure read beats an earlier unsure one; with no sure read the first digit stays (issue 98).
        XCTAssertEqual(SudokuImageDetector.settle([.digit(7, unsure: true), .digit(1, unsure: false)]), Reading.digit(1, unsure: false))
        XCTAssertEqual(SudokuImageDetector.settle([.digit(7, unsure: true), .empty]), Reading.digit(7, unsure: true))
        // Two unsure reads that agree are sure; any disagreement keeps the first, unsure (issue 103).
        XCTAssertEqual(SudokuImageDetector.settle([.digit(1, unsure: true), .digit(1, unsure: true), .empty]),
                       Reading.digit(1, unsure: false))
        XCTAssertEqual(SudokuImageDetector.settle([.digit(1, unsure: true), .digit(1, unsure: true), .digit(7, unsure: true)]),
                       Reading.digit(1, unsure: true))
    }

    /// Text that was seen but not read as a digit is ringed and left blank, never dropped (issue 66).
    func testRejectedCellIsRingedAndBlank() {
        var readings = [SudokuImageDetector.CellReading](repeating: .empty, count: 81)
        readings[0] = .digit(5, unsure: false)
        readings[1] = .digit(3, unsure: true)
        readings[2] = .rejected
        let grid = SudokuImageDetector.grid(from: readings)
        XCTAssertEqual(Array(grid.values.prefix(4)), [5, 3, nil, nil])
        XCTAssertEqual(grid.unsure, [1, 2])
    }

    private func makeViewModel() -> ImportPuzzleViewModel {
        ImportPuzzleViewModel(
            createGame: { _, _, _ in nil },
            saveImage: { _ in nil },
            deleteImage: { _ in }
        )
    }

    /// The empty grid says what to do; the line goes once a digit is in (issue 51).
    func testEmptyGridHint() {
        let viewModel = makeViewModel()
        viewModel.enterByHand()
        XCTAssertEqual(viewModel.emptyGridHint, "Type the digits printed in the puzzle: tap a cell, then a number.")
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        XCTAssertNil(viewModel.emptyGridHint)
    }
}

/// Holds async work until the test finishes it, so results can arrive in any order.
@MainActor
private final class Gate<Value: Sendable> {
    private(set) var pending: [CheckedContinuation<Value, Never>] = []
    private var finished: Set<Int> = []

    func wait() async -> Value {
        await withCheckedContinuation { pending.append($0) }
    }

    func finish(_ index: Int, with value: Value) {
        guard finished.insert(index).inserted else { return }
        pending[index].resume(returning: value)
    }
}
