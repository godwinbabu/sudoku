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
Three tabs: Play (Home), Learn and Journal (Section 3.1).
Home lists five levels: Easy, Medium, Hard, Expert, Master (phase 5 of the redesign).
Tapping a level always starts a new puzzle at that level.
A Continue card resumes the unfinished game played last.
No accounts, no login, no backend, no ads.
Focus on:
Fast launch.
Instant responsiveness to taps.
Clean, readable UI.
The app must support bedtime / partner-friendly use with a Night appearance (black canvas, Glow, Warmth, Clarity; see Section 12).
The app teaches solving techniques, not only answers (see Section 13):
The Learn tab opens the technique curriculum.
Hints name and explain a technique on the player’s own board before any cell changes.
Each level row names the hardest technique it needs (“Expert: Wings & fish”).
Expert and Master exist from phase 5: Master needs XY-Chain, the first Expert-tier technique.
Testing requirements:

Unit test: the Continue card picks the unfinished game played last; a level always starts a new game.
UI test: tapping a level on Home navigates to a game and shows a 9×9 grid (Expert included).
2. Core Gameplay Requirements
2.1 Sudoku Basics
Standard 9×9 Sudoku:
Each row, column, and 3×3 subgrid must contain all digits 1–9 exactly once.
Each puzzle:
Generated puzzles have a unique solution.
Imported puzzles (BYOS.md) need only be solvable. They may have more than one solution.
Has a preset difficulty: .easy, .medium, .hard, .expert, .master.
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
    case expert
    case master   // swiftlint:disable:next inclusive_language on the declaration
}

Old saves hold only easy, medium and hard, so they decode unchanged.

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
	•	Map grade to difficulty by the hardest technique it needs (Technique.level, phase 5):
	•	Easy: singles only (Basic tier).
	•	Medium: Pointing or Claiming, nothing harder.
	•	Hard: pairs, triples and quads (naked, hidden, locked), nothing harder.
	•	Expert: wings and fish — any Advanced technique (X-Wing, Swordfish, Skyscraper, 2-String Kite, Empty Rectangle, XY-Wing, XYZ-Wing, W-Wing, Simple Coloring, uniqueness), nothing harder.
	•	Master: chains — XY-Chain (Expert tier).
	•	Saved games keep the level they were created with.
	•	Within a level, the score orders puzzles from easier to harder.
	•	No silent fallback: a puzzle is only offered at the level its grade maps to. If generation cannot find one in time, use a bundled pre-graded puzzle of that level.
	•	Generation runs off the main thread and tries up to 30 puzzles (about 13 ms each on a Mac, generating and grading). Measured on 400 seeded puzzles with five levels (redesign phase 5): 43% Easy, 15% Medium, 5% Hard, 14% Expert, 8.5% Master, 14.5% need a technique beyond XY-Chain (discarded). So 30 tries find Expert about 99% of the time, Master about 93% and Hard about 80%; otherwise a bundled puzzle is used.
	•	Bundled: 120 pre-graded, unique-solution puzzles per level, 600 in all (BundledPuzzles.swift, generated offline with this app’s generator; no licence applies). They also serve as practice drills, indexed by technique.
	•	An import the logical solver can’t finish gets Master and no grade.
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
	•	A puzzle that needs only singles grades Easy; a known X-Wing puzzle grades Expert.
	•	Expert puzzles (generated and bundled) need an Advanced technique and no chain; Master puzzles need XY-Chain.
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

	•	Maintain one active GameState per difficulty (5 saved states, game_<level>.json).
	•	lastUpdated is set on every save; the Continue card uses it.

Additions for teaching (added in the phase that first needs them, Section 13.6):
	•	SudokuPuzzle:
	•	hasUniqueSolution: Bool (Section 2.1). Default when missing from a saved file: source == .generated. An imported puzzle saved without it gets its solutions counted (stopping at 2) the first time it loads, and the result is saved.
	•	grade: PuzzleGrade? (hardestTier, score, techniques; Section 2.2). Nil for puzzles saved before grading existed.
	•	GameState:
	•	hintLog: [HintLogEntry] — one entry per hint: technique, deepest step shown (1–3; older saves hold rungs 0–4), whether its action was used.
	•	hints: Int — hints opened in this puzzle (hintLog.count), for the Solved summary.
	•	assisted: Bool — true once a hint placed a digit or removed candidates (Section 6.3.1). Saves from before this field decode the old usedHint key into it.
	•	TechniqueProgress (new model, one per technique):
	•	foundUnaidedCount: Int, foundUnaidedDays: Set<day>, lastSeen: Date?, strength: Double (0–1, decays over time).
	•	All new fields decode with defaults (decodeIfPresent), so older save files still load. This applies to every persisted model: SudokuPuzzle, GameState, Settings, Stats and TechniqueProgress. A strict decode of a new field would make the old file fail to load and be moved aside, losing the player’s settings.

Testing requirements:
	•	Unit tests:
	•	Decode a GameState and SudokuPuzzle saved without the new fields; verify defaults (empty hintLog, assisted == false; an old usedHint == true becomes assisted, grade == nil, hasUniqueSolution == true for generated).
	•	An imported two-solution puzzle saved without hasUniqueSolution loads as false.
	•	Settings and Stats files saved by the previous version load without errors, with defaults for new fields.
	•	Construct a GameState from initialGrid and solutionGrid and verify:
	•	Exactly 81 cells.
	•	given and value are set correctly based on initialGrid.
	•	Encode and decode GameState using Codable and ensure equality (round-trip test).

⸻

3. Screen & Navigation Structure

