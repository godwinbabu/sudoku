PureSudoku – Coding AI Spec with Testing
BEGIN SPEC FOR CODING AI

You are an expert iOS engineer.
Build PureSudoku, a no-frills Sudoku iPhone app focused on speed, clarity, and great gameplay, modeled after the New York Times Sudoku experience.

In addition to the app, you must also create a comprehensive test suite:

Unit tests for Sudoku logic, game state, stats, and persistence.
UI tests for core flows (starting a game, entering numbers, toggling notes, etc.).
0. Tech Stack & Project Setup
App name (display name): PureSudoku
Target platform: iOS only, iPhone screens (later should scale to iPad, but not required now).
Language: Swift 5+
UI framework: SwiftUI (preferred).
If something is much easier in UIKit, you may use a small UIViewRepresentable bridge, but default to SwiftUI.
Minimum iOS version: iOS 16+
Architecture: MVVM with clear separation:
Sudoku engine (pure logic, testable).
View models for UI state.
SwiftUI views for rendering.
No backend / no network calls. All data must be stored locally on the device.
Testing requirements for setup:

Create two test targets:
PureSudokuTests (unit tests, using XCTest).
PureSudokuUITests (UI tests, using XCTest + XCUITest).
Make sure logic modules (engine, models, view models) are in a module shared with unit tests.
Deliverables:

A working Xcode project with:
SudokuEngine module (or group).
Models, ViewModels, Views.
Persistence utilities for saving/loading state and stats.
Test targets with meaningful tests, not just empty templates.
1. High-Level Product Requirements
The app is a minimalist Sudoku game, modeled after NYT Sudoku:
Single main screen with three difficulty buttons: Easy, Medium, Hard.
Tapping a difficulty:
If there is an unfinished game at that difficulty, continue that game.
Otherwise, start a new puzzle at that difficulty.
No accounts, no login, no backend, no ads.
Focus on:
Fast launch.
Instant responsiveness to taps.
Clean, readable UI.
The app must support bedtime / partner-friendly use with a Night appearance (black canvas, Glow, Warmth, Clarity; see Section 12).
The app teaches solving techniques, not only answers (see Section 13):
A Learn entry point on the main screen opens the technique curriculum.
Hints name and explain a technique on the player’s own board before any cell changes.
Each difficulty button lists the techniques it needs (e.g. “Medium: singles, pointing, pairs”).
Optional later: a fourth Expert difficulty (Section 13, phase 6). Do not add it before the Expert tier exists.
Testing requirements:

Unit test: logic for “continue existing game vs. create new game” per difficulty.
UI test: tapping each difficulty on main screen should navigate to a game and show a 9×9 grid.
2. Core Gameplay Requirements
2.1 Sudoku Basics
Standard 9×9 Sudoku:
Each row, column, and 3×3 subgrid must contain all digits 1–9 exactly once.
Each puzzle:
Generated puzzles have a unique solution.
Imported puzzles (BYOS.md) need only be solvable. They may have more than one solution.
Has a preset difficulty: .easy, .medium, .hard.
Has a uniqueness flag (hasUniqueSolution), set when the puzzle is created:
Generated puzzles: true.
Imported puzzles: count solutions on import, stopping at 2; true only if the count is exactly 1.
When hasUniqueSolution is false:
The hint engine must not use uniqueness techniques (Unique Rectangle, BUG+1, Hidden/Avoidable Rectangle).
Check, Hint and Reveal compare against a solution that fits the player’s current entries (as GameViewModel already does for imports), not one fixed answer.
Testing requirements:

Unit tests:
A puzzle with two solutions is flagged hasUniqueSolution == false; a generated puzzle is flagged true.
On a puzzle flagged false, the hint engine never returns a uniqueness technique.
Given a complete solutionGrid, verify that:
Each row has digits 1–9.
Each column has digits 1–9.
Each 3×3 block has digits 1–9.
For a GameState representing a solved puzzle, isCompleted should return true.
2.2 Difficulty Levels
Implement a Difficulty enum:

enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
}

For now, implement one of these two approaches (either is acceptable):
	1.	Simpler for MVP (recommended):
	•	Bundle a JSON file for each difficulty (easy.json, medium.json, hard.json) with a list of puzzles.
	•	Each puzzle entry contains:
	•	id: String
	•	initialGrid: String (81-char string, 0 or . for empty cells)
	•	solutionGrid: String (81-char string with full solution)
	•	When starting a new puzzle, pick one at random (or sequentially) for the chosen difficulty.
	2.	Full generator (optional):
	•	Implement a generator + solver that:
	•	Generates full valid grids.
	•	Removes numbers to create puzzles.
	•	Uses a solver to ensure uniqueness and assign a rough difficulty score.
	•	Map difficulty score to .easy, .medium, .hard.
	•	(Before phase 4 the score was the average backtracking depth over 4 solver runs; see docs/audit/bench-ratings.swift. Replaced by the logical grade below.)

Rating (phase 4 onward): a logical grade, measured the way a person solves (PuzzleGrader).
	•	Solve the puzzle with the logical solver (Section 13.3), one step at a time, always taking the simplest available step.
	•	The grade records:
	•	hardestTier: the tier of the hardest technique needed (Basic, Intermediate, Advanced, Expert).
	•	score: the sum of the step scores (one fixed score per technique, see HINT_STRATEGIES.md).
	•	techniques: the set of techniques used.
	•	If the logical solver gets stuck, the puzzle is out of range for every level and is discarded.
	•	Map grade to difficulty by the techniques it needs:
	•	Easy: Basic tier only.
	•	Medium: needs at least one Intermediate technique, nothing harder.
	•	Hard: needs at least one Advanced technique, nothing harder.
	•	(Optional, phase 6) Expert: needs at least one Expert technique.
	•	Within a level, the score orders puzzles from easier to harder.
	•	No silent fallback: a puzzle is only offered at the level its grade maps to. If generation cannot find one in time, use a bundled pre-graded puzzle of that level.
	•	Generation tries up to 30 puzzles (about 12 ms each on a Mac). Measured on 1,000 generated puzzles with the full Advanced tier (phase 5): 42% Easy, 19% Medium, 18% Hard, 21% need an Expert technique (discarded). (Phase 4 alone: 3.7% Hard.)
	•	Bundled: 120 pre-graded, unique-solution puzzles per level (BundledPuzzles.swift, generated offline with this app’s generator; no licence applies). They also serve as practice drills, indexed by technique.
	•	An import the logical solver can’t finish gets Hard and no grade.
	•	The grade is deterministic: the same puzzle always gets the same grade.

