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
No accounts, no login, no backend, no ads (for now).
Focus on:
Fast launch.
Instant responsiveness to taps.
Clean, readable UI.
The app must support bedtime / partner-friendly use with a special Sleep theme and Bedtime Mode (see Section 12).
Testing requirements:

Unit test: logic for “continue existing game vs. create new game” per difficulty.
UI test: tapping each difficulty on main screen should navigate to a game and show a 9×9 grid.
2. Core Gameplay Requirements
2.1 Sudoku Basics
Standard 9×9 Sudoku:
Each row, column, and 3×3 subgrid must contain all digits 1–9 exactly once.
Each puzzle:
Has a unique solution.
Has a preset difficulty: .easy, .medium, .hard.
Testing requirements:

Unit tests:
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

Testing requirements:
	•	Unit tests:
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
	•	A small section showing:
	•	Current streak (“Streak: N days”).
	•	Total puzzles solved.
	•	Optional total time spent.
	•	A settings icon to open SettingsView (for theme, toggles, Bedtime Mode, etc.).
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
	•	Hint
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

Testing requirements:
	•	UI tests:
	•	Start an Easy game, tap a cell, tap a number; verify the cell displays that number.
	•	Toggle Notes mode, tap another cell, tap a number; verify smaller candidate text appears in that cell.
	•	Tap Reset Puzzle and verify that user-entered values and candidates are cleared.

3.3 Settings & Stats Screen
	•	SwiftUI view: SettingsView and StatsView (can be separate or combined).
	•	Settings includes:
	•	Theme: System, Light, Dark, Sleep (low blue light).
	•	Toggles:
	•	Show timer on/off.
	•	Auto remove candidates.
	•	Auto-check mistakes.
	•	Bedtime Mode (see Section 12).
	•	Stats includes:
	•	Current streak.
	•	Best times per difficulty.
	•	Puzzles solved per difficulty.
	•	Total puzzles solved.
	•	Total time spent.

Testing requirements:
	•	Unit tests:
	•	Changing a setting (e.g. showTimer, theme, bedtimeMode) in the view model should persist and reload correctly.
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

6.3 Hint / Reveal Cell

For MVP, treat Hint as “Reveal one cell”:
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

⸻

7. Theme & UI Modes

7.1 Theme Settings

Implement:
enum AppTheme: String, Codable {
    case system     // follow system light/dark
    case light
    case dark
    case sleep      // low-blue-light mode for bedtime use
}

	•	In SettingsView, allow user to choose theme.
	•	Apply theme globally via environment and a central theme manager.
	•	AppTheme.sleep is optimized for in-bed, partner-friendly use and is also used by Bedtime Mode (Section 12).

7.2 Visual Rules
	•	Light Mode:
	•	Background: light (white/off-white).
	•	Grid lines: dark gray.
	•	Given numbers: bold, dark.
	•	User numbers: normal weight.
	•	Dark Mode:
	•	Background: dark gray or near-black.
	•	Grid lines: light gray.
	•	Text: off-white.
	•	Sleep Mode (low blue light):
	•	Background: very dark.
	•	Use warm colors (amber/orange) for accents instead of blue.
	•	Avoid pure white; use dim off-white or warm light text.
	•	No bright full-screen flashes or highly contrasting popups.
	•	Integrates with Bedtime / Partner-Friendly Mode (extra dimming, silent behavior).

7.3 Grid Interaction Visuals
	•	Selecting a cell:
	•	Highlight its background, row, column, box.
	•	Selecting a number:
	•	Highlight all cells with that number.
	•	Duplicate entry:
	•	With autoCheckMistakes enabled:
	•	Immediately mark conflicting cells as error (red indicator).

Testing requirements:
	•	Unit tests:
	•	Theme selection is persisted and restored.
	•	UI tests (basic):
	•	Switch theme to Dark and verify at least that background or some key UI element changes (sanity check).
	•	autoCheckMistakes: place a conflicting number and verify visual error (e.g., presence of an error indicator).

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
	2.	Settings:
	•	AppTheme
	•	showTimer
	•	autoRemoveCandidates
	•	autoCheckMistakes
	•	bedtimeMode flag
	3.	Stats:
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
	•	Update best time.
	•	Add to totalSecondsPlayed.
	•	Streak logic based on lastSolvedDate vs. today.

Testing requirements:
	•	Unit tests:
	•	Stats streak logic:
	•	Solve on day N (no previous): streak = 1.
	•	Solve again on day N+1: streak = 2.
	•	Skip day N+2, solve on N+3: streak resets to 1.
	•	Best time logic: solving faster updates best; slower does not.
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
	•	Accessibility:
	•	Support Dynamic Type where reasonable.
	•	Ensure color contrast in all themes.
	•	Code organization:
	•	Keep engine / models / view models in separate groups or modules.

Testing requirements:
	•	Unit tests:
	•	At least:
	•	SudokuValidator tests.
	•	GameViewModel tests (input, check, reveal, reset, completion).
	•	Stats streak & time tests.
	•	Persistence round-trip tests.
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
	•	AppTheme.swift
	•	Engine/
	•	SudokuValidator.swift
	•	SudokuPuzzleRepository.swift
	•	(Optional) SudokuGenerator.swift
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

12.3 Extra-Dim Sleep Mode

Extend the existing AppTheme.sleep behavior:
	•	In Sleep theme:
	•	Use very dark backgrounds and warm accent colors (amber/orange).
	•	Avoid pure white; prefer dim off-white or warm light text.
	•	Avoid high-contrast flashes (no bright full-screen modals).
	•	Add an optional in-app brightness limiter:
	•	A simple slider or a few fixed steps (e.g. Normal, Dim, Extra Dim) that only affects the app’s content (simulate with an overlay).
	•	When AppTheme.sleep is active, default the in-app brightness to the dimmest setting.

Implementation suggestion (optional):
	•	Use a semi-transparent dark overlay layer on top of all content in Sleep mode to “double dim” the app, independent of system brightness.

Testing requirements:
	•	UI tests (visual sanity checks / snapshot-ready):
	•	Enable Sleep theme and confirm:
	•	Background is dark.
	•	No pure white elements dominate the screen.
	•	Accent colors are warm (not blue).
	•	Manual test:
	•	With system brightness at ~25%, enable Sleep theme and in-app “Extra Dim”.
	•	Subjectively confirm the grid is still readable but significantly dim.

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

12.7 “Bedtime Mode” Shortcut
	•	Add a simple toggle in Settings:
	•	Bedtime Mode (boolean).
	•	When ON:
	•	Force theme to AppTheme.sleep.
	•	Force soundsEnabled == false, hapticsEnabled == false.
	•	Set in-app brightness to minimum (via overlay).
	•	Optionally, provide a shortcut on the main menu:
	•	Small icon or button, e.g. “🌙 Bedtime Mode”.
	•	Tapping it:
	•	Turns on Bedtime Mode.
	•	Immediately applies Sleep theme and dimming.

Testing requirements:
	•	Unit tests:
	•	Toggling bedtimeMode in settings forces:
	•	theme == .sleep
	•	soundsEnabled == false
	•	hapticsEnabled == false
	•	UI tests:
	•	Enable Bedtime Mode via settings and assert that:
	•	Sleep theme is active.
	•	UI re-renders with dark warm palette and dim overlay.