3.1 App structure and Home
	•	MainMenuView holds three tabs: Play (HomeView), Learn (LearnView) and Journal (JournalView). Each tab has its own NavigationStack.
	•	The tab bar is drawn by the app (PSTabBar), not the system, so it stays dark at night: bg fill, 1 pt hair top border, Play (square.grid.3x3), Learn (book), Journal (chart.bar). The active tab is accent with a semibold label; the others are ink3. The selected tab also carries the selected trait.
	•	The tab bar belongs to each tab’s root screen, so anything pushed (a game, a lesson, Import, Display & Night) covers it.
	•	Each tab’s header has the serif title and the moon, which opens the Night sheet (Section 12.7). Import has the moon in its bar.
	•	No system sheets, alerts, context menus or confirmation dialogs: Display & Night and lessons are pushed; confirmations are custom popovers. The camera and the Photos picker on Import are the only system screens left, and each opens only after an explicit tap (Section 3.4).
	•	At night the status bar is hidden on every screen but the game, which follows Hide status bar in games (Section 3.2).
	•	Home, top to bottom (Design/v2/README.md, “Play tab”):
	•	“Pure Sudoku” and the moon; the sub-line “Saturday night · 6-night streak” (the part of the day; the streak only when it is above zero).
	•	Continue card, only when an unfinished level game exists: a 112 pt mini board (lines and digits, no fills), “CONTINUE”, the level, “6:52 · 44 of 81” and a 3 pt progress bar. It resumes the game saved last (lastUpdated).
	•	NEW PUZZLE: five 64 pt rows, one per level. Each has a tier glyph (five rising bars, the first N lit; the level name beside it carries the meaning), the level name over its hardest technique (“Singles only”, “Pointing & claiming”, “Pairs & triples”, “Wings & fish”, “Chains & beyond”), the best time when there is one, and a chevron.
	•	“Import a puzzle from a photo” (44 pt).
	•	Saved imports: unfinished imports, most recently played first. A trash button asks first, with a custom confirmation.
	•	Behavior:
	•	Tapping a level always starts a new puzzle at that level. If an unfinished game with player entries (digits or notes) is saved at that level, a custom confirmation asks first: “Replace your unfinished Hard game?” with Continue (resume it) and New. Only one game per level is saved, so this is the player’s way back to older games too.
	•	The Continue card opens the saved game as it was.
	•	Goodnight from any game returns to Home.
	•	Learn (Section 13.5) is a plain scroll view, not a List, so no system chevrons or separators show. Disclosure chevrons are drawn in palette colours.

Testing requirements:
	•	UI tests:
	•	Launch shows the five level rows, each with its technique line; there is no Night bar.
	•	The tabs switch, and each tab has the moon.
	•	Home starts an Expert game; back on Home, the Continue card resumes it with its entry.
	•	A level with an unfinished game asks first; Continue resumes it, New starts a different puzzle; a level with no entries does not ask.
	•	Unit tests:
	•	The Continue card picks the unfinished game played last, never a finished one; a level always starts a new puzzle.

3.2 Game Screen
	•	SwiftUI view: GameView. Layout and sizes: Design/v2/README.md, “Game”.
	•	From top to bottom:
	•	Header (48 pt): Back; the level over the timer (tap to pause); the moon (opens the Night sheet, Section 12.2); More.
	•	Board: 3×3 boxes on a lineMajor ground, each 3×3 cells on a line ground. Line widths follow Clarity (Section 12.3). Cell states are in Section 7.3.
	•	Hint slot (124 pt): always reserved, so nothing moves. It holds the hint card while a hint is open (Section 6.3.1). Otherwise it says “Notes on — digits go in as pencil marks” while Notes is on, and warns when two of the same digit share a house (not when mistakes are set to Never).
	•	Tools: Undo, Erase, Notes (with an ON / OFF badge) and Hint. While a hint is open the Hint tool reads “Next step” and does what the card’s button does.
	•	Keypad: 1×9. Each key shows how many of its digit are left. A digit with none left fades to 28% and is disabled. In Notes mode each key shows its digit small, at its pencil-mark position.
	•	More menu (a custom popover, never a system menu): Check puzzle, Fill all notes, Restart puzzle, Hush screen. Check puzzle is left out when mistakes are set to Never, since it would mark nothing.
	•	Fill all notes writes, in every empty cell, the digits its row, column and box still allow. One Undo reverts it.
	•	Restart puzzle asks first, with a custom confirmation styled like the menu.
	•	Paused: the board is replaced by a box with “Paused” and Resume. The timer stops.
	•	Hush: a two-finger tap anywhere, or the More menu, pauses the game and shows pure black. “Tap anywhere to return” fades out after about 3.5 s. Any tap returns and resumes.
	•	Solved: the board fades to 30% over 600 ms. Over it: “Solved.”, the level, time and hint count, a note on what the solve counts for (Practice: not counted; Revealed: not counted; Assisted: “Assisted · counts for your streak, not best times”), and the techniques the grid needs, by name: “This grid took Hidden Single ×38, Naked Single ×9.” They come from LogicalSolver.techniquesNeeded(for:), which replays the hint engine from the givens once, off the main thread. Buttons: Another (a new puzzle at this level; imports and practice go back) and Goodnight.
	•	Goodnight: pure black with “Sleep well.” fading out. A tap returns to Home.
	•	In a Night game the status bar is hidden (hideStatusBarInGames) and the home indicator auto-hides.
	•	Drift (Section 12.3) applies to the game's palette while Night and the Drift setting are on.
	•	Interaction:
	•	Tap a cell to select it.
	•	Tap a number to either:
	•	Fill value (Notes off).
	•	Toggle candidate (Notes on).
	•	Hint card (Section 6.3.1): it fills the hint slot. The board, tools and keypad keep their place. While it is open the grid shows the hint’s marks (Section 7.3) and no selection.
	•	Check Cell, Reveal Puzzle and the in-game New Puzzle button are not on the v2 game screen. Their GameViewModel behaviour (Sections 6.1, 6.4, 6.6) stays.

Testing requirements:
	•	UI tests:
	•	Start an Easy game, tap a cell, tap a number; verify the cell displays that number.
	•	Toggle Notes mode, tap another cell, tap a number; verify smaller candidate text appears in that cell.
	•	Restart the puzzle from the More menu and verify that user-entered values and candidates are cleared.
	•	The Notes badge reads Off, then On, then Off.
	•	A two-finger tap shows Hush; a tap returns.
	•	Unit tests:
	•	A digit's keypad count drops as it is placed; at zero its key is disabled.
	•	Fill all notes keeps each cell's answer, skips digits a peer holds, and is one Undo.