For this first version, it’s acceptable to only implement the JSON-puzzle approach and leave the generator as a future enhancement (stubbed).

Testing requirements:
	•	Unit tests for SudokuPuzzleRepository:
	•	Load puzzles for each difficulty; verify:
	•	At least one puzzle exists per difficulty.
	•	initialGrid.count == 81, solutionGrid.count == 81.
	•	Validate that solutionGrid is a valid Sudoku with the validator.
	•	If generator is implemented:
	•	Generator unit tests: each generated puzzle has:
	•	Exactly 81 cells.
	•	A valid solution.
	•	A unique solution (if you implement uniqueness checking).
	•	Logical grade (phase 4):
	•	The same puzzle graded twice gives the same grade.
	•	A puzzle that needs only singles grades Easy; a known X-Wing puzzle grades Hard.
	•	A puzzle requested at a level never comes back graded at a different level.

2.3 Game State Model

Define core models:

struct SudokuCell: Identifiable, Codable {
    let id: UUID
    var row: Int // 0-8
    var col: Int // 0-8
    var given: Bool      // true if part of initial puzzle
    var value: Int?      // final user value or given
    var candidates: Set<Int> // candidate notes (1-9)
    var isError: Bool    // for check feedback
    var isRevealed: Bool // true if revealed by hint/reveal
}

struct SudokuPuzzle: Codable {
    var id: String
    var difficulty: Difficulty
    var initialGrid: String    // 81 chars
    var solutionGrid: String   // 81 chars
}

struct GameState: Codable {
    var puzzle: SudokuPuzzle
    var cells: [SudokuCell] // 81 cells
    var elapsedSeconds: Int
    var isCompleted: Bool
    var usedReveal: Bool // true if Reveal Cell or Reveal Puzzle used
    var lastUpdated: Date
}

	•	Maintain one active GameState per difficulty (3 saved states):
	•	activeEasyGame
	•	activeMediumGame
	•	activeHardGame

Additions for teaching (added in the phase that first needs them, Section 13.6):
	•	SudokuPuzzle:
	•	hasUniqueSolution: Bool (Section 2.1). Default when missing from a saved file: source == .generated. An imported puzzle saved without it gets its solutions counted (stopping at 2) the first time it loads, and the result is saved.
	•	grade: PuzzleGrade? (hardestTier, score, techniques; Section 2.2). Nil for puzzles saved before grading existed.
	•	GameState:
	•	hintLog: [HintLogEntry] — one entry per hint: technique, deepest rung shown (0–4), whether it was applied.
	•	usedHint: Bool — true once a hint’s result (rung 4) has been shown (Section 6.3.1).
	•	TechniqueProgress (new model, one per technique):
	•	foundUnaidedCount: Int, foundUnaidedDays: Set<day>, lastSeen: Date?, strength: Double (0–1, decays over time).
	•	All new fields decode with defaults (decodeIfPresent), so older save files still load. This applies to every persisted model: SudokuPuzzle, GameState, Settings, Stats and TechniqueProgress. A strict decode of a new field would make the old file fail to load and be moved aside, losing the player’s settings.

Testing requirements:
	•	Unit tests:
	•	Decode a GameState and SudokuPuzzle saved without the new fields; verify defaults (empty hintLog, usedHint == false, grade == nil, hasUniqueSolution == true for generated).
	•	An imported two-solution puzzle saved without hasUniqueSolution loads as false.
	•	Settings and Stats files saved by the previous version load without errors, with defaults for new fields.
	•	Construct a GameState from initialGrid and solutionGrid and verify:
	•	Exactly 81 cells.
	•	given and value are set correctly based on initialGrid.
	•	Encode and decode GameState using Codable and ensure equality (round-trip test).

⸻

3. Screen & Navigation Structure

3.1 Main Screen
	•	SwiftUI view: MainMenuView
	•	Layout:
	•	App title: “PureSudoku”.
	•	Three buttons: Easy, Medium, Hard.
	•	Under each button, a short line naming the techniques that level needs (phase 4).
	•	A Learn button that opens the Learn screen (Section 13.5, phase 5).
	•	A small section showing:
	•	Current streak (“Streak: N days”).
	•	Total puzzles solved.
	•	Optional total time spent.
	•	A settings icon to open SettingsView (appearance, Night screen, toggles).
	•	A Night toggle at the bottom that switches between Day and Night (until the Night sheet, Section 12.2 of the v2 design, replaces it).
	•	Behavior:
	•	Tapping a difficulty:
	•	If an unfinished game exists for that difficulty (!isCompleted), navigate to GameView with that existing GameState.
	•	Otherwise, create a new GameState from a puzzle of that difficulty and navigate to GameView.

Testing requirements:
	•	UI tests:
	•	Launch app, verify that Easy, Medium, Hard buttons are visible.
	•	Tap Easy and verify that a game view appears and shows a grid of 9×9 cells.

3.2 Game Screen
	•	SwiftUI view: GameView
	•	Shows:
	•	Top bar:
	•	Back button (to main).
	•	Difficulty label.
	•	Timer display.
	•	Sudoku grid (9×9), with:
	•	Bold lines between 3×3 blocks.
	•	Cells:
	•	Given numbers in one style.
	•	User-entered numbers in another.
	•	Number pad (digits 1–9) at bottom (thumb-friendly).
	•	Mode toggle: Normal / Notes (Candidate mode).
	•	Action buttons (can be toolbar or menu, preferably near bottom for ergonomics):
	•	Hint (opens the hint panel, Section 6.3)
	•	Check Cell
	•	Check Puzzle
	•	Reveal Cell
	•	Reveal Puzzle
	•	Reset Puzzle
	•	New Puzzle
	•	Interaction:
	•	Tap a cell to select it.
	•	Tap a number to either:
	•	Fill value (Normal mode).
	•	Toggle candidate (Notes mode).
	•	Hint panel (phase 3):
	•	A bottom sheet over the number pad. The whole grid stays visible above it.
	•	Its buttons (Back, Next, Apply, Done) sit in thumb reach at the bottom.
	•	While it is open, the grid shows the hint’s highlights (Section 7.3).

