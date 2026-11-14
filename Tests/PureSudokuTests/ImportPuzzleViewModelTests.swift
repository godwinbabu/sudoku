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
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "printed-grid", withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let grid = try await SudokuImageDetector().detectGrid(from: image)
        let expected = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
        XCTAssertEqual(grid.values.map { String($0 ?? 0) }.joined(), expected)
        XCTAssertTrue(grid.unsure.allSatisfy { grid.values[$0] != nil }, "no blank cell is ringed: \(grid.unsure.sorted())")
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
private final class Gate<Value> {
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