3.3 Journal (stats and settings)
	•	SwiftUI view: JournalView (Design/v2/README.md, “Journal”). It replaces the old SettingsView and StatsView.
	•	Streak: the current streak (NY 56, zero once a whole day passes without a solve) over “nights in a row”, and this week’s seven days, Monday first. A day with a counted solve is a filled dot; other days are rings, so shape carries it, not hue. VoiceOver reads the full weekday (“Tuesday, solved”). Stats files from before the week seed it with the last solve day.
	•	SOLVED: a table of level, Solved, Best and Typical. Typical is the median of the last 50 unassisted solve times at that level. A dash means none yet. Under it: “N assisted solves kept your streak but don’t set best times.” and “N solved in all · N imported · h:mm:ss played”.
	•	SETTINGS: a Display & Night row that pushes DisplaySettingsView. Display & Night holds, top to bottom:
	•	A live preview strip: five 52 pt cells (given 5, entered 3, selected 7, mistake 4, notes).
	•	Appearance: Day, Night, After dark, Match iPhone, with a checkmark (Section 7.1). With After dark chosen, a block shows either “Tonight · Sunset 6:12 PM → sunrise 6:41 AM” with “Worked out on this iPhone from your rough location and the date. Nothing leaves the phone.”, or “Hours · 9:00 PM → 6:30 AM” with − / + buttons (15-minute steps). A chip switches between the two (“Use fixed hours instead” / “Use sunset and sunrise”).
	•	Night screen: presets, Glow and Warmth (Section 12.3).
	•	Your eyes: Clarity; Lowest readable glow (“Set at N%. Glow and Drift never go below it.”) with Check again.
	•	Quiet: Drift; Hide status bar in games; Sounds; Vibration (“Night always keeps sound and vibration off.”). Then a footnote about Hush.
	•	Every control is drawn from the palette (custom segments, switches and sliders), never a system control that could render light.
	•	ASSISTS (palette segments and switches):
	•	Show mistakes: Right away / When I check / Never. Never means no automatic marks and no Check; the hint still points at a mistake first.
	•	Tidy notes (remove a placed digit from the notes it sees).
	•	Cell names in hints (notation): “row 5, column 2” (plain, default) or “R5C2” (grid), with a line explaining the choice. Grid also names houses “R5”, “C2” and “B4”. Every hint and lesson sentence goes through the CellNotation formatter, which also picks the article (“an 8”).
	•	Show timer on/off.
	•	IMPORTS (kept from the old Settings screen): Keep import photos, and Clear imported photos, which asks first with a custom confirmation.
	•	VoiceOver reads each table row as one line: “Expert: 3 solved, best 4:12, typical 5:00”, with “none yet” for a dash.
	•	PRIVACY: “Everything stays on this iPhone. No account, no network, no analytics. Silent by design — no sounds or vibration unless you turn them on.”
	•	Migration: the old cellNameStyle key maps short → grid and long → plain. The old askBeforeHintResult key is ignored: the card has no “Try it yourself first?” step.

Testing requirements:
	•	Unit tests:
	•	Changing a setting (e.g. showTimer, appearance, glow) in the view model should persist and reload correctly.
	•	Settings files from v1 (theme, bedtimeMode, sleepBrightness, display profiles, autoCheckMistakes, autoRemoveCandidates) load and map to the v2 fields (Section 7.1).
	•	cellNameStyle migrates to notation; askBeforeHintResult is ignored and not written back.
	•	Notation strings in both modes, including “an 8”.
	•	Journal stats: typical is the median of unassisted times; assisted solves count for the streak and counts, not best or typical; Reveal counts for nothing; one week entry per day; the streak drops to zero after a missed day.
	•	UI tests:
	•	Journal → Show timer off, then a game shows no timer (and on shows it).
	•	Journal → Display & Night shows the presets and After dark.

⸻