Testing requirements:
	•	UI tests:
	•	Start an Easy game, tap a cell, tap a number; verify the cell displays that number.
	•	Toggle Notes mode, tap another cell, tap a number; verify smaller candidate text appears in that cell.
	•	Tap Reset Puzzle and verify that user-entered values and candidates are cleared.

3.3 Settings & Stats Screen
	•	SwiftUI view: SettingsView and StatsView (can be separate or combined).
	•	Settings includes:
	•	Appearance: Day, Night, After dark, Match iPhone (Section 7.1).
	•	Night screen: preset (Reading lamp, Lights out, Red light), Glow, Warmth (shown in Kelvin), Clarity (Section 12.3).
	•	Toggles:
	•	Show timer on/off.
	•	Tidy notes (remove a placed digit from the notes it sees).
	•	Show mistakes: Right away / When I check. Never (no marks, even on Check) is hidden until the v2 game screen supports it.
	•	Cell names: “row 3, column 5” (default) or short “r3c5” (phase 3).
	•	Hints: ask “Try it yourself first?” before showing a result (default on, phase 3).
	•	These controls move to the Night sheet and Journal › Display & Night in later v2 phases (Design/v2/README.md).
	•	Stats includes:
	•	Current streak.
	•	Best times per difficulty.
	•	Puzzles solved per difficulty.
	•	Total puzzles solved.
	•	Total time spent.

Testing requirements:
	•	Unit tests:
	•	Changing a setting (e.g. showTimer, appearance, glow) in the view model should persist and reload correctly.
	•	Settings files from v1 (theme, bedtimeMode, sleepBrightness, display profiles, autoCheckMistakes, autoRemoveCandidates) load and map to the v2 fields (Section 7.1).
	•	UI tests:
	•	Navigate to settings, toggle Show timer off, go back to game and verify timer visually hidden.

⸻

4. Timer Behavior

Implement a timer that tracks only active play time:
	•	The timer should:
	•	Start when a puzzle begins or resumes.
	•	Pause when app goes into background, app becomes inactive, or GameView disappears.
	•	Resume when GameView appears again (and game is not completed).

Implementation suggestion:
	•	Store elapsedSeconds in GameState.
	•	When GameView appears:
	•	Record startTimestamp = Date().
	•	Use a Timer.publish(every: 1, on: .main, in: .common) or Task with sleep to increment elapsedSeconds while active.
	•	When GameView disappears or app moves to background:
	•	Add Date().timeIntervalSince(startTimestamp) to elapsedSeconds.
	•	Stop timer.

Timer display:
	•	Format as mm:ss or hh:mm:ss for longer sessions.
	•	If Show timer setting is off:
	•	Keep updating internals but hide the timer UI.

Testing requirements:
	•	Unit tests:
	•	Given a GameViewModel with mocked time progression, verify that:
	•	elapsedSeconds increments while running.
	•	elapsedSeconds stops incrementing when pause() is called (simulating background).
	•	UI tests (best-effort, can be shorter):
	•	Start a game, wait a couple of seconds, assert that the timer label changes.

⸻

5. Input Modes: Normal vs Candidate

Maintain:
enum InputMode {
    case normal
    case candidate
}

	•	Normal mode:
	•	Selecting a number sets cell.value = digit (if cell is not given and not isRevealed).
	•	Clears cell.candidates.
	•	Candidate (notes) mode:
	•	Selecting a number toggles presence in cell.candidates.
	•	Leaves cell.value unchanged.
	•	Candidates appear in smaller font inside the cell:
	•	Use a smaller Text overlay.

Optional behavior (controlled by settings):
	•	Auto-remove candidates:
	•	When a final value is placed in a cell:
	•	For all cells in the same row/column/block, remove that digit from candidates.

Testing requirements:
	•	Unit tests:
	•	In GameViewModel, test:
	•	When in normal mode, setting a value clears candidates.
	•	When in candidate mode, tapping same number toggles it in candidates.
	•	When autoRemoveCandidates is true, placing a value removes the candidate from related cells; when false, it doesn’t.

⸻

6. Check, Hint, Reveal & Puzzle Control

6.1 Check Cell
	•	When user taps Check Cell:
	•	If a cell is selected and has value:
	•	Compare with solutionGrid.
	•	If correct: mark isError = false.
	•	If incorrect: set isError = true.

Testing requirements:
	•	Unit tests:
	•	For a known puzzle and solution, set a cell value correctly and call checkCell(); verify isError == false.
	•	Set an incorrect value and call checkCell(); verify isError == true.

6.2 Check Puzzle
	•	When user taps Check Puzzle:
	•	Iterate all cells with value:
	•	Compare each value to solutionGrid.
	•	Mark isError for incorrect cells.

Testing requirements:
	•	Unit tests:
	•	With a partially incorrect board, call checkPuzzle() and verify:
	•	All incorrect cells are flagged.
	•	Correct cells are not flagged.

6.3 Hint and Reveal Cell

Hint and Reveal Cell are two separate actions. Hint teaches; Reveal Cell fills a cell.
Until phase 3 ships, the current behavior stays: Hint finds a placement and, with autoFillHints on, fills it.

