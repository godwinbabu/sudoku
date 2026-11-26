import XCTest
@testable import PureSudoku

/// v3 game behaviour: the Solved greeting, the board layout, generated notes and the More menu's cell
/// actions (HANDOFF 5, 6.2, 6.5; owner's requests after v3).
@MainActor
final class GameV3Tests: XCTestCase {
    private func makeViewModel(settings: Settings = Settings()) -> GameViewModel {
        GameViewModel(state: TestData.newGameState(), settings: settings, validator: SudokuValidator(), timeProvider: MockTimeProvider())
    }

    private func cellIndex(_ viewModel: GameViewModel, _ cell: SudokuCell) -> Int {
        viewModel.state.cells.firstIndex { $0.id == cell.id }!
    }
}

// The Solved screen's greeting (HANDOFF 6.5, owner's request).
extension GameV3Tests {
    func testSolvedGreetingFollowsTheHour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let expected: [(minutes: Int, greeting: String)] = [
            (4 * 60 + 59, "Good night"), (5 * 60, "Good morning"), (11 * 60 + 59, "Good morning"), (12 * 60, "Good afternoon"),
            (16 * 60 + 59, "Good afternoon"), (17 * 60, "Good evening"), (20 * 60 + 59, "Good evening"), (21 * 60, "Good night"),
            (0, "Good night")
        ]
        let midnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 22)))
        for item in expected {
            let date = midnight.addingTimeInterval(TimeInterval(item.minutes * 60))
            XCTAssertEqual(GameViewModel.greeting(at: date, calendar: calendar), item.greeting, "minute \(item.minutes)")
        }
    }
}

// The game layout (HANDOFF 5, PR 106 review): the keypad stays on screen on short screens.
extension GameV3Tests {
    func testBoardLeavesRoomForTheKeypad() {
        // (width, height inside the safe areas, bars' bottom padding): iPhone SE with Display Zoom, iPhone SE,
        // a 390 pt Face ID phone, and the same with the build-number strip.
        for (width, height, barsBottom) in [(320.0, 548.0, 28.0), (375, 647, 28), (390, 756, -6), (390, 740, 0)] {
            let side = GameView.boardSide(width: width, height: height, barsBottom: barsBottom)
            XCTAssertLessThanOrEqual(side + GameView.chromeHeight + barsBottom, height, "\(width)×\(height)")
            XCTAssertLessThanOrEqual(side, width - 12)
        }
        XCTAssertEqual(GameView.boardSide(width: 390, height: 756, barsBottom: -6), 378, "full width on a 390 pt phone")
    }
}

// Generated notes and the More menu's cell actions (owner's request, PR 106).
extension GameV3Tests {
    /// Fill all notes keeps the player's notes; Clear generated notes removes only what Fill added, and a
    /// generated note the player removes and adds back is theirs. One Undo reverts the clear.
    func testClearGeneratedNotesKeepsThePlayersOwn() throws {
        let viewModel = makeViewModel()
        let solution = Array(viewModel.state.puzzle.solutionGrid).map { Int(String($0)) ?? 0 }
        let empties = viewModel.state.cells.filter { $0.value == nil }
        let mine = try XCTUnwrap(empties.first), other = try XCTUnwrap(empties.dropFirst().first)
        let answer = solution[mine.index]
        viewModel.inputMode = .candidate
        viewModel.select(cell: mine)
        viewModel.setDigit(answer)
        XCTAssertFalse(viewModel.hasGeneratedNotes)

        viewModel.fillAllNotes()
        let filled = viewModel.state.cells[cellIndex(viewModel, mine)]
        XCTAssertTrue(filled.candidates.contains(answer))
        XCTAssertFalse(filled.generatedCandidates.contains(answer), "the player's note is not generated")
        XCTAssertTrue(viewModel.hasGeneratedNotes)

        let touched = try XCTUnwrap(viewModel.state.cells[cellIndex(viewModel, other)].generatedCandidates.min())
        viewModel.select(cell: other)
        viewModel.setDigit(touched) // removes the generated note
        viewModel.setDigit(touched) // adds it back by hand
        viewModel.clearGeneratedNotes()
        XCTAssertEqual(viewModel.state.cells[cellIndex(viewModel, mine)].candidates, [answer])
        XCTAssertEqual(viewModel.state.cells[cellIndex(viewModel, other)].candidates, [touched])
        XCTAssertFalse(viewModel.hasGeneratedNotes)
        viewModel.undo()
        XCTAssertTrue(viewModel.hasGeneratedNotes, "one Undo brings them back")
    }