3.4 Import (Bring Your Own Sudoku)
	•	ImportPuzzleView is pushed from Home and covers the tab bar. It hides the navigation bar and draws its own 48 pt header: close (xmark, “Discard”) on the left, the moon on the right. It has three steps (ImportPuzzleViewModel.step), which change with a 300 ms fade (none with Reduce Motion). The flow and its rules are in BYOS.md; the look is Design/v2/README.md, “Import (BYOS)”.
	•	Source: “Import a puzzle” (serif 32) and “From a newspaper, a book or a screenshot. The photo is read on this iPhone and never uploaded.” Three option cards: Take a photo (Camera; disabled with “No camera on this device” when there is none), Choose from Photos (Screenshots work best), Type it in (Enter the givens by hand). Then “FOR A CLEAN READ” and the tips line. Cards have the surface fill in Day and only a hairline at night.
	•	Take a photo opens the camera (UIImagePickerController in a sheet). Choose from Photos opens .photosPicker(isPresented:selection:matching:). Both close when the first-night screen appears, since it is drawn at the app root and a system screen would sit above it.
	•	Reading: while the detector runs. The photo with the found grid outlined in accent, its inner box lines in accentDim, and the area outside dimmed; “Reading digits…” (serif 26); “Looking for the grid…”, then “Grid found · N of 81 cells checked”; a 3 pt progress bar (hair track, accentDim fill). At night the photo is multiplied by ink3, so it stays under ink and under its accent outline.
	•	Check the grid: after reading (even a failed read, which shows “Could not detect a clear grid. You can fill it manually.”) or Type it in. The header says “CHECK THE GRID”. The board shows every entered digit as a given. Digits whose recognised candidate (VNRecognizedText.confidence, not the observation's) scores below 0.6 are unsure and ringed (the evidence ring); tapping a ringed cell confirms it, and changing or clearing it does too. VoiceOver reads ringed cells with the value “Unsure” and the hint “Hard to read. Double-tap to confirm.”; their labels are unchanged. Conflicts get the err underline bar.
	•	Legend lines under the board: “N unsure. Ringed cells were hard to read — tap to confirm or fix.” (with a ring swatch), and for the first house with a repeated digit “Two 4s in row 4. Fix one before starting.” (with an underline swatch; the house is named in the player’s cell-name style). Without a conflict, the status line shows instead: “Add at least 10 clues to start.”, “Checking if the puzzle is solvable.”, “Puzzle is solvable.” or “This puzzle has no solution.”
	•	Under the legend, Start over (ghost) deletes the photo, empties the grid and returns to Source, for a failed or wrong read (BYOS.md, retry and reset). The board, legend and Start over scroll when they don't fit (iPhone SE); the keypad and buttons stay at the bottom.
	•	Then a 1×9 keypad (52 pt keys, no counts), Clear cell (ghost) and Start puzzle (primary). Start is disabled, at 40% opacity, until there are at least 10 clues, no conflicts and a solution.
	•	No text fields: givens are typed with the keypad, so the system keyboard never shows.

Testing requirements:
	•	Unit tests: the steps go Source → Check the grid on Type it in or a loaded grid; the conflict line names the first repeated digit and house in both cell-name styles; unsure cells clear when tapped or fixed; Start over returns to Source and deletes the photo; a photo shows Reading at once; unsure uses the candidate's confidence, and 0.6 itself is sure; conflicts block Start; the minimum clue count.
	•	UI tests: Import opens on Source with its options; Type it in → Check the grid, where two 4s in a row show the conflict line and keep Start disabled, Clear cell removes it, and Start over returns to Source.

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

6.3.1 Hint (graduated hint card, phase 3)
	•	Tapping Hint opens the hint card in the hint slot (Section 3.2) at step 1. The card’s button, or the Hint tool (“Next step”), moves one step on. × closes it without changing anything.
	•	On a card with no step-3 action, “Next step” does what the card offers: Undo on the clashing-entries card, otherwise it closes the card.
	•	Opening a hint clears the selection, and tapping a cell closes the hint, so the keypad never types into a cell the card hides.
	•	Steps 1–3 are free: they never change the board or stats.
	•	Order: the technique order follows the design’s engine.js: mistakes first, then Full House, Hidden Single (box, then row, then column), Naked Single, Pointing, Claiming, then the rest of Section 13.2 in curriculum order. Within one technique, the lowest cell wins (Section 13.3), not engine.js’s first house and lowest digit.
	•	Only the hint applies “row before column” (LogicalSolver.nextHintStep). Grading and mastery keep every step of nextStep, so a column single still earns credit.
	•	Mistake first (always checked, whatever Show mistakes is set to):
	•	A wrong digit, or a cell whose notes leave out its correct digit. Cells with no notes are never a mistake. Notes that conflict with a placed digit (stale notes) are ignored.
	•	Step 1 “Where to look”: “Something in box 4 doesn’t fit.” (the box is spotlit). Button: Show me.
	•	Step 2 “Mistake”: “The 7 in row 3, column 4 can’t be right — the puzzle doesn’t solve with it.” (dashed ring on the cell). Button: Show me why.
	•	Step 3 “Why”: the same sentence. Button: Clear it. It clears the digit (or the notes) as one undoable edit and does not mark the solve assisted.
	•	Imports whose entries fit no solution: one card, “Some of your entries don’t fit together. Try undoing recent moves.”, with Undo.
	•	Technique steps (from the logical solver, Section 13.3: the simplest step on the player’s board, using their notes where they exist; the same board always gives the same hint):
	•	Step 1 “Where to look”: the nudge, with a spotlight on the focus cells. “Look at box 4. Where can 5 go?”
	•	Step 2 “Technique” · tier: the technique name (serif) and its one-line definition. The pattern cells are filled and, in cells without notes, the candidates it relies on are shown.
	•	Step 3 “Why”: evidence rings, the dashed target with its ghost digit, struck-through eliminations. “Every other empty cell in box 4 already sees a 5. So 5 can only go in row 5, column 2.” If the player’s notes, not placed digits, rule a cell out, it reads “sees or has ruled out”.
	•	Step 3 button: “Place 5 · assisted”, or for eliminations “Remove 5 · assisted” (one digit) / “Apply · assisted”. It makes the change as one undoable edit (Section 6.7). An elimination in a cell without notes first writes that cell’s candidates as notes, so the deduction is kept and the next hint moves on.
	•	“Lesson →” (from step 2) pushes the technique’s lesson (Section 13.5); Back returns to the game. The timer stops while the game is off screen, also across a trip to the background, and runs again when the game shows.
	•	Each hint carries: nudge, technique, tier, short (definition), why, focus, evidence, pattern, elim and target (TechniqueStep and HintSession).
	•	If the solver finds no step it can explain, the card opens at step 3: “This step needs a technique beyond what hints explain yet. Placing 5 in row 5, column 2.” with “Place 5 · assisted”. It never returns nothing.
	•	Every hint opens at step 1 (the earlier fading plan, which opened new techniques at the “why” rung, is dropped).
	•	Stats:
	•	Using the step-3 button to place or remove sets assisted = true. Undo never clears it (same as usedReveal). An assisted solve counts toward puzzles solved, total time and the streak, but not toward best or typical times (Section 3.3).
	•	Reveal Cell and Reveal Puzzle keep their rule (usedReveal: the solve does not count at all).

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
	•	Hint card (phase 3):
	•	A wrong entry is the first hint; Clear it empties the cell and does not set assisted.
	•	With no notes anywhere, or stale notes only (Tidy notes off), Hint returns a technique.
	•	Each step advances the level by one, up to 3, with its label, button and marks; steps 1–3 never change the board.
	•	Placing from a hint sets assisted; one Undo reverts the board but leaves assisted set.
	•	An assisted solve updates the streak and counts but not best time.
	•	The same board gives the same hint twice.
	•	When the solver finds no step, the hint places the answer as assisted (not a reveal).
	•	Hidden singles come box, then row, then column.
	•	UI tests:
	•	Tap Hint, step through the three steps (the keypad does not move), tap Place; verify the board changed and Undo restores it.
	•	A digit repeated in its row is the first hint; Clear it empties the cell.

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
	•	“Restart puzzle” in the More menu. A custom confirmation, never a system dialog (Section 12.4).
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
	•	“Another” on the Solved panel. The puzzle is already solved, so it does not ask first.
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

	•	Default: afterDark. AfterDarkScheduler decides the window:
	•	With location (useLocationForAfterDark and a known place): sunset to sunrise, worked out on the device with the NOAA solar equations. No network.
	•	Location is CoreLocation with reduced accuracy (NSLocationDefaultAccuracyReduced). The app asks only when the player picks After dark or “Use sunset and sunrise”. If permission was given earlier, the place is refreshed at launch without asking.
	•	Without location (off, denied, not known yet, or a day with no sunset): fixed hours, 9:00 PM → 6:30 AM by default, editable on Display & Night. If permission is taken away, the cached place is dropped.
	•	Each local day uses one source: the sun when it rises and sets that day, else the fixed hours. A day's sun times are those of the solar day whose noon falls on that local day (right across the date line; near the poles the sunset may be after midnight). The next boundary is the first moment Night really changes. The candidates are every sunrise and sunset, every fixed-hour start and end (including the end of a window that began the day before), and every local midnight, where a day can change source. While the app runs, when Night first comes on in Day it shows the first-night flow, which closes the Night sheet and the camera picker first.
	•	Fixed hours are instants on the calendar: a wall time that happens twice (clocks go back) means its first occurrence; a skipped one (clocks go forward) means the next valid time. The Night check and the boundary list use the same rule.
	•	The maths uses a Gregorian calendar in the device’s current time zone, whatever calendar the device shows.
	•	A one-shot timer fires at the next boundary. It is re-armed after any settings change, a new place, a permission change, a clock change (significantTimeChangeNotification) or a time zone change. The palette then changes inside a 600 ms fade (instant with Reduce Motion).
	•	Match iPhone leaves the colour scheme to iOS; the other choices pin it (Day = light, Night = dark).
	•	The palette (PSPalette) and type scale (PSType) are injected through the SwiftUI environment (psPalette, psType) from the app root. Views never hard-code colours.
	•	v1 settings migrate once: theme light → Day, dark → Night, system → Match iPhone; sleepBrightness normal / dim / extraDim → glow 55 / 30 / 18; the active display profile (the bedtime profile when bedtimeMode is on) then sets glow = (1 − dimness) × 60 and warmth; theme sleep or bedtimeMode → Night with the Lights out preset, unless hasCalibratedDisplay, when the profile wins; autoCheckMistakes true → Right away, false → When I check; autoRemoveCandidates → tidyNotes; hasCalibratedDisplay → calibrated.

7.2 Visual Rules
	•	Day palette (fixed): bg #F4F1E9, surface #EBE6DA, surface2 #E2DCCD, ink #1B1A17, ink2 #57534B, ink3 #8A857A, accent #9A5712, accentDim #C9A27A, line #CFC8B8 (Clarity Large/Bold: #B9B1A0), lineMajor #2E2B25, hair #D8D1C1, sel #EFD9B0, peer #ECE6D9, same #F1E2C6, err #B3261E.
	•	Night palette (computed from glow, warmth and Clarity; never hard-coded):
	•	K = warmth mapped 6500 → 1200 K, interpolated in mireds, rounded to 50 K. Warmth 0 / 45 / 75 / 100 = 6500 / 2200 / 1500 / 1200 K.
	•	base = blackbody colour of K (Tanner Helland approximation). accent = blackbody of warmth × 0.55 + 52.
	•	s = floor + (1 − floor) × min(1, glow / 40)^0.9 (above 40, glow drives the backlight, Section 12.3), with floor 0.20 / 0.30 / 0.38 for Clarity Standard / Large / Bold. Increase Contrast uses the Bold floor.
	•	bg is always #000 (OLED pixels off). Every other token is base or accent times a fixed share of s (Design/v2/README.md, “Night palette”), except that the shares that carry readable text and outlines are raised for contrast: ink2 0.78, ink3 0.62, accentDim 0.65, line 0.22, lineMajor 0.60, hair 0.25.
	•	Never use a black overlay to dim; it dims everything by the same amount and makes small marks unreadable first.
	•	Night rules: no filled shapes behind text; primary buttons are outlines (1.5 pt accentDim stroke, accent text); cards are transparent with a 1 pt hair border (popovers over the board, such as the More menu and confirmations, fill #000 so the board does not show through).
	•	The tab bar, tab headers, Home and Journal follow the same rules: hairlines, no fills behind text at night (Day keeps the surface fill on cards).
	•	Every state must show by shape or weight, not hue alone (Day and Night):
	•	Selection: a filled background plus a heavier outline.
	•	Error: an underline bar plus the err colour.
	•	Hint roles: rings for evidence and targets, strike-through for eliminations.
	•	Import: unsure cells are ringed, conflicts underlined, and each legend line has a matching ring or underline swatch (Section 3.4).
	•	Learn mastery dots: mastered is a filled dot, learning a half-filled ring, new an empty ink3 ring. VoiceOver reads the level.

7.3 Grid Interaction Visuals
	•	Selecting a cell:
	•	Highlight its background, row, column, box.
	•	Selecting a number:
	•	Highlight all cells with that number.
	•	Duplicate entry:
	•	With Show mistakes set to Right away:
	•	Immediately mark conflicting cells as error (error marker, see 7.2).
	•	When I check: only Check marks wrong digits. Never: nothing is marked, even after Check, and switching to Never clears existing marks.
	•	Cell states (Design/v2/README.md, “Cell states”):
	•	Given: ink, given weight. Entered: accent, entered weight.
	•	Selected: sel fill and a 2 pt inset accent ring. Peers (row, column, box): peer fill. Same digit: same fill.
	•	Mistake: err digit plus a 2 pt err bar under it (120% of its width).
	•	Notes: 3×3 at cell × 0.25; a note matching the selected digit is bold accent.
	•	Hint marks: a spotlight (everything outside the hint’s cells at focusDim), a 1.5 pt accent ring on evidence, a 1.5 pt dashed accent ring with a 55% ghost digit on the target (a mistake gets the dashed ring without a ghost), a same fill on pattern cells, and a 1 pt dotted ink3 ring on ruled-out cells.
	•	By step: 1 spotlight; 2 adds the pattern fill; 3 adds evidence rings, the target and struck eliminations.
	•	Hint highlights:
	•	Fade in (about 0.15 s). Never blink or pulse.
	•	Stay until the player moves to another step or closes the card.

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
    // Redesign phase 5, all decodeIfPresent with defaults:
    var solveTimes: [Difficulty: [Int]]  // last 50 unassisted times per level, for Typical
    var assistedSolves: Int
    var solvedDays: [Date]               // last 14 days with a counted solve, for the Journal week
}

Streak rules:
	•	Puzzle completed without usedReveal:
	•	Update counts.
	•	Update best time and add to solveTimes, only if assisted is also false (Section 6.3). An assisted solve adds to assistedSolves instead.
	•	Add the day to solvedDays.
	•	Add to totalSecondsPlayed.
	•	Streak logic based on lastSolvedDate vs. today.

Testing requirements:
	•	Unit tests:
	•	Stats streak logic:
	•	Solve on day N (no previous): streak = 1.
	•	Solve again on day N+1: streak = 2.
	•	Skip day N+2, solve on N+3: streak resets to 1.
	•	Best time logic: solving faster updates best; slower does not.
	•	A faster assisted solve does not update best time, but does update counts and streak.
	•	Persistence:
	•	Save a GameState and Stats to storage and reload; verify equality.
	•	UI tests:
	•	Solve a very simple puzzle (you can pre-wire a nearly complete puzzle for UITest), then return to Home and verify stats (e.g., “Total puzzles solved” increased).

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
	•	ScreenBrightnessController.swift, SystemAppearance.swift, SheetTheme.swift
	•	AfterDarkScheduler.swift (Coordinate, SunTimes, SolarCalculator, AfterDarkScheduler)
	•	DriftController.swift
	•	Engine/
	•	SudokuValidator.swift
	•	SudokuPuzzleRepository.swift
	•	(Optional) SudokuGenerator.swift
	•	Logical solver (phase 2 onward, Section 13.3), in the Engine group:
	•	SolverBoard.swift (bitset board, House)
	•	TechniqueStep.swift (Technique, TechniqueStep, explanation text, graduated hint fields)
	•	CellNotation.swift (cell and house names in hint text: plain or grid, articles)
	•	LogicalSolver.swift (nextStep / solve loop, tie-break)
	•	Detector files by family: SinglesAndIntersections.swift, SubsetDetector.swift, FishAndWings.swift (phase 2); AdvancedDetectors.swift (single-digit patterns, more wings, coloring, uniqueness); Chains.swift (XY-Chain, redesign phase 5); later ALS
	•	PuzzleGrader.swift (phase 4)
	•	DrillIndex.swift (phase 4)
	•	ViewModels/
	•	GameViewModel.swift
	•	Lesson.swift (Lesson, LearnTier, LessonScript: the four written lessons)
	•	MainMenuViewModel.swift
	•	SettingsViewModel.swift
	•	StatsViewModel.swift (the Journal’s numbers)
	•	Views/
	•	MainMenuView.swift (the three tabs, PSTabBar, ScreenHead, NightButton)
	•	HomeView.swift (Continue card, MiniBoard, level rows, TierGlyph, saved imports)
	•	JournalView.swift (streak, week, solved table, Assists, Imports, Privacy)
	•	GameView.swift
	•	SudokuGridView.swift
	•	NumberPadView.swift
	•	GameChrome.swift (tools, More menu, Solved panel, Hush and Goodnight)
	•	HintCardView.swift (the three-step hint card, phase 3)
	•	NightControls.swift (segments, switch, slider, presets, rows, card, sample strip, CalibrateView)
	•	NightSheetView.swift, DisplaySettingsView.swift, FirstNightView.swift
	•	LearnView.swift (LearnView, LessonView, StatusDot, Chevron)
	•	ImportPuzzleView.swift (Source, Reading and Check the grid; OptionCard, GridPhoto), ImagePicker.swift (camera)
	•	Assets: AppIcon is “The hint”, three single-size 1024 px images: Any (light), Dark and Tinted (luminosity appearances, iOS 18). There is no LandingIcon.
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
	•	Glow 0–100: how much light the screen gives off. Implemented in two layers, so the whole slider visibly changes the screen:
	1.	Glow 0–40: the screen backlight sits at its hardware minimum and the palette’s luminance scale (Section 7.2) rises from the Clarity floor to full strength: s = floor + (1 − floor)·(glow / 40)^0.9.
	2.	Glow 40–100: the palette stays at full strength and UIScreen brightness rises in a straight line from its minimum to 0.6 at glow 100.
	3.	While the app is in front in Night it owns the backlight. Restore the player’s brightness when the app goes to the background or Night ends. Keep it while inactive (Control Center), so it does not flash. If the player changes brightness themselves, keep their choice until Glow changes.
	•	Glow scale migration: settings saved before this scale (no glowScale key, or glowScale 1) map glowFloor to the same palette strength (40·(floor/100)^(1.15/0.9)) and restart glow at Lights out, or the floor if higher. The old scale was too dark to read.
	•	Warmth 0–100: colour temperature 6500 → 1200 K. Warmth is a comfort setting. The app must not claim that warm colours protect sleep.
	•	Clarity: Standard / Large / Bold. Bigger, heavier digits and stronger lines, and a higher Night floor.
	•	Presets: Reading lamp (glow 70, warmth 45), Lights out (45, 65; the default, mid-range so a first night is readable), Red light (30, 100). A preset never sets glow below glowFloor.
	•	Find my lowest glow: six 76 pt tiles drawn in the night ink at glow 0 / 4 / 8 / 14 / 22 / 32 (all inside the palette layer). “Use this” sets glowFloor = pick, glow = max(Lights out, pick + 4) and calibrated = true. The slider and presets never set glow below glowFloor.
	•	First night (FirstNightView): the first time Night is active while calibrated is false, a full black screen shows welcome → Find my lowest glow (no Cancel) → result (“Glow set to N%.”, the Kelvin, a sample strip, Start playing). “Skip for now — use Lights out” applies Lights out and sets calibrated. It appears once: calibrated is saved before the result screen. It is drawn above everything: the camera picker closes first, the More menu closes, and a running game timer pauses until the flow ends. It keeps the Night palette for its whole run, even if Night ends while it is open. VoiceOver treats it as modal. UI tests launch with -uiTestSkipFirstNight (Debug only); -uiTestFirstNight starts in Day before the first night, to walk through the flow.
	•	Drift (DriftController): during a night game with Drift on, every 90 s glow −1 and warmth +1, up to 20 each. Glow never goes below glowFloor (and Drift never raises it). It is a session offset: never saved, reset when the game closes or Night ends, and reset after a gap of 30 minutes or more between updates (the app was away, for example through a whole day). The change fades over 600 ms.
	•	Limits the app must respect: it cannot go below the system brightness minimum, cannot read room light, and cannot turn on Reduce White Point.

Testing requirements:
	•	Unit tests: palette snapshots, Kelvin mapping, Clarity floor, v1 migration, brightness lowered only in Night and restored afterwards.
	•	Unit tests: NOAA sunrise and sunset within ±2 minutes of published times (London, 21 June 2024; New York, 21 December 2024); no sun times in polar night; After dark boundaries with and without location; edited fixed hours; Drift steps, stops at 20 and never goes below the floor; the first-night flow appears exactly once, also after a relaunch.
	•	Manual test: with Night on at minimum system brightness, no filled area anywhere renders brighter than ink, including sheets and menus.

12.4 Calm Visual Design (No Sudden Flashing)
	•	Animations:
	•	Avoid rapid, attention-grabbing animations.
	•	Use only subtle fades/scale where necessary (e.g. presenting menus).
	•	Errors / conflicts:
	•	Error indication must be subtle:
	•	Use the err colour plus an underline bar under the digit.
	•	No large full-screen flashes.
	•	No rapid blinking.
	•	Dialogs:
	•	Confirmations (Restart) are custom popovers in the app palette, never system dialogs, so they cannot render light at night.
	•	Hint card and lessons (phase 3 onward):
	•	Highlights fade in slowly; nothing blinks.
	•	The card never advances on its own. Every step waits for a tap.
	•	Lesson steps change with a 250 ms fade (none with Reduce Motion). Next and Practise are outline buttons at night. The only fill behind text is the dim pattern tint (same) that game hints use too (Section 7.3); everything else in a lesson is lines and rings. VoiceOver announces each new step.
	•	One or two short lines per step; the card has a fixed height and long text shrinks to fit.
	•	At night the card has no fill, only a hairline, and its button is an outline (Section 7.2).
	•	Puzzle completion: a slow fade, no bright burst.
	•	Import (Section 3.4): steps change with a 300 ms fade; the photo is capped at ink3 at night; the only fills are the dim outside the found grid (black) and the progress bar, neither behind text.

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
	•	Keypad at the bottom edge.
	•	Tools (Undo, Erase, Notes, Hint) just above it.
	•	Less common actions (Check puzzle, Fill all notes, Restart, Hush) in the More menu.
	•	The hint card sits just above the tools; its button (and the Hint tool, “Next step”) are in the thumb zone. Every card control has a 44 pt target.
	•	Tap targets:
	•	Minimum hit size ~44×44 points for all interactive elements (Apple HIG).
	•	Exception: the 1×9 keypad keys are about 38 pt wide on a 390 pt phone, but 64 pt tall. The single row is a design decision (Design/v2).
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
	•	If there is an incomplete puzzle for any difficulty, Home appears quickly with its Continue card.
	•	From Home, the Continue card opens the last game instantly (no loading spinners).
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
	•	Bedtime Mode is replaced by Night (Section 7.1). The moon on every tab, on Import and in the game header opens the Night sheet. The old main-menu Night bar is removed.
	•	Night sheet (NightSheetView): a custom bottom panel drawn over every screen from the app root, never a system sheet. Top radius 28, bg fill, hair top edge, 36 × 5 grabber. Backdrop black at 55% at night, warm at 18% in Day; tapping it or × closes the sheet. At least 56 pt of backdrop always shows; when the controls do not fit (iPhone SE, large text) the panel scrolls. VoiceOver treats the panel as modal. It fades in and out. The screen behind repaints live.
	•	Contents: “Night”; Day · Night · After dark segments (none marked for Match iPhone; After dark adds a line on the hours in use); then, unless Day: three presets, Glow (“Below your iPhone’s lowest brightness.” up to 40, else “Above 40%, the screen itself gets brighter.”), Warmth in Kelvin on a Kelvin-colour track (“Blue light about N% lower than daylight white.”); Clarity; then, unless Day: Drift and Find my lowest glow (Start).
	•	At night the selected segment is an accentDim ring, not a fill, and the Warmth track is capped at 75% of the ink’s light, so no fill is brighter than ink. The sheet, the first-night screen and every screen but the game hide the white system status bar at night; the game follows Hide status bar in games.
	•	The one accepted system alert is the iOS location permission prompt. It appears only after the player taps After dark (or “Use sunset and sunrise”), and it follows the dark colour scheme at night.
	•	Hush and Goodnight (Section 3.2) go to pure black in one tap.
	•	When Night is active:
	•	Sounds and haptics are off at runtime, whatever the saved settings say (the saved choice is kept for Day).
	•	Force dark appearance for every screen, including sheets the app presents. Avoid system views that cannot be themed dark (they flash white).
	•	Screen brightness is lowered (Section 12.3).
	•	The launch screen is black in every mode (iOS shows a static launch screen).

Testing requirements:
	•	Unit tests:
	•	With Night active, soundsActive and hapticsActive are false, the palette is the Night palette and the colour scheme is dark.
	•	UI tests:
	•	Turn Night on from the moon on Home and open a game.
	•	The moon opens the Night sheet on Home and in a game; × and the backdrop close it.

⸻

13. Teaching & Hints (“Learn to solve, not just fill”)

PureSudoku teaches the solving techniques from the Sudoku literature. A hint teaches the next idea, not the next digit. The research behind this section is in docs/research/sudoku-hint-and-teaching-design.md.

13.1 Goals
	•	Every hint names a real technique and shows why it works on the player’s own board.
	•	The board changes only when the player chooses (Apply).
	•	Help fades as the player masters a technique. Full worked examples help beginners but slow experts down.
	•	All teaching content follows the bedtime rules of Section 12.

13.2 Curriculum
	•	Four grading tiers: Basic, Intermediate, Advanced, Expert (TechniqueTier; they set puzzle levels, Section 2.2). The full ordered list, with a short definition and score for each technique, is in HINT_STRATEGIES.md. That file is the source of truth for technique order.
	•	The solver tries techniques in that order, so the simplest available step is always found first.
	•	Learn and the hint card group techniques into five Learn tiers (LearnTier), named as in Design/v2/README.md: Beginner (singles), Intermediate (intersections and subsets), Advanced (fish, wings, single-digit patterns), Expert (XY-Chain, Simple Coloring) and Esoteric (Unique Rectangle types and BUG+1, which work only because the puzzle has one solution). The design’s Exocet, Sue de Coq, 3D Medusa and Bowman’s Bingo are not in the app, so Learn lists the 27 techniques the solver knows (Hidden Single box and line are one lesson). Learn tiers never change grading.
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
	•	If no technique applies, return nil. The hint then places the answer as an assisted step (Section 6.3.1); the solver never guesses.
	•	Which engine feeds hints:
	•	Phases 1–2: the current SudokuHintEngine (current behavior).
	•	From phase 3: the logical solver. By then it covers every technique the old engine handles correctly (phase 2). The old engine’s XY-Chain (buggy) and Bowman’s Bingo (trial and error) are dropped; boards that needed them get the honest “beyond what hints explain yet” fallback until a correct XY-Chain lands (redesign phase 5, Section 13.6).
	•	SudokuHintEngine is deleted in phase 3.
	•	Known issues in the current engine that the new solver must not repeat:
	•	Each technique starts again from the original candidates, so steps do not stack.
	•	A hint carries only a target cell and a message, so the pattern cannot be shown.
	•	XY-Chain only eliminates when the chain’s end sees its start; the rule is any cell that sees both ends.
	•	The last resort (Bowman’s Bingo) can return no hint.

13.4 Mastery
	•	A technique is mastered at 10 credits (redesign phase 6). Each unaided move earns one credit. A move earns a credit when, on the board just before the player’s move (a correct placement, or removing a wrong note), some step of some technique makes exactly that change, and no hint for that technique was shown in this puzzle, no hint in this puzzle showed that cell and digit, the move was not credited before in this puzzle under any technique, and the board has no mistake. Each credit carries the puzzle id taken with the move, so a credit that lands after a new puzzle loads still counts for its own puzzle.
	•	The learning ledger (LearningLedger, saved in technique_progress.json together with the progress, as one atomic file: { progress, ledger }; an older file holding only the progress loads with an empty ledger) is the one store for these exclusions. AppController owns it; the game view model only reports hints and moves. It holds credited moves (“puzzle|kind|cell|digit”), hinted cells and digits (“puzzle|cell|digit”) and hinted techniques (“puzzle|technique”, the lesson technique, so a Hidden Single box hint also blocks line credit). A hint is written the moment it opens, so Undo, Restart, Continue and reopening a practice puzzle cannot lose it. Games saved before the ledger seed their hinted techniques from the hint log when opened.
	•	The puzzle key is the puzzle id. Practice puzzles use “practice-” plus the whole starting grid, so two bundled puzzles never share a key and a practice puzzle reopened later is the same puzzle.
	•	At launch the ledger keeps practice keys and keys of saved games (level games and imports) and drops the rest, so it stays small. It skips this while any level game or the imports file fails to load, or while a copy of one set aside as unreadable (name.corrupt-<time>.json) is on disk, since those games may still be restored on a later launch.
	•	If technique_progress.json fails to load, no move earns credit and the file is not written that session (hints are noted in memory only). Because credits and exclusions share the file, losing it loses both together, so a credited move can never earn again on top of its old credit. Moves from the hint card (Place · assisted, Remove · assisted, Apply · assisted) never earn credit. The credit goes to the simplest such technique (curriculum order). Checking every step, not only nextStep’s first, lets techniques like Naked Single earn credit even when another single comes first. The check runs off the main thread.
	•	Each technique has a strength value (0–1) that decays over time (half-life model). Strength rises once per puzzle where it is found unaided and falls when a hint for it is needed.
	•	Hidden Single (line) progress is stored and shown as Hidden Single (box), one lesson; saves holding line progress on its own are merged in on read.
	•	Saves from before credits decode: they get one credit per puzzle found, and a technique mastered under the old rule (3 puzzles on 3 days) keeps 10.
	•	When strength falls low, the Learn screen offers an optional review drill. No streak alarms, no notifications.

13.5 Learn screen (phase 5, redesigned in phase 6)
	•	The Learn tab, top to bottom (Design/v2/README.md, “Learn”):
	•	“Learn” and the moon; the sub-line “N of 27 techniques in your hands” (techniques that are learning or mastered).
	•	Up next card: the first technique in curriculum order that is not mastered. “UP NEXT · N STEPS”, the name (serif 24), and a reason: the level that needs it, then the player’s credits (“4 of 10 unaided uses so far”) or the hints they met it in. An accent chevron. No card once everything is mastered.
	•	The five Learn tiers (Section 13.2), each a section label and rows: the mastery dot (Section 7.2), the name, its one-line definition, and the credit count (“12×”), or “Lesson” for the four written lessons.
	•	A lesson is pushed, never a sheet, with its own header: Back, “TIER · LESSON”, the title (serif 34) and an intro. Then the board (at most 342 pt wide, SudokuGridView with the hint marks), the step text (17 pt, at least 92 pt tall) and a footer: a previous-step circle, step pills, and Next, which becomes Practise on the last step.
	•	Four lessons are written by hand, ported from Design/v2/ui_kits/puresudoku-2/Learn.jsx as data (LessonScript): Hidden Single (5 steps), Pointing (4), Naked Pair (4), X-Wing (4). Their boards are drawn for teaching, not taken from a puzzle. Their text uses plain cell names.
	•	Every other lesson uses the template: a bundled puzzle solved up to the first step of that technique, shown as the three hint steps (where to look; why; what changes, with the removals struck and the placement as a ghost digit). Its text follows the cell-name setting.
	•	The written lessons’ boards are real Sudoku: every note shown is a true candidate, every pattern is the digit’s full set of places, and the solver’s own detector finds the lesson’s step on that board (a unit test checks this).
	•	Practise opens the first bundled practice puzzle that needs the technique (from the drill index; for the template, not the example puzzle).
	•	Practice puzzles are not saved and do not count toward stats or the streak; they do count toward learning (mastery and strength).
	•	Every hint card links to its technique’s lesson from step 2 (“Lesson →”), and shows the technique’s Learn tier.

13.6 Build phases
Each phase ships on its own and keeps the app working.
	1.	Spec (this section, CODESPEC updates, HINT_STRATEGIES.md, BYOS.md uniqueness rule).
	2.	Engine core: SolverBoard, TechniqueStep, LogicalSolver; Basic and Intermediate tiers including hidden subsets; X-Wing, Swordfish and XY-Wing (ported from the old engine, so nothing it does correctly is lost); deterministic order; honest last resort; correctness oracle and latency benchmark in the test suite.
	3.	Hint card and display calibration: Section 6.3.1 three steps with Place · assisted, Reveal Cell separate, autoFillHints removed; Section 12.3 calibration and profiles.
	4.	Grading and drills: logical grade per puzzle (Section 2.2), technique lines under difficulty buttons, no silent fallback, bundled pre-graded puzzles and drill index, solution count on import.
	5.	Advanced tier and Learn: the rest of the Advanced tier (single-digit patterns, XYZ-Wing, W-Wing, simple coloring, uniqueness techniques, gated); Learn screen, lessons, mastery and fading.
	6.	Expert tier and polish: chain link graph, X-Chain, AIC, grouped AIC, ALS-XZ, ALS-XY-Wing, Sue de Coq; full VoiceOver play.
	•	Done early, in redesign phase 5: XY-Chain (ChainDetector) and the Expert and Master levels. XY-Chain is a chain of two-candidate cells, each seeing the next and sharing one digit with it; if one end is not X, the links force the other end to be X, so a cell that sees both ends can’t be X. The detector searches breadth-first from each two-candidate cell, so each end gets its shortest chain; chains that pass a cell twice are skipped. It runs after every other technique, so hints and grades of puzzles that never needed it do not change. It is Expert tier, score 260.

Testing requirements:
	•	Unit tests (phase 2):
	•	Hand-made boards for the elimination techniques (phase 2: Pointing, Claiming, Locked Pair/Triple, Naked Pair/Quad, Hidden Quad, X-Wing, Swordfish, XY-Wing): the detector returns exactly the expected eliminations (catches a detector that finds too few). Hidden Pair/Triple and Naked Triple rely on the corpus oracle.
	•	Correctness oracle: over a seeded corpus of generated puzzles (400 in phase 2; bundled pre-graded puzzles from phase 4), every step agrees with the known solution and its pattern is re-checked against the board.
	•	Same board, same step, every run.
	•	A board needing two techniques in a row (e.g. pointing, then a naked pair) yields both steps in order.
	•	Unit tests (phase 5): strength decay.
	•	Unit tests (redesign phase 6): mastered at 10 credits; old progress decodes (and keeps old mastery); a manual placement credits the technique the engine would use for it, once; hint card moves (placements and eliminations) and the cell a hint showed earn nothing; the four written lessons load with 5, 4, 4 and 4 steps and the expected marks; every technique sits in one of the five Learn tiers.
	•	UI tests (redesign phase 6): Learn shows the five tiers; a lesson steps forward and back, and Practise on the last step opens a puzzle; “Lesson →” opens that technique’s lesson, and Back returns to the same game.
	•	Unit tests (XY-Chain): a hand-made four-cell chain gives exactly the eliminations seen by both ends; the corpus oracle walks every XY-Chain step link by link.