6.3.1 Hint (the hint ladder, phase 3)
	•	Tapping Hint opens the hint panel at the first rung that applies. Each further tap (Next) shows the next rung.
	•	The board never changes until the player taps Apply.
	•	Rungs:
	•	Rung 0 – Check (automatic, always first):
	•	Narrowing uses the cell’s box: “Look at box 5”, then the cell.
	•	If the board has a wrong digit, or a cell that has notes leaves out its correct digit: “There’s a mistake on the board.”
	•	Cells with no notes are never a mistake. Notes that conflict with a placed digit (stale notes) are ignored, not reported.
	•	Next narrows it: first the house (row, column or box), then the cell.
	•	No technique hint is given until the mistake is fixed. The panel offers Undo.
	•	Rung 1 – Name: “A Hidden Single is available.” Shows the tier badge and a one-line definition.
	•	For a technique the player has never seen: also offers a short lesson (Section 13.5).
	•	Rung 2 – Where: soft outlines on the house or houses to look at. “Look at box 5.”
	•	Rung 3 – Why: the pattern cells are outlined and the key digit is ringed. Chains show strong links solid and weak links dashed.
	•	A step with several parts splits into numbered sub-steps with Back and Next.
	•	Rung 4 – Result: eliminated candidates are struck through, or the placed digit appears as a ghost.
	•	A Before / After toggle stays until the player taps Apply or Done.
	•	If “Try it yourself first?” is on, ask once before showing this rung.
	•	Apply makes the change as one undoable edit (Section 6.7). An elimination in a cell without notes first writes that cell’s candidates as notes, then removes the digit, so the deduction is kept and the next hint moves on.
	•	For singles (placement steps), the target cell is outlined only at rung 4: at rung 3 it would give the answer away.
	•	Done closes the panel without changing the board.
	•	Hint content:
	•	The hint comes from the logical solver (Section 13.3): the simplest step available on the player’s current board.
	•	The hint uses the player’s own notes where they exist. If a step needs notes the player has not written, the step shows the candidates it relies on.
	•	The same board always gives the same hint.
	•	If the solver finds no step it can explain: “I can’t find a step I can explain. Reveal this cell?” This links to Reveal Cell. It never returns nothing.
	•	Fading (phase 5):
	•	A technique the player has mastered (Section 13.4) opens at rung 1 and stops there unless the player taps Next.
	•	A technique the player has never seen opens at rung 3, as a worked example, and the panel also offers its lesson.
	•	Stats:
	•	Rungs 0–3 do not affect stats.
	•	Showing rung 4 (the result) sets usedHint = true, whether or not the player taps Apply. Undo never clears it (same as usedReveal). The solve still counts toward puzzles solved, total time and the streak, but not toward best time.
	•	Reveal Cell and Reveal Puzzle keep their current rule (usedReveal: the solve does not count).
	•	The autoFillHints setting is removed when the ladder ships. Older settings files that contain it still load.

6.3.2 Reveal Cell
	•	If a selected cell is empty (value == nil, not given, not isRevealed):
	•	Set value to correct number from solutionGrid.
	•	Set isRevealed = true.
	•	Mark gameState.usedReveal = true.

Testing requirements:
	•	Unit tests:
	•	On revealCell():
	•	Verify that value matches solutionGrid.
	•	isRevealed == true.
	•	usedReveal == true.
	•	Hint ladder (phase 3):
	•	With a wrong digit on the board, Hint returns rung 0 and no technique.
	•	With no notes anywhere, Hint returns a technique (not rung 0).
	•	With stale notes only (Auto-remove off), Hint returns a technique.
	•	Rungs 1–3 never change the board.
	•	Showing rung 4 sets usedHint; Apply changes the board as the step says, and one Undo reverts the board but leaves usedHint set.
	•	A solve with usedHint counts in puzzles solved and the streak but not in best time.
	•	The same board gives the same hint twice.
	•	When the solver finds no step, Hint offers Reveal Cell instead of returning nothing.
	•	UI tests:
	•	Tap Hint, step through each rung, tap Apply; verify the board changed and Undo restores it.

6.4 Reveal Puzzle
	•	Confirmation dialog.
	•	On confirm:
	•	Fill all cells with solution values.
	•	Mark all as isRevealed = true.
	•	Mark usedReveal = true.
	•	Mark isCompleted = true.

Testing requirements:
	•	Unit tests:
	•	After revealPuzzle() on a partially filled board:
	•	All cells.value equal solution.
	•	All cells.isRevealed == true.
	•	usedReveal == true, isCompleted == true.

6.5 Reset Puzzle (Restart Same Puzzle)
	•	Confirmation dialog.
	•	On confirm:
	•	Reset cells to initial puzzle state.
	•	elapsedSeconds = 0.
	•	usedReveal = false, isCompleted = false.

Testing requirements:
	•	Unit tests:
	•	Fill some cells, set some candidates and flags, then call resetPuzzle(); verify:
	•	Only given values exist.
	•	Candidates cleared.
	•	Flags reset.
	•	Timer reset.

6.6 New Puzzle (Same Difficulty)
	•	Confirmation dialog.
	•	On confirm:
	•	Load a new SudokuPuzzle of the same difficulty.
	•	Create fresh GameState.
	•	Replace active game for that difficulty.

Testing requirements:
	•	Unit tests:
	•	After newPuzzle(), verify:
	•	GameState.puzzle.id is different (if multiple puzzles exist).
	•	All cells correspond to the new puzzle’s initialGrid.

6.7 Undo
	•	Provide an Undo action in GameView.
	•	Each user-facing edit pushes a snapshot onto an undo stack (value set/clear, candidate toggle, hint/reveal cell, reveal puzzle, reset).
	•	Applying a hint step is one edit, even when it removes many candidates at once.
	•	Tapping Undo restores the previous state; repeated taps walk back to the first change.
	•	Disable Undo when there is no history or the game is completed.

Testing requirements:
	•	Unit tests:
	•	After two sequential value edits, Undo restores the previous value, then clears it on the next Undo.
	•	Candidate toggles are reverted by Undo.
	•	One Undo reverts a whole applied hint step.

⸻

7. Theme & UI Modes

7.1 Appearance