    /// Saves from before generated notes treat every note as the player's own.
    func testOldSavedCellsHaveNoGeneratedNotes() throws {
        var cell = SudokuCell(row: 0, col: 0, given: false, value: nil, candidates: [2, 5])
        cell.generatedCandidates = [5]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(cell)) as? [String: Any])
        XCTAssertNotNil(json["generatedCandidates"], "saved with the game")
        json["generatedCandidates"] = nil
        let old = try JSONDecoder().decode(SudokuCell.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.candidates, [2, 5])
        XCTAssertTrue(old.generatedCandidates.isEmpty)
    }

    /// Check cell needs an entered digit; Reveal cell needs a cell the player can fill.
    func testCellActionsFollowTheSelection() throws {
        let viewModel = makeViewModel()
        let given = try XCTUnwrap(viewModel.state.cells.first { $0.given })
        let empty = try XCTUnwrap(viewModel.state.cells.first { $0.value == nil })
        XCTAssertFalse(viewModel.canCheckSelectedCell, "nothing selected")
        viewModel.select(cell: given)
        XCTAssertFalse(viewModel.canCheckSelectedCell)
        XCTAssertFalse(viewModel.canRevealSelectedCell)
        viewModel.select(cell: empty)
        XCTAssertFalse(viewModel.canCheckSelectedCell, "an empty cell has nothing to check")
        XCTAssertTrue(viewModel.canRevealSelectedCell)
        viewModel.setDigit(1)
        XCTAssertTrue(viewModel.canCheckSelectedCell)
        viewModel.revealCell()
        XCTAssertFalse(viewModel.canRevealSelectedCell, "already revealed")
        XCTAssertTrue(viewModel.state.usedReveal, "a revealed cell means the solve is not counted")
    }
}

// Generated notes across a refill and a save (PR 106 review round 3).
extension GameV3Tests {
    /// Tidy notes off: a digit placed after the first fill leaves a stale generated note in its peers. A second
    /// fill keeps it generated, so Clear generated notes still removes it.
    func testRefillKeepsStaleNotesGenerated() throws {
        var settings = Settings()
        settings.tidyNotes = false
        let viewModel = makeViewModel(settings: settings)
        viewModel.fillAllNotes()
        let empties = viewModel.state.cells.filter { $0.value == nil }
        // Two empty cells in a row that share a generated note.
        let (placed, peer) = try XCTUnwrap(empties.lazy.compactMap { a -> (SudokuCell, SudokuCell)? in
            empties.first { $0.id != a.id && $0.row == a.row && !$0.generatedCandidates.isDisjoint(with: a.candidates) }
                .map { (a, $0) }
        }.first)
        let digit = try XCTUnwrap(peer.generatedCandidates.intersection(placed.candidates).min())
        viewModel.inputMode = .normal
        viewModel.select(cell: placed)
        viewModel.setDigit(digit)
        XCTAssertTrue(viewModel.state.cells[cellIndex(viewModel, peer)].candidates.contains(digit), "Tidy notes off: stale note stays")
        viewModel.fillAllNotes()
        viewModel.clearGeneratedNotes()
        XCTAssertFalse(viewModel.state.cells[cellIndex(viewModel, peer)].candidates.contains(digit), "the stale note was generated")
        XCTAssertFalse(viewModel.hasGeneratedNotes)
    }

    /// A saved game keeps which notes are generated: after a reload, Clear still keeps only the player's.
    func testGeneratedNotesSurviveASave() throws {
        let viewModel = makeViewModel()
        let mine = try XCTUnwrap(viewModel.state.cells.first { $0.value == nil })
        let solution = Array(viewModel.state.puzzle.solutionGrid).map { Int(String($0)) ?? 0 }
        viewModel.inputMode = .candidate
        viewModel.select(cell: mine)
        viewModel.setDigit(solution[mine.index])
        viewModel.fillAllNotes()
        let reloaded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(viewModel.state))
        XCTAssertEqual(reloaded, viewModel.state, "generated notes round-trip")
        let restored = GameViewModel(state: reloaded, settings: Settings(), validator: SudokuValidator(), timeProvider: MockTimeProvider())
        restored.clearGeneratedNotes()
        XCTAssertEqual(restored.state.cells[cellIndex(restored, mine)].candidates, [solution[mine.index]])
        XCTAssertTrue(restored.state.cells.filter { $0.id != mine.id }.allSatisfy { $0.candidates.isEmpty })
    }
}