Implement:
enum Appearance: String, Codable {
    case day          // warm paper palette
    case night        // black canvas, warm digits, silent
    case afterDark    // Night from sunset to sunrise; Day otherwise
    case matchSystem  // Night when iOS is in Dark mode
}

	•	Default: afterDark. Without location (until the After dark scheduler lands), the window is fixed hours: 9:00 PM → 6:30 AM.
	•	Match iPhone leaves the colour scheme to iOS; the other choices pin it (Day = light, Night = dark).
	•	The palette (PSPalette) and type scale (PSType) are injected through the SwiftUI environment (psPalette, psType) from the app root. Views never hard-code colours.
	•	v1 settings migrate once: theme light → Day, dark → Night, system → Match iPhone; sleepBrightness normal / dim / extraDim → glow 55 / 30 / 18; the active display profile (the bedtime profile when bedtimeMode is on) then sets glow = (1 − dimness) × 60 and warmth; theme sleep or bedtimeMode → Night with the Lights out preset, unless hasCalibratedDisplay, when the profile wins; autoCheckMistakes true → Right away, false → When I check; autoRemoveCandidates → tidyNotes; hasCalibratedDisplay → calibrated.

7.2 Visual Rules
	•	Day palette (fixed): bg #F4F1E9, surface #EBE6DA, surface2 #E2DCCD, ink #1B1A17, ink2 #57534B, ink3 #8A857A, accent #9A5712, accentDim #C9A27A, line #CFC8B8 (Clarity Large/Bold: #B9B1A0), lineMajor #2E2B25, hair #D8D1C1, sel #EFD9B0, peer #ECE6D9, same #F1E2C6, err #B3261E.
	•	Night palette (computed from glow, warmth and Clarity; never hard-coded):
	•	K = warmth mapped 6500 → 1200 K, interpolated in mireds, rounded to 50 K. Warmth 0 / 45 / 75 / 100 = 6500 / 2200 / 1500 / 1200 K.
	•	base = blackbody colour of K (Tanner Helland approximation). accent = blackbody of warmth × 0.55 + 52.
	•	s = floor + (1 − floor) × (glow / 100)^1.15, with floor 0.20 / 0.30 / 0.38 for Clarity Standard / Large / Bold. Increase Contrast uses the Bold floor.
	•	bg is always #000 (OLED pixels off). Every other token is base or accent times a fixed share of s (Design/v2/README.md, “Night palette”).
	•	Never use a black overlay to dim; it dims everything by the same amount and makes small marks unreadable first.
	•	Night rules: no filled shapes behind text; primary buttons are outlines (1.5 pt accentDim stroke, accent text); cards are transparent with a 1 pt hair border.
	•	Every state must show by shape or weight, not hue alone (Day and Night):
	•	Selection: a filled background plus a heavier outline.
	•	Error: an underline bar plus the err colour.
	•	Hint roles: rings for evidence and targets, strike-through for eliminations.

7.3 Grid Interaction Visuals
	•	Selecting a cell:
	•	Highlight its background, row, column, box.
	•	Selecting a number:
	•	Highlight all cells with that number.
	•	Duplicate entry:
	•	With Show mistakes set to Right away:
	•	Immediately mark conflicting cells as error (error marker, see 7.2).
	•	Hint highlights (phase 3):
	•	Fade in slowly (about 0.3 s). Never blink or pulse.
	•	Stay until the player moves to another rung or closes the panel.

Testing requirements:
	•	Unit tests:
	•	Appearance is persisted and restored; v1 settings migrate (Section 7.1).
	•	Night palettes for the three presets match the Design/v2/styles.css snapshots within ±1 per channel.
	•	Kelvin for warmth 0 / 45 / 75 / 100 is 6500 / 2200 / 1500 / 1200.
	•	UI tests (basic):
	•	Switch theme to Dark and verify at least that background or some key UI element changes (sanity check).
	•	Show mistakes: place a conflicting number and verify visual error (e.g., presence of an error indicator).

⸻

8. Persistence & Local Storage

All persistence must be local and offline. Use:
	•	Either UserDefaults or local JSON files via FileManager and Codable.

Persist:
	1.	Active games (per difficulty):
	•	GameState for Easy, Medium, Hard.
	•	Save on:
	•	Every few seconds (debounced).
	•	When app goes to background.
	•	When user leaves GameView.
	2.	Settings (v2, Section 7.1):
	•	appearance, glow, warmth, clarity, glowFloor, calibrated
	•	drift, hideStatusBarInGames, useLocationForAfterDark, afterDarkStart, afterDarkEnd
	•	soundsEnabled, hapticsEnabled
	•	mistakes, tidyNotes, showTimer
	•	cell-name style, “try it yourself first”
	•	keepImportImages
	•	v1 keys (theme, bedtimeMode, sleepBrightness, display profiles, autoCheckMistakes, autoRemoveCandidates) are read once and mapped (Section 7.1), never written.
	3.	Technique progress (phase 5): one TechniqueProgress per technique (Section 2.3).
	4.	Imported games (BYOS.md).
	5.	Stats:
struct Stats: Codable {
    var totalPuzzlesSolved: Int
    var puzzlesSolvedByDifficulty: [Difficulty: Int]
    var bestTimeByDifficulty: [Difficulty: Int?] // seconds
    var totalSecondsPlayed: Int
    var currentStreakDays: Int
    var lastSolvedDate: Date?
}

Streak rules:
	•	Puzzle completed without usedReveal:
	•	Update counts.
	•	Update best time, only if usedHint is also false (Section 6.3).
	•	Add to totalSecondsPlayed.
	•	Streak logic based on lastSolvedDate vs. today.

Testing requirements:
	•	Unit tests:
	•	Stats streak logic:
	•	Solve on day N (no previous): streak = 1.
	•	Solve again on day N+1: streak = 2.
	•	Skip day N+2, solve on N+3: streak resets to 1.
	•	Best time logic: solving faster updates best; slower does not.
	•	A faster solve with usedHint does not update best time, but does update counts and streak.
	•	Persistence:
	•	Save a GameState and Stats to storage and reload; verify equality.
	•	UI tests:
	•	Solve a very simple puzzle (you can pre-wire a nearly complete puzzle for UITest), then return to main menu and verify stats (e.g., “Total puzzles solved” increased).

⸻

9. Validation & Non-Functional Requirements
	•	Performance:
	•	App should launch quickly.
	•	Interactions must feel instantaneous.
	•	Offline-only:
	•	App must work completely without network.
	•	Testability:
	•	Sudoku engine and view models must be unit-testable without UI.
	•	Minimize logic in SwiftUI views; move it to view models.
	•	Hint latency: a hint (one solver step) must be ready within 50 ms on the oldest supported iPhone. Grading a puzzle may take longer but must run off the main thread.
	•	Hint correctness (phase 2 onward): no hint may ever remove a correct candidate or place a wrong digit.
	•	Accessibility:
	•	Support Dynamic Type, including candidate marks (with a minimum size).
	•	Color contrast:
	•	Day: at least 4.5:1 for digits and text, 3:1 for grid lines and large or bold text.
	•	Night: the player chooses the glow, and it may go below 4.5:1 (a dark room needs less contrast, and this is the player’s own choice). The Clarity floor still applies (ink at least 20% / 30% / 38% of the full blackbody colour).
	•	Night with iOS Increase Contrast on: the palette uses the Bold floor and line lift.
	•	If iOS Bold Text or Increase Contrast is on, raise the app’s weight and contrast floors.
	•	VoiceOver can play a full game (phase 6): each cell reads its row, column, value or candidates, and hints read their explanation.
	•	Code organization:
	•	Keep engine / models / view models in separate groups or modules.

Testing requirements:
	•	Unit tests:
	•	At least:
	•	SudokuValidator tests.
	•	GameViewModel tests (input, check, reveal, reset, completion).
	•	Stats streak & time tests.
	•	Persistence round-trip tests.
	•	Solver correctness oracle (phase 2 onward): run the logical solver step by step over a seeded corpus of puzzles (400 generated in phase 2; bundled pre-graded puzzles from phase 4). Every elimination and placement is checked against the known solution. Zero failures allowed.
	•	Hint latency: an XCTest measure benchmark for one hint on a hard board, with a simulator baseline that fails the test on a large regression. Each release also gets a manual on-device check on the oldest supported iPhone (iPhone 8 for iOS 16).
	•	UI tests:
	•	Core happy paths:
	•	Launch → Easy → enter a few cells → back.
	•	Launch → Hard → toggle notes mode → add candidate → reset.
	•	Verify the app does not crash and key elements are present.

⸻

10. Suggested File / Type Overview
	•	Models/
	•	Difficulty.swift
	•	SudokuCell.swift
	•	SudokuPuzzle.swift
	•	GameState.swift
	•	Stats.swift
	•	Settings.swift
	•	Theme/
	•	NightPalette.swift (Appearance, Clarity, PSType, PSPalette, Blackbody, NightPreset)
	•	Engine/
	•	SudokuValidator.swift
	•	SudokuPuzzleRepository.swift
	•	(Optional) SudokuGenerator.swift
	•	Logical solver (phase 2 onward, Section 13.3), in the Engine group:
	•	SolverBoard.swift (bitset board, House)
	•	TechniqueStep.swift (Technique, TechniqueStep, explanation text)
	•	LogicalSolver.swift (nextStep / solve loop, tie-break)
	•	Detector files by family: SinglesAndIntersections.swift, SubsetDetector.swift, FishAndWings.swift (phase 2); later phases add SingleDigitPatterns, Coloring, Uniqueness, Chains, ALS
	•	PuzzleGrader.swift (phase 4)
	•	DrillIndex.swift (phase 4)
	•	ViewModels/
	•	GameViewModel.swift
	•	MainMenuViewModel.swift
	•	SettingsViewModel.swift
	•	StatsViewModel.swift
	•	Views/
	•	MainMenuView.swift
	•	GameView.swift
	•	SudokuGridView.swift
	•	CellView.swift
	•	NumberPadView.swift
	•	SettingsView.swift
	•	StatsView.swift
	•	HintPanelView.swift (phase 3)
	•	DisplayCalibrationView.swift (phase 3)
	•	LearnView.swift, LessonView.swift (phase 5)
	•	Persistence/
	•	PersistenceManager.swift (or similar).
	•	Tests/
	•	PureSudokuTests/:
	•	Tests for engine, models, view models, stats, persistence.
	•	PureSudokuUITests/:
	•	Tests for main flows and basic visual behavior.

⸻

11. Implementation Order (for You, the Coding AI)

Please implement in this order:
	1.	Models & Difficulty enum (+ unit tests for basic behaviors).
	2.	Sudoku puzzle repository (JSON-based) (+ unit tests for loading and validation).
	3.	Sudoku validator (row/col/box checks, isCompleted) (+ unit tests with valid/invalid grids).
	4.	GameState management & GameViewModel (+ unit tests for input, check, reveal, reset).
	5.	Timer logic and pause behavior (+ unit tests simulating elapsed time).
	6.	GameView with grid, number pad, normal vs candidate mode (+ UI tests for tap flows).
	7.	Check / Reveal / Reset / New Puzzle actions (+ unit + some UI tests).
	8.	Persistence for game state, settings, and stats (+ unit tests for save/load).
	9.	MainMenuView with difficulty buttons and stats summary (+ UI tests).
	10.	Theme support and settings screen (+ basic UI tests for theme toggle).
	11.	Bedtime / Partner-Friendly Mode behavior (Section 12) (+ manual & automated tests).
	12.	Teaching and hints, in the phases of Section 13.6. Each phase ships on its own and keeps the app working.

⸻

12. Bedtime / Partner-Friendly Mode (“No Elbow Mode”)

PureSudoku must be comfortable to use in bed, next to a sleeping partner, without disturbing them (i.e., avoid “getting an elbow”). This implies strict constraints on brightness, animations, sound, and interaction patterns.

12.1 Bedtime Usage Goals
	•	The app should:
	•	Emit minimal light (especially blue light).
	•	Produce no sound and no haptics by default.
	•	Avoid sudden bright flashes, animations, or popups.
	•	Be usable one-handed (thumb-only) when lying on one side.
	•	The user should be able to:
	•	Open the app and resume a puzzle in Sleep mode in 1–2 taps.
	•	Play for a while and put the phone down instantly without extra prompts or dialogs.

12.2 Default Silent Behavior
	•	Sounds:
	•	The app must be completely silent by default:
	•	No click sounds on key presses.
	•	No “success” chimes when finishing a puzzle.
	•	No error beeps.
	•	If you add sounds later, they must be off by default and controlled via a Settings toggle.
	•	Haptics / Vibration:
	•	No haptics by default.
	•	If added later, haptics must also be off by default and controlled via Settings.

Testing requirements:
	•	Manual / UI test:
	•	Launch app on a device with volume ON and system haptics ON.
	•	Interact with:
	•	Number pad
	•	Check / Reveal / Reset
	•	Verify: no sound and no vibration occur.

12.3 Night screen (Glow, Warmth, Clarity)

Night replaces the v1 Sleep theme, Bedtime Mode and display profiles.
Why: total light, not colour, is what affects sleep, and people differ widely. So brightness (Glow) and colour (Warmth) are separate continuous controls, and Clarity trades a higher floor for readability.
	•	Glow 0–100: how much light the screen gives off. Implemented in two layers:
	1.	While the app is in front in Night, set UIScreen brightness to its minimum. Restore the player’s brightness when the app goes to the background. Keep it low while inactive (Control Center), so it does not flash up.
	2.	Below the hardware minimum, the palette’s luminance scale (Section 7.2) does the rest.
	•	Warmth 0–100: colour temperature 6500 → 1200 K. Warmth is a comfort setting. The app must not claim that warm colours protect sleep.
	•	Clarity: Standard / Large / Bold. Bigger, heavier digits and stronger lines, and a higher Night floor.
	•	Presets: Reading lamp (glow 55, warmth 45), Lights out (18, 75), Red light (10, 100). A preset never sets glow below glowFloor.
	•	glowFloor and calibrated are stored for the first-night “Find my lowest glow” flow (a later v2 phase).
	•	Limits the app must respect: it cannot go below the system brightness minimum, cannot read room light, and cannot turn on Reduce White Point.

Testing requirements:
	•	Unit tests: palette snapshots, Kelvin mapping, Clarity floor, v1 migration, brightness lowered only in Night and restored afterwards.
	•	Manual test: with Night on at minimum system brightness, no filled area anywhere renders brighter than ink, including sheets and menus.

12.4 Calm Visual Design (No Sudden Flashing)
	•	Animations:
	•	Avoid rapid, attention-grabbing animations.
	•	Use only subtle fades/scale where necessary (e.g. presenting menus).
	•	Errors / conflicts:
	•	Error indication must be subtle:
	•	Use a small red outline or corner marker.
	•	No large full-screen flashes.
	•	No rapid blinking.
	•	Dialogs:
	•	Confirmation dialogs (Reset, New Puzzle, Reveal Puzzle) should:
	•	Reuse a dark/sleep palette in Sleep mode.
	•	Not flash bright backgrounds.
	•	Hint panel and lessons (phase 3 onward):
	•	Highlights fade in slowly; nothing blinks.
	•	The panel never advances on its own. Every step waits for a tap.
	•	One or two short lines per step, with “More” for detail.
	•	Puzzle completion: a slow fade, no bright burst.

Testing requirements:
	•	Manual test:
	•	In Sleep mode, trigger:
	•	Check Puzzle with errors.
	•	Reset Puzzle, New Puzzle, and Reveal Puzzle dialogs.
	•	Verify:
	•	No bright white flash.
	•	No flashing/blinking animations.

12.5 One-Handed / In-Bed Ergonomics

Design with thumb-only use in mind:
	•	Layout:
	•	Sudoku grid centered, but main controls near the bottom of the screen:
	•	Number pad at bottom edge.
	•	Mode toggle (Normal / Notes) adjacent to number pad.
	•	Common actions (Hint, Check, Reset) in a bottom toolbar or easily reachable area.
	•	Hint panel buttons (Back, Next, Apply, Done) in the bottom thumb zone.
	•	Tap targets:
	•	Minimum hit size ~44×44 points for all interactive elements (Apple HIG).
	•	Gestures:
	•	Primary interactions must be simple taps.
	•	Avoid complex gestures (e.g. long-press + drag combos) as required controls.

Testing requirements:
	•	Manual ergonomic test:
	•	On a typical iPhone (e.g. 6.1” device), hold in one hand and:
	•	Tap cells across the board.
	•	Use number pad, switch Normal/Notes, hit Check and Reset.
	•	Confirm all essential actions are reachable with thumb from a natural “bed grip”.

12.6 Quick Exit and Resume
	•	Resume:
	•	When user opens PureSudoku:
	•	If there is an incomplete puzzle for any difficulty, the main menu appears quickly.
	•	From main menu, going back into the last difficulty should be instant (no loading spinners).
	•	Exit:
	•	No blocking dialogs when:
	•	Hitting the Home indicator / backgrounding the app.
	•	Locking the device.
	•	Game state autosaves quietly.

Testing requirements:
	•	Unit/UI tests:
	•	Start a game, make a couple of moves, background the app, then foreground:
	•	Verify the grid state and elapsedSeconds resumed correctly.
	•	Ensure no modal dialog appears on resume unless absolutely necessary.

12.7 Night shortcut and silence
	•	Bedtime Mode is replaced by Night (Section 7.1). A toggle on the main menu switches between Day and Night.
	•	When Night is active:
	•	Sounds and haptics are off at runtime, whatever the saved settings say (the saved choice is kept for Day).
	•	Force dark appearance for every screen, including sheets the app presents. Avoid system views that cannot be themed dark (they flash white).
	•	Screen brightness is lowered (Section 12.3).
	•	The launch screen is black in every mode (iOS shows a static launch screen).

Testing requirements:
	•	Unit tests:
	•	With Night active, soundsActive and hapticsActive are false, the palette is the Night palette and the colour scheme is dark.
	•	UI tests:
	•	Turn Night on from the main menu and open a game.

⸻

13. Teaching & Hints (“Learn to solve, not just fill”)

PureSudoku teaches the solving techniques from the Sudoku literature. A hint teaches the next idea, not the next digit. The research behind this section is in docs/research/sudoku-hint-and-teaching-design.md.

13.1 Goals
	•	Every hint names a real technique and shows why it works on the player’s own board.
	•	The board changes only when the player chooses (Apply).
	•	Help fades as the player masters a technique. Full worked examples help beginners but slow experts down.
	•	All teaching content follows the bedtime rules of Section 12.

13.2 Curriculum
	•	Four tiers: Basic, Intermediate, Advanced, Expert. The full ordered list, with a short definition and score for each technique, is in HINT_STRATEGIES.md. That file is the source of truth for technique order.
	•	The solver tries techniques in that order, so the simplest available step is always found first.
	•	Some ideas are taught as short concept lessons before the techniques that need them: candidates, strong link, bivalue cell, almost locked set.
	•	Out of scope: Exocet, Franken/Mutant/Kraken fish, templates, Nishio, Bowman’s Bingo, brute force.

13.3 Logical solver (phase 2)
	•	A new solver beside the existing generator solver. It solves like a person, one step at a time.
	•	nextStep(board) -> TechniqueStep?: tries each technique in curriculum order and returns the first step it finds. The caller applies it and asks again. This one loop drives hints, grading and drills.
	•	TechniqueStep (Codable value type) holds:
	•	technique and tier.
	•	placements (cell, digit) and eliminations (cell, digit).
	•	houses, each with a role (base or cover).
	•	pattern cells, each with a role (defining, fin, pivot, pincer).
	•	links (from, to, strong or weak) for chains.
	•	explanation text, generated from the step’s own data by one template per technique (the technique is the template key; the step’s digits, houses and cells are its arguments). Testable, and translatable later.
	•	Board: a 9-bit candidate mask per cell, static peer and house tables. (Per-digit cell sets can be added if a later technique needs the speed.)
	•	Deterministic: within a technique, prefer the instance with fewest pattern cells, then most eliminations, then lowest cell index. Never depend on Set or Dictionary order.
	•	Steps stack: after each step, the next search starts from the updated candidates.
	•	Uniqueness techniques run only when hasUniqueSolution is true (Section 2.1).
	•	If no technique applies, return nil. The hint then offers Reveal Cell (Section 6.3); it never guesses.
	•	Which engine feeds hints:
	•	Phases 1–2: the current SudokuHintEngine (current behavior).
	•	From phase 3: the logical solver. By then it covers every technique the old engine handles correctly (phase 2). The old engine’s XY-Chain (buggy) and Bowman’s Bingo (trial and error) are dropped; boards that needed them get the honest “Reveal this cell?” fallback until phase 6.
	•	SudokuHintEngine is deleted in phase 3.
	•	Known issues in the current engine that the new solver must not repeat:
	•	Each technique starts again from the original candidates, so steps do not stack.
	•	A hint carries only a target cell and a message, so the pattern cannot be shown.
	•	XY-Chain only eliminates when the chain’s end sees its start; the rule is any cell that sees both ends.
	•	The last resort (Bowman’s Bingo) can return no hint.

13.4 Mastery
	•	A technique is mastered when the player has found it without a hint in 3 different puzzles on 3 different days. “Found” means: on the board just before the player’s move (a correct placement, or removing a wrong note), some step of some technique makes exactly that change, and no hint for that technique was shown in this puzzle, and the board has no mistake. The credit goes to the simplest such technique (curriculum order). Checking every step, not only nextStep’s first, lets techniques like Naked Single earn credit even when another single comes first. The check runs off the main thread.
	•	Each technique has a strength value (0–1) that decays over time (half-life model). Strength rises when found unaided and falls when a hint for it is needed.
	•	When strength falls low, the Learn screen offers an optional review drill. No streak alarms, no notifications.

13.5 Learn screen (phase 5)
	•	Opened from the main menu. Shows the four tiers and each technique’s state (new, learning, mastered).
	•	One lesson per technique, built on a single example on a real board. No catalogs of variants.
	•	Each lesson ends with three practice puzzles that need that technique (from the drill index).
	•	Practice puzzles are not saved and do not count toward stats or the streak; they do count toward learning (mastery and strength).
	•	The example board is a bundled puzzle solved up to the first step of that technique, drawn like a hint: pattern first, then the result on “Show the result”.
	•	The first time a puzzle needs a technique the player has not seen, the hint offers that lesson.

13.6 Build phases
Each phase ships on its own and keeps the app working.
	1.	Spec (this section, CODESPEC updates, HINT_STRATEGIES.md, BYOS.md uniqueness rule).
	2.	Engine core: SolverBoard, TechniqueStep, LogicalSolver; Basic and Intermediate tiers including hidden subsets; X-Wing, Swordfish and XY-Wing (ported from the old engine, so nothing it does correctly is lost); deterministic order; honest last resort; correctness oracle and latency benchmark in the test suite.
	3.	Hint ladder and display calibration: Section 6.3 rungs 0–4, Apply with Undo, Reveal Cell separate, autoFillHints removed; Section 12.3 calibration and profiles.
	4.	Grading and drills: logical grade per puzzle (Section 2.2), technique lines under difficulty buttons, no silent fallback, bundled pre-graded puzzles and drill index, solution count on import.
	5.	Advanced tier and Learn: the rest of the Advanced tier (single-digit patterns, XYZ-Wing, W-Wing, simple coloring, uniqueness techniques, gated); Learn screen, lessons, mastery and fading.
	6.	Expert tier and polish: chain link graph, X-Chain, AIC, grouped AIC, ALS-XZ, ALS-XY-Wing, Sue de Coq; optional Expert difficulty; full VoiceOver play.

Testing requirements:
	•	Unit tests (phase 2):
	•	Hand-made boards for the elimination techniques (phase 2: Pointing, Claiming, Locked Pair/Triple, Naked Pair/Quad, Hidden Quad, X-Wing, Swordfish, XY-Wing): the detector returns exactly the expected eliminations (catches a detector that finds too few). Hidden Pair/Triple and Naked Triple rely on the corpus oracle.
	•	Correctness oracle: over a seeded corpus of generated puzzles (400 in phase 2; bundled pre-graded puzzles from phase 4), every step agrees with the known solution and its pattern is re-checked against the board.
	•	Same board, same step, every run.
	•	A board needing two techniques in a row (e.g. pointing, then a naked pair) yields both steps in order.
	•	Unit tests (phase 5): mastery rule (3 puzzles, 3 days), strength decay, fading opens a mastered technique at rung 1.
