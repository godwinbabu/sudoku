# Sudoku Masters specification

Sudoku Masters is an offline Sudoku app for iPhone. It teaches solving techniques and is comfortable to use in bed, in the dark, without waking someone nearby.

This file is the source of truth for the behaviour, features and tests of the app. "PureSudoku" is the code name. It names the Xcode targets, the module and the test targets.

Each section ends with the tests it needs. Code comments cite the section numbers, so keep them stable.

## 0. Tech stack and project setup

- Display name: Sudoku Masters. The target, module, bundle id and test targets keep the name PureSudoku.
- Platform: iOS only, iPhone screens. iPad is not required.
- Language: Swift 5 or later.
- UI framework: SwiftUI. Use a small `UIViewRepresentable` bridge only when UIKit is much easier.
- Minimum iOS version: iOS 16.
- Architecture: MVVM with three layers:
  - The Sudoku engine holds pure logic that is easy to test.
  - View models hold UI state.
  - SwiftUI views render state and forward user actions.
- No backend and no network calls. All data stays on the device.
- Persistence utilities save and load game state, settings and stats.

Tests:
- Two test targets: `PureSudokuTests` (unit tests, XCTest) and `PureSudokuUITests` (UI tests, XCTest and XCUITest).
- Engine, models and view models sit in a module that the unit tests can import.
- The tests check real behaviour. Empty templates do not count.

## 1. Product requirements

The app is a minimalist Sudoku game with no accounts, no login, no backend and no ads.

- Three tabs: Play (Home), Learn and Journal (Section 3.1).
- Home lists five levels: Easy, Medium, Hard, Expert and Master.
- Tapping a level always starts a new puzzle at that level.
- A Continue card resumes the unfinished game played last.
- The app is fast to launch, answers taps at once, and has a clean, readable screen.
- The look is floating glass controls over a plain board, with one accent colour and no decoration.
  - Three themes: Light, Dark and Night (Section 7.1).
  - Bricolage Grotesque is the display and digit font. DM Sans is the font for everything else.
- The app is silent by default: no sound and no haptics (small taps you feel) unless the player turns them on.
- The Night appearance supports bedtime use: black canvas, Glow, Warmth and Clarity (Section 11).
- The app teaches solving techniques, not only answers (Section 12):
  - The Learn tab opens the technique curriculum.
  - A hint names and explains a technique on the player's own board before it changes any cell.
  - Each level row names the hardest technique the level needs, for example "Expert: Wings & fish".
  - Master needs XY-Chain, the first Expert-tier technique.
- Copy is calm, plain and exact. Use sentence case. Use no exclamation marks, no emoji and no streak pressure. Name a cell as "row 5, column 2".
- Accessibility:
  - Tap targets are at least 44 × 44 pt.
  - Each cell reads as "Row r column c value N" (or "empty", or its notes), followed by "given", "mistake", "hint target" or "proof" where they apply. Each key reads "N left".
  - Dynamic Type (the player's text size), VoiceOver and Reduce Motion: see Section 9.
  - No state shows by hue alone (Section 7.2).

Tests:
- Unit: the Continue card picks the unfinished game played last. A level always starts a new game.
- UI: tapping a level on Home opens a game with a 9×9 grid (Expert included).

## 2. Core gameplay

### 2.1 Sudoku basics

A puzzle is a standard 9×9 Sudoku. Each row, column and 3×3 box holds the digits 1–9 exactly once.

- Every puzzle has a preset difficulty: `.easy`, `.medium`, `.hard`, `.expert` or `.master`.
- Generated puzzles have one solution.
- Imported puzzles (BYOS.md) only need to be solvable. They can have more than one solution.
- Every puzzle has a flag, `hasUniqueSolution`, set when the puzzle is created:
  - Generated puzzles: true.
  - Imported puzzles: the app counts solutions on import and stops at 2. The flag is true only when the count is exactly 1.
- When `hasUniqueSolution` is false:
  - The hint engine does not use uniqueness techniques (Unique Rectangle, BUG+1, Hidden Rectangle, Avoidable Rectangle).
  - Check, Hint and Reveal compare against a solution that fits the player's current entries, not one fixed answer. `GameViewModel` already does this for imports.

Tests:
- Unit:
  - A puzzle with two solutions gets `hasUniqueSolution == false`. A generated puzzle gets true.
  - On a puzzle flagged false, the hint engine never returns a uniqueness technique.
  - For a complete `solutionGrid`, each row, column and 3×3 box has the digits 1–9.
  - For a `GameState` that holds a solved puzzle, `isCompleted` is true.

### 2.2 Difficulty levels

Use this enum:

```swift
enum Difficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard
    case expert
    case master
}
```

Saves that hold only easy, medium and hard decode unchanged.

#### Puzzle source

- The app generates puzzles with a generator and a solver (below).
- It falls back to puzzles bundled in the app when generation cannot find one in time.
- The bundled puzzles live in `BundledPuzzles.swift`. Each entry has an id, an initial grid and a solution grid. A grid is an 81-character string, with 0 or `.` for an empty cell.

#### Rating

The rating is a logical grade. It measures a puzzle the way a person solves it (`PuzzleGrader`).

- Solve the puzzle with the logical solver (Section 12.3), one step at a time. Always take the simplest available step.
- The grade records:
  - `hardestTier`: the tier of the hardest technique needed (Basic, Intermediate, Advanced or Expert).
  - `score`: the sum of the step scores. Each technique has one fixed score (see HINT_STRATEGIES.md).
  - `techniques`: the set of techniques used.
  - `stepsPerTier`: the number of solver steps per tier, Basic to Expert. A wall is a step at Intermediate tier or above. The solver always takes the simplest step, so each wall is a point where no single exists anywhere. "Intermediate+" and "Advanced+" count by tier, cumulatively.
  - `openingSingles`: the distinct cells that any Basic-tier detector (Full House, Hidden Single in a box or line, Naked Single) can fill on the untouched starting board.
- A grade saved without `stepsPerTier` or `openingSingles` decodes them as unknown (nil), never as zero.
- If the logical solver gets stuck, the puzzle is out of range for every level. The app discards it.
- The grade is deterministic: the same puzzle always gets the same grade.

The hardest technique a puzzle needs (`Technique.level`) sets its level:

| Level | Hardest technique needed |
|---|---|
| Easy | Singles only (Basic tier) |
| Medium | Pointing or Claiming, nothing harder |
| Hard | Pairs, triples and quads (naked, hidden, locked), nothing harder |
| Expert | Wings and fish: any Advanced technique (X-Wing, Swordfish, Skyscraper, 2-String Kite, Empty Rectangle, XY-Wing, XYZ-Wing, W-Wing, Simple Coloring, uniqueness), nothing harder |
| Master | Chains: XY-Chain (Expert tier) |

- Saved games keep the level they were created with.
- Within a level, the score orders puzzles from easier to harder.
- A puzzle is offered only at the level its grade maps to. There is no silent fallback to another level.
- An import that the logical solver cannot finish gets Master and no grade.

#### Level targets

The hardest technique sets the level. The targets shape how the puzzle plays inside the level. Clue count tracks human difficulty poorly, and "moves open at each step" tracks it well. So the targets bound opening singles and walls as well as givens. They are product hypotheses to tune, not research-validated values.

| Level | Givens | Opening singles | Walls |
|---|---|---|---|
| Easy | 38–44 | at least 15 | none |
| Medium | 30–34 | 5–14 | at least 2 (pointing or claiming) |
| Hard | 26–30 | 3–7 | at least 2 (at least one a subset, which the level already requires) |
| Expert | 24–27 | at most 5 | at least 4, and at least 1 Advanced+ (the level requires it) |
| Master | 22–26 | at most 7 | at least 6, and at least 2 Advanced+ (one a chain, which the level requires) |

- Medium allows 5–14 opening singles.
- Master allows at most 7 opening singles. Master still has the most walls.

#### Generation

1. Make a minimal puzzle: remove every clue that can go. Grade it.
2. If its level is right, add digits back from the solution. Solution digits keep the puzzle unique.
3. Go through the cells in random order, in at most one pass. An added digit stays only if the level stays the same. Easy cannot leave Easy, so it is graded only once it is in range.
4. Once the givens reach the range, check each addition against every target. Opening singles and walls need not change in one direction.
5. The first board that meets all targets is the puzzle.
6. If no board meets them, the attempt is a miss and the next try starts. After 30 tries, use a bundled puzzle.

- Generation runs off the main thread. It makes up to 30 tries.
- The stored grade (score, techniques, `stepsPerTier`, `openingSingles`) is the grade of the final board.
- Saved games keep their own boards. Nothing migrates.

#### Feasibility gate

- For each level, live generation (not the fallback) must succeed at least 75% of the time within 30 tries. The sample is at least 200 seeded runs.
- If a level misses the gate, loosen that level's targets and say so in this section. Do not add tries.
- The rest falls back to a bundled puzzle, which also meets the targets.
- The mean time per request must stay under 0.4 s per level, with failed tries and fallback included.

#### Bundled puzzles

- There are 120 pre-graded puzzles with unique solutions per level, 600 in all. Each is inside its level's targets.
- The app's own generator made them offline (seed 20261114). No licence applies.
- Each entry carries the full grade, including `stepsPerTier` and `openingSingles`. A fallback puzzle has the same grade as a generated one.
- Every board of the earlier sets stays as a practice-only entry. It is deduplicated by grid and never offered as a level puzzle. So no technique has fewer drills than before.
- The puzzles also serve as practice drills, indexed by technique.

Tests:
- Unit, puzzle repository:
  - At least one puzzle exists per difficulty.
  - `initialGrid.count == 81` and `solutionGrid.count == 81`.
  - The validator accepts every `solutionGrid`.
- Unit, generator:
  - Each generated puzzle has exactly 81 cells, a valid solution and a unique solution.
- Unit, logical grade:
  - The same puzzle graded twice gives the same grade.
  - A puzzle that needs only singles grades Easy. A known X-Wing puzzle grades Expert.
  - Expert puzzles (generated and bundled) need an Advanced technique and no chain. Master puzzles need XY-Chain.
  - A puzzle requested at a level never comes back graded at a different level.

### 2.3 Game state model

Core models:

```swift
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
```

- The app keeps one active `GameState` per difficulty: five saved states, `game_<level>.json`.
- `lastUpdated` is set on every save. The Continue card uses it.

Teaching fields:
- `SudokuPuzzle`:
  - `hasUniqueSolution: Bool` (Section 2.1). When a saved file lacks it, the default is `source == .generated`. An imported puzzle saved without it gets its solutions counted (stopping at 2) the first time it loads. The app saves the result.
  - `grade: PuzzleGrade?` (hardestTier, score, techniques; Section 2.2). Nil for puzzles saved before grading existed.
- `GameState`:
  - `hintLog: [HintLogEntry]`: one entry per hint. It holds the technique, the deepest step shown (1–3; older saves hold rungs 0–4) and whether the player used its action.
  - `hints: Int`: the hints opened in this puzzle (`hintLog.count`), for the Solved summary.
  - `assisted: Bool`: true once a hint placed a digit or removed candidates (Section 6.3.1). Saves that hold the old `usedHint` key decode it into this field.
- `SudokuCell.generatedCandidates`: the notes that Fill all notes added (Section 3.2).
- `TechniqueProgress`, one per technique: `credits: Int` (Section 12.4), `foundUnaided` (the puzzle id and day of each puzzle where the player found it unaided), `hintsSeen: Int`, `lastSeen: Date?`, `strength: Double` (0–1, decays over time) and `strengthDate: Date?` (when `strength` was set).
- Every persisted model decodes new fields with defaults (`decodeIfPresent`): `SudokuPuzzle`, `GameState`, `Settings`, `Stats` and `TechniqueProgress`. A strict decode of a new field makes the old file fail to load. The app then moves the file aside and the player loses their settings.

Tests:
- Unit:
  - Decode a `GameState` and a `SudokuPuzzle` saved without the new fields. Check the defaults: empty `hintLog`, `assisted == false`, `grade == nil`, and `hasUniqueSolution == true` for generated puzzles. An old `usedHint == true` becomes `assisted`.
  - An imported two-solution puzzle saved without `hasUniqueSolution` loads as false.
  - Settings and Stats files from the previous version load without errors, with defaults for new fields.
  - Build a `GameState` from `initialGrid` and `solutionGrid`. It has exactly 81 cells, and `given` and `value` match `initialGrid`.
  - A `GameState` survives an encode and decode round trip with equality.

## 3. Screens and navigation

### 3.1 App structure and Home

`MainMenuView` holds three tabs: Play (`HomeView`), Learn (`LearnView`) and Journal (`JournalView`). Each tab has its own `NavigationStack`.

Tab bar:
- The app draws the tab bar itself (`PSTabBar`), so it stays dark at night. It is a floating glass capsule, 62 pt tall, 21 pt from the left, right and bottom screen edges. When the build-number strip shows, the capsule sits above the strip.
- It holds Play (`square.grid.3x3`), Learn (`book`) and Journal (`chart.bar`). Each is a symbol over an 11 pt label.
- Content scrolls under the bar.
- The active tab is accent, with a bold label, on a pill (clear at night). The other tabs are ink. The selected tab also carries the selected trait.
- A separate 62 pt round glass button sits 10 pt to the right of the bar. It imports a puzzle from a photo (label "Import a puzzle from a photo"). From Learn or Journal it switches to Play first.
- The tab bar belongs to each tab's root screen. Anything pushed (a game, a lesson, Import, Licences) covers it.

Headers and system UI:
- Each tab's header (`ScreenHead`) is a 44 pt row. It has an optional line on the left and the moon on a 44 pt round glass button, which opens the Night sheet (Section 11.7). The large title follows (Bricolage 33, 800). Import has the moon in its bar.
- The app uses no system sheets, alerts, context menus or confirmation dialogs. The Display sheet is drawn by the app. Lessons are pushed. Confirmations are custom popovers.
- The camera and the Photos picker on Import are the only system screens. Each opens only after an explicit tap (Section 3.4).
- Status bar and home indicator: see Section 11.7.
- Screens that scroll from the top (Home, Learn, Journal, Licences) draw a bg strip behind the status bar, so content never sits under the clock.

Layout sizes:
- Screen side padding is 16 pt. The design size is 390 × 844 pt. Lay out with safe areas, not fixed offsets.
- Corner radii: board 12, hint card 22, grouped list and card 26, tab bar 31. Pills are half their height.

Home, top to bottom, with 16 pt side padding:
1. The date line (for example "Saturday, November 21", 15 pt, ink2) and the moon. Then the title "Sudoku Masters". There is no streak here.
2. The Continue card, only when an unfinished level game exists:
   - Style: surface, 26 pt corners, 16 pt padding.
   - A 72 pt progress ring: 7 pt stroke, line track, accent progress (filled cells ÷ 81), with the filled count inside.
   - Text: "Continue", then the level (Bricolage 24, 800), then the time and fill count ("6:52 · 44 of 81").
   - A primary Resume pill, 44 pt tall.
   - The whole card resumes the game saved last (`lastUpdated`).
3. "New puzzle" (15 pt, 600, ink2), then one grouped list (surface, 26 pt corners, line separators):
   - Five rows, 60 pt tall. Each shows the level name (Bricolage 19, 800) over the techniques its puzzles need, and a chevron.
   - The technique lines are "Singles", "Pointing and claiming", "Naked and hidden pairs", "Skyscraper, XY-Wing, X-Wing" and "XY-Chain and beyond". They come from what the generator's puzzles use.
   - Best times are in Journal.
4. Saved imports: unfinished imports, most recently played first, in the same grouped style. A trash button asks first, with a custom confirmation.

Behaviour:
- Tapping a level always starts a new puzzle at that level.
- If an unfinished game with player entries (digits or notes) is saved at that level, a custom confirmation asks first: "Replace your unfinished Hard game?" It offers Continue (resume the old game) and New. The app saves one game per level, so this is the player's way back to older games.
- The Continue card opens the saved game as it was.
- Goodnight from any game returns to Home.
- Learn (Section 12.5) is a plain scroll view, not a `List`, so no system chevrons or separators show. The app draws disclosure chevrons in palette colours.

Tests:
- UI:
  - Launch shows the five level rows, each with its technique line. There is no Night bar.
  - The tabs switch, and each tab has the moon.
  - The import button opens Import from Play. From Journal it opens Import on Play.
  - Home starts an Expert game. Back on Home, the Continue card resumes it with its entry.
  - A level with an unfinished game asks first. Continue resumes it. New starts a different puzzle. A level with no entries does not ask.
- Unit:
  - The Continue card picks the unfinished game played last, never a finished one. A level always starts a new puzzle.
  - The Home date line reads "Saturday, November 21" (en_US).

### 3.2 Game screen

The SwiftUI view is `GameView`. From top to bottom:

1. Navigation row (44 pt, 16 pt side padding):
   - A round glass Back button.
   - In the middle, the level (Bricolage 21, 800) and the timer (15 pt, ink2). A tap on the timer pauses the game.
   - A glass capsule that holds the moon (opens the Night sheet, Section 11.7) and More.
2. Board, 8 pt below the row:
   - Its width is the screen width minus 12 pt (6 pt from each edge). It is smaller only on a screen too short for it. On wider phones it grows with the screen. At 390 pt it is 378 pt wide with 42 pt cells.
   - Cells sit on surface with 12 pt corners and a 1 pt edge outline. Line separates cells and lineMajor separates boxes. There is no outer frame.
   - Line widths follow Clarity (Section 11.3). Cell states are in Section 7.3.
3. Hint slot (170 pt, 10 pt below the board):
   - It is always reserved, so nothing moves.
   - It holds the hint card while a hint is open (Section 6.3.1), or the coach card (Section 6.3.3).
   - Otherwise it says "Notes on — digits go in as pencil marks" while Notes mode is on.
   - It warns when two of the same digit share a house, except when mistakes are set to Never.
   - It offers the coach once the player is stuck (Section 6.3.3).
4. Tool bar and keypad: two glass bars (26 pt corners), 12 pt from the sides and 8 pt apart. The lower bar is 28 pt above the bottom screen edge.
   - Tools (52 pt tall): Undo, Erase, Notes and Hint. Each is a symbol over an 11 pt label. The Notes label reads "Notes on" or "Notes off". VoiceOver reads "Notes" with the value On or Off. The active tool is accent and heavier, with no chip. While a hint is open, the Hint tool reads "Next step" and does what the card's button does.
   - Keypad (64 pt tall): 1×9, with no key backgrounds. Each key shows its digit (Bricolage 28, 800). A digit with none left turns ink2 and is disabled, except in Notes mode, where every key stays on. In Notes mode the keypad bar gains a 1.5 pt accent outline, the digits shrink to 22 pt, and each key shows how many of its digit are left (11 pt, ink2) under it. Outside Notes mode the counts are hidden. VoiceOver reads "N left" in both modes.

Other game states:
- More menu: a custom popover, never a system menu. Its rows are Check cell, Check puzzle, Reveal cell ("Not counted"), Fill all notes, Clear generated notes, Restart puzzle and Hush screen.
  - Check cell and Check puzzle are left out when mistakes are set to Never, because they would mark nothing.
  - Check cell needs a selected cell with an entered digit.
  - Reveal cell needs a selected cell that is not a given and not already revealed. It marks the solve as not counted (Section 6.3.2).
  - Clear generated notes shows only while some notes came from Fill all notes.
  - The menu scrolls when its rows do not fit.
- Generated notes:
  - Fill all notes adds the digits that each empty cell's row, column and box still allow. It keeps the player's own notes. It records the added notes per cell in `SudokuCell.generatedCandidates`, which is saved with the game. Older saves have none, so every old note is the player's.
  - Clear generated notes removes only the generated notes, as one Undo.
  - A generated note stops being generated when the player removes it or any edit takes it away. If the player then adds it back by hand, it is the player's note.
- Restart puzzle asks first, with a custom confirmation styled like the menu. At night its backdrop is black at 92%, so the board and notes do not show around the card.
- Paused: a box with "Paused" and Resume replaces the board. The timer stops. The keypad dims to 30% and is disabled, like the tools.
- Hush: a two-finger tap anywhere, or the More menu, pauses the game and shows pure black.
  - "Tap anywhere to return" fades out after about 3.5 s.
  - Any tap returns and resumes.
  - The black fades out over 0.3 s but stops taking taps at once, so the next tap reaches the control under it.
- Solved:
  - The board fades to 30% over 600 ms (150 ms with Reduce Motion) and shows no selection.
  - The hint slot, tool bar and keypad give way to a summary below the board:
    - "Solved" (Bricolage 52, 800).
    - A greeting for the time of day (`GameViewModel.greeting`): "Good morning" 5:00–11:59, "Good afternoon" 12:00–16:59, "Good evening" 17:00–20:59, "Good night" 21:00–4:59. The first-night greeting (Section 11.3) is separate and has its own hours.
    - The level, the time and the hint count.
    - A note on what the solve counts for: Practice "not counted"; Revealed "not counted"; Assisted "Assisted · counts for your streak, not best times".
    - "This grid needed" with one outlined chip per technique. The techniques come from `LogicalSolver.techniquesNeeded(for:)`, which replays the hint engine from the givens once, off the main thread.
  - At the bottom, 50 pt tall: Another (secondary) and Goodnight (primary). Another starts a new puzzle at this level. For imports and practice it goes back.
  - There is no confetti, sound or haptic.
- Goodnight: pure black with "Sleep well." fading out. A tap returns to Home.
- Status bar and home indicator: see Section 11.7.
- Drift (Section 11.3) applies to the game's palette while Night and the Drift setting are on.

Interaction:
- Tap a cell to select it.
- Tap a number to fill the value (Notes off) or to toggle a candidate (Notes on).
- A hint card fills the hint slot (Section 6.3.1). The board, tools and keypad keep their place. While a hint is open, the grid shows the hint's marks (Section 7.3) and no selection.
- The game screen has no Check Cell button, no Reveal Puzzle button and no in-game New Puzzle button. The `GameViewModel` behaviour stays (Sections 6.1, 6.4 and 6.6).
- Motion is fades only, 600 ms or less (Section 11.4). Nothing bounces.

Tests:
- UI:
  - Start an Easy game, tap a cell, tap a number. The cell shows that number.
  - Turn Notes mode on, tap another cell, tap a number. Smaller candidate text appears in that cell.
  - Restart the puzzle from the More menu. Entered values and candidates clear.
  - The Notes tool reads Off, then On, then Off.
  - A two-finger tap shows Hush. A tap returns.
- Unit:
  - A digit's keypad count drops as the player places it. At zero its key is disabled outside Notes mode.
  - Fill all notes keeps each cell's answer, adds no digit that a peer holds, and is one Undo.
  - Clear generated notes keeps the player's notes (also one the player removed and added back) and is one Undo. Old saved cells decode with no generated notes.
  - Check cell and Reveal cell follow the selection.

### 3.3 Journal (stats and settings)

The SwiftUI view is `JournalView`. It has the header line "Nothing here leaves this iPhone" and the title "Journal". Groups are surface cards (26 pt corners) under 15 pt ink2 labels.

- Streak card:
  - The current streak (Bricolage 40, 800) over "days in a row".
  - The streak is zero once a whole day passes without a solve. A night runs until 4 am, so a solve at 00:30 counts for the evening before (`Stats.playDay`).
  - This week's seven days, Monday first. A day with a counted solve is a filled circle by day and a ring with a dot at night. Other days are plain rings. Shape carries the state, not hue.
  - VoiceOver reads the full weekday ("Tuesday, solved").
  - Stats files from before the week view seed it with the last solve day.
  - When the streak is 0 but this week has a solve, a line under it reads "Last solved Tuesday." So 0 beside filled dots is not a contradiction.
- Solved: a table with the columns Level, Solved, Best and Typical.
  - Level names are Bricolage 19, 800.
  - Typical is the median of the last 50 unassisted solve times at that level.
  - An en dash means none yet. Solved shows 0.
  - Under the table: "N assisted solves kept your streak but don't set best times." and "N solved in all · N imported · h:mm:ss played".
  - VoiceOver reads each table row as one line: "Expert: 3 solved, best 4:12, typical 5:00", with "none yet" for a dash.
- Assists (palette segments and switches):
  - Show mistakes: Right away, When I check or Never. Never means no automatic marks and no Check. A hint still points at a mistake first.
  - Tidy notes: remove a placed digit from the notes it sees.
  - Show timer: on or off.
  - Cell names in hints (notation): "row 5, column 2" (plain, the default) or "R5C2" (grid). Grid also names houses "R5", "C2" and "B4". Every hint and lesson sentence goes through the `CellNotation` formatter, which also picks the article ("an 8").
- More (other settings):
  - Coach when I'm stuck (default on, Section 6.3.3).
  - Hide status bar in games.
  - Sounds.
  - Vibration ("Night always keeps sound and vibration off.").
  - Keep import photos.
  - Imported photos · Clear. It asks first, with a custom confirmation.
  - Show build number.
- About:
  - "Everything stays on this iPhone. No account, no network, no analytics. Silent by design — no sounds or vibration unless you turn them on."
  - Licences pushes `LicencesView`. It shows the SIL Open Font License text of Bricolage Grotesque and DM Sans, read from Resources/Fonts.
  - One selectable line, for example "Version 1.0 (412) · 5e4a202". It holds the marketing version, the build number and the short commit SHA.
    - The build number is the commit count. The "Stamp build number" build phase writes it into the built Info.plist.
    - The SHA is `PSGitCommit`, with "+dirty" when tracked files had changes.
    - A missing value reads "unknown", for example in a build made without git.
- Show build number:
  - When it is on, the same line shows in a 16 pt strip under every screen's safe area. The root view controller reserves the strip with `additionalSafeAreaInsets`, so pushed screens get it too. It never covers a control.
  - The line is a fixed 11 pt, not Dynamic Type, so it fits its strip. Its colour is ink3 of the current palette, with no fill. It is not hit-testable. It follows Drift in a Night game.
  - Hush, Goodnight and the first-night flow hide the line, so they stay pure black. The strip stays reserved, so the game does not move.
- Settings migration:
  - The old `cellNameStyle` key maps short to grid and long to plain.
  - The app ignores the old `askBeforeHintResult` key. The hint card has no "Try it yourself first?" step.

Tests:
- Unit:
  - A changed setting (for example `showTimer`, `appearance` or `glow`) persists and reloads.
  - Settings files from older versions (theme, `bedtimeMode`, `sleepBrightness`, display profiles, `autoCheckMistakes`, `autoRemoveCandidates`) load and map to the current fields (Section 7.1).
  - `cellNameStyle` migrates to notation. `askBeforeHintResult` is ignored and not written back.
  - Notation strings in both modes, including "an 8".
  - Journal stats:
    - Typical is the median of unassisted times.
    - Assisted solves count for the streak and the counts, not best or typical.
    - Reveal counts for nothing.
    - There is one week entry per day.
    - The streak drops to zero after a missed day.
- UI:
  - Journal, Show timer off: a game shows no timer. With Show timer on, it shows one.
  - Journal, Licences: the OFL text shows. Back returns.

### 3.4 Import (Bring Your Own Sudoku)

`ImportPuzzleView` is pushed from Home and covers the tab bar. It hides the navigation bar and draws its own 48 pt header: close (xmark, "Discard") on the left and the moon on the right. The flow and its rules are in BYOS.md.

It has three steps (`ImportPuzzleViewModel.step`). They change with a 300 ms fade (none with Reduce Motion).

Source:
- Title "Import a puzzle" (serif 32). Text: "From a newspaper, a book or a screenshot. The photo is read on this iPhone and never uploaded."
- Four option cards:
  - Take a photo (Camera). It is disabled with "No camera on this device" when there is no camera.
  - Choose from Photos ("Screenshots work best").
  - Type it in ("Enter the givens by hand").
  - Paste a grid ("81 digits, 0 or . for blanks").
- Paste reads the clipboard text. iOS may ask to allow it. The app keeps digits 1–9 and blanks (0 or `.`) in order and ignores everything else, so text-drawn grids with `|`, `-` and `+` work.
  - Exactly 81 cells go to Check the grid.
  - Anything else stays on Source with "No grid on the clipboard. Copy 81 digits, with 0 or . for blanks." (ink2, under the cards).
- Then "FOR A CLEAN READ" and the tips line: "Fill the frame with the grid · Good light, no glare · Pencil marks are ignored".
- Cards have the surface fill in Day and only a hairline at night.
- Take a photo opens the camera (`UIImagePickerController` in a sheet). Choose from Photos opens `.photosPicker(isPresented:selection:matching:)`. Both close when the first-night screen appears, because that screen is drawn at the app root and a system screen would sit above it.

Reading (while the detector runs):
- The photo shows with the found grid outlined in accent, its inner box lines in accentDim, and the area outside dimmed.
- Text: "Reading digits…" (serif 26). Then "Looking for the grid…", then "Grid found · N of 81 cells checked".
- A 3 pt progress bar (hair track, accentDim fill).
- At night the photo is multiplied by ink3, so it stays under ink and under its accent outline.

Check the grid:
- This step follows reading (even a failed read) or Type it in. A failed read shows "Could not detect a clear grid. You can fill it manually." The header says "CHECK THE GRID".
- The board shows every entered digit as a given.
- Unsure cells:
  - A digit is unsure when its recognised candidate scores below 0.6. The score is `VNRecognizedText.confidence` of the candidate, not of the observation. A score of exactly 0.6 is sure. An unsure cell gets a ring (the evidence ring).
  - Exception: if two reads of the cell agree on the digit and none reads another digit, the cell is sure. Fast mode scores most clear digits 0.5.
  - A cell where any pass saw one central character but no digit could be read (such as "I" for a thin 1) is ringed and left blank. It is never silently dropped. Longer text, or text near the cell's edge, counts as grid lines.
  - A cell with no fast read but with text seen or ink is read again from its inner area on a plain margin, fast and then accurate. This handles thick border lines and thin 1s.
  - Tapping a ringed cell confirms it. Changing or clearing it confirms it too.
  - VoiceOver reads ringed cells with the value "Unsure" and the hint "Hard to read. Double-tap to confirm." Their labels are unchanged.
- Reading, solving and grading run off the main thread.
- Conflicts get the err underline bar.
- Legend lines under the board:
  - "N unsure. Ringed cells were hard to read — tap to confirm or fix." (with a ring swatch).
  - For the first house with a repeated digit: "Two 4s in row 4. Fix one before starting." (with an underline swatch). The house is named in the player's cell-name style.
  - Without a conflict, a status line shows instead: "Add at least 10 clues to start.", "Checking if the puzzle is solvable.", "Puzzle is solvable." or "This puzzle has no solution."
  - When the grid has two or more solutions (counted up to 2, off the main thread), a note follows "Puzzle is solvable.": "This grid has more than one solution. Check the digits against your photo." It does not block Start (Section 2.1).
  - While the grid is empty, the legend reads "Type the digits printed in the puzzle: tap a cell, then a number."
- Under the legend, Start over (ghost) deletes the photo, empties the grid and returns to Source. It serves a failed or wrong read (BYOS.md, retry and reset).
- The board, legend and Start over scroll when they do not fit (iPhone SE). The keypad and buttons stay at the bottom.
- At the bottom: a 1×9 keypad (52 pt keys, no counts), Clear cell (ghost) and Start puzzle (primary).
  - Start is disabled until the grid has at least 10 clues, no conflicts and a solution.
  - A disabled button is a hair outline with ink3 text (at least 3:1 in Day), not a faded fill.
- Import has no text fields. The player types givens with the keypad, so the system keyboard never shows.

Tests:
- Unit:
  - The steps go Source to Check the grid on Type it in, on a pasted grid and on a loaded grid.
  - Pasted text reads as a plain line, dots and a text-drawn grid alike. Anything but 81 cells stays on Source with the message.
  - The conflict line names the first repeated digit and house, in both cell-name styles.
  - Unsure cells clear when tapped or fixed.
  - Start over returns to Source and deletes the photo.
  - A photo shows Reading at once.
  - Unsure uses the candidate's confidence, and 0.6 itself is sure.
  - Conflicts block Start. The minimum clue count applies.
  - Every photo fixture reads all its digits with no cell ringed: a printed grid, dark-theme screenshots and crops of a puzzle site, and a light-theme screenshot. The dark-theme grid reads in full wherever the found rectangle lands around its frame.
  - Two agreeing unsure reads are sure.
  - Text seen but not read rings a blank cell.
  - Two solutions show the note without blocking Start.
  - A stale solve or Start result is dropped.
  - The image cache cleanup removes photos that no saved import uses and keeps the rest.
- UI:
  - Import opens on Source with its options.
  - Type it in goes to Check the grid. Two 4s in a row show the conflict line and keep Start disabled. Clear cell removes the conflict. Start over returns to Source.
- Not yet covered (add these):
  - Unit: an imported puzzle's metadata survives a save and load.
  - UI: a photo goes through Check the grid, an edit and Start puzzle into play.
  - UI: Discard exits Import and creates no game (today the tests check only that Home shows).

## 4. Timer behaviour

The timer counts only active play time.

- It starts when a puzzle begins or resumes.
- It pauses when the app goes to the background, when the app becomes inactive, and when `GameView` disappears.
- It resumes when `GameView` appears again, if the game is not completed.
- `GameState.elapsedSeconds` stores the time.
- Suggested implementation:
  - When `GameView` appears, record `startTimestamp = Date()`. Use `Timer.publish(every: 1, on: .main, in: .common)` or a `Task` with sleep to count while active.
  - When `GameView` disappears or the app goes to the background, add `Date().timeIntervalSince(startTimestamp)` to `elapsedSeconds` and stop the timer.
- Display format: `mm:ss`, or `hh:mm:ss` for longer sessions.
- With Show timer off, the timer keeps counting but its UI is hidden.

Tests:
- Unit, with mocked time in `GameViewModel`:
  - `elapsedSeconds` increases while the timer runs.
  - `elapsedSeconds` stops increasing when `pause()` is called (this simulates the background).
- UI (best effort): start a game, wait a few seconds, and check that the timer label changes.

## 5. Input modes: Normal and Notes

```swift
enum InputMode {
    case normal
    case candidate
}
```

- Normal mode: selecting a number sets `cell.value = digit`, if the cell is not given and not `isRevealed`. It clears `cell.candidates`.
- Notes mode (`.candidate` in code): selecting a number toggles that digit in `cell.candidates`. It leaves `cell.value` unchanged. Candidates show in a smaller font inside the cell.
- Optional, set by the Tidy notes setting (`autoRemoveCandidates`): when a final value is placed in a cell, remove that digit from the candidates of every cell in the same row, column and box.

Tests:
- Unit, in `GameViewModel`:
  - In normal mode, setting a value clears candidates.
  - In Notes mode, tapping the same number toggles it in `candidates`.
  - With `autoRemoveCandidates` true, placing a value removes the candidate from related cells. With it false, it does not.

## 6. Check, Hint, Reveal and puzzle control

### 6.1 Check Cell

- When the player taps Check Cell, and a cell is selected and has a value, compare the value with `solutionGrid`.
- If it is correct, set `isError = false`. If it is incorrect, set `isError = true`.

Tests:
- Unit, for a known puzzle and solution:
  - Set a cell to the correct value and call `checkCell()`. `isError == false`.
  - Set an incorrect value and call `checkCell()`. `isError == true`.

### 6.2 Check Puzzle

- When the player taps Check Puzzle, compare every cell that has a value with `solutionGrid`. Mark `isError` on each incorrect cell.
- After a check, the hint slot says "No mistakes so far." or "N wrong digit(s), marked with a bar." VoiceOver announces it. The next move, selection, hint, restart or new puzzle clears the message.

Tests:
- Unit: on a partially incorrect board, `checkPuzzle()` flags all incorrect cells and no correct cells.

### 6.3 Hint and Reveal Cell

Hint and Reveal Cell are two separate actions. Hint teaches. Reveal Cell fills a cell.

#### 6.3.1 Hint (graduated hint card)

Opening and closing:
- Tapping Hint opens the hint card in the hint slot (Section 3.2) at step 1. Every hint opens at step 1.
- The card's button, or the Hint tool ("Next step"), moves one step on. The × button closes the card without changing anything.
- On a card with no step-3 action, "Next step" does what the card offers: Undo on the clashing-entries card, otherwise it closes the card.
- Opening a hint clears the selection. Tapping a cell closes the hint. So the keypad never types into a cell that the card hides.
- Steps 1–3 are free. They never change the board or the stats.

Order:
- The hint engine picks the first match in this order: mistakes, then Full House, Hidden Single (box, then row, then column), Naked Single, Pointing, Claiming, then the rest of Section 12.2 in curriculum order.
- Within one technique, the lowest cell wins (Section 12.3).
- Only the hint applies "row before column" (`LogicalSolver.nextHintStep`). Grading and mastery keep every step of `nextStep`, so a column single still earns credit.

Mistake first (always checked, whatever Show mistakes is set to):
- A mistake is a wrong digit, or a cell whose notes leave out its correct digit. Cells with no notes are never a mistake. Notes that conflict with a placed digit (stale notes) are ignored.
- Step 1, "Where to look": "Something in box 4 doesn't fit." The box is spotlit. Button: Show me.
- Step 2, "Mistake":
  - When a peer already holds the digit: "The 7 in row 3, column 4 repeats the 7 in row 3, column 8." The cell gets a dashed ring. The peer gets a solid ring. Their shared row, column or box is spotlit.
  - Otherwise: "The 7 in row 3, column 4 can't be right."
  - Button: Next.
- Step 3, "Why":
  - With a peer: "Row 3 already has a 7 (column 8)." In a column the text ends "(row N)". In a box it gives the full cell name.
  - Otherwise: "Nothing on the board clashes with it yet, but the puzzle has one solution, and it has a different digit here."
  - Button: Clear it. It clears the digit (or the notes) as one undoable edit. It does not mark the solve assisted.
- Imports whose entries fit no solution get one card: "Some of your entries don't fit together. Try undoing recent moves." The card has an Undo button.

Technique steps:
- The steps come from the logical solver (Section 12.3). The solver takes the simplest step on the player's board and uses the player's notes where they exist. The same board always gives the same hint.
- The card:
  - Style: surface, 22 pt corners, 1 pt edge outline, padding 12 / 16 / 14.
  - Top row: the heading (Bricolage 21, 800) and "Hint · N of 3" (13 pt, ink2), then ×. The heading is "Where to look", and from step 2 on it is the technique name.
  - Body: 15 pt in ink. It drops to 13 pt if the text would not fit, and then it scrolls.
  - Steps 1 and 2 have one primary Next button. Step 1 also has a secondary "All patterns", which opens the coach.
  - Step 3 has a secondary Lesson button (104 pt) and the primary action.
  - Buttons are 44 pt tall.
- Step 1, "Where to look": the nudge, with the unit tinted. Example: "Look at box 4. Where can 5 go?"
- Step 2, "Technique": the technique name and its one-line definition. The pattern cells are filled. In cells without notes, the candidates the pattern relies on show.
- Step 3, "Why":
  - The board shows evidence rings, the dashed target with its ghost digit, and struck-through eliminations.
  - Example: "Every other empty cell in box 4 already sees a 5. So 5 can only go in row 5, column 2."
  - If the player's notes, not placed digits, rule a cell out, the text says "sees or has ruled out".
  - The button reads "Place 5 · assisted". For eliminations it reads "Remove 5 · assisted" (one digit) or "Apply · assisted".
  - The button makes the change as one undoable edit (Section 6.7).
  - An elimination in a cell without notes first writes that cell's candidates as notes. So the deduction is kept and the next hint moves on.
- Lesson (step 3) pushes the technique's lesson (Section 12.5). Back returns to the game. The timer stops while the game is off screen, also across a trip to the background, and runs again when the game shows.
- Each hint carries: nudge, technique, tier, short (definition), why, focus, evidence, pattern, elim and target (`TechniqueStep` and `HintSession`).
- If the solver finds no step it can explain, the card opens at step 3: "This step needs a technique beyond what hints explain yet. Placing 5 in row 5, column 2." The button is "Place 5 · assisted". A hint never returns nothing.

Stats:
- Using the step-3 button to place or remove sets `assisted = true`. Undo never clears it (same as `usedReveal`).
- An assisted solve counts toward puzzles solved, total time and the streak. It does not count toward best or typical times (Section 3.3).
- Reveal Cell and Reveal Puzzle keep their own rule: `usedReveal` means the solve does not count at all.

#### 6.3.2 Reveal Cell

- If the selected cell is empty (`value == nil`, not given, not `isRevealed`):
  - Set `value` to the correct number from `solutionGrid`.
  - Set `isRevealed = true`.
  - Set `gameState.usedReveal = true`.

Tests:
- Unit, `revealCell()`: `value` matches `solutionGrid`, `isRevealed == true` and `usedReveal == true`.
- Unit, hint card:
  - A wrong entry is the first hint. Clear it empties the cell and does not set `assisted`.
  - With no notes anywhere, or with stale notes only (Tidy notes off), Hint returns a technique.
  - Each step advances the level by one, up to 3, with its label, button and marks. Steps 1–3 never change the board.
  - Placing from a hint sets `assisted`. One Undo reverts the board but leaves `assisted` set.
  - An assisted solve updates the streak and the counts but not best time.
  - The same board gives the same hint twice.
  - When the solver finds no step, the hint places the answer as assisted (not as a reveal).
  - Hidden singles come box, then row, then column.
- UI:
  - Tap Hint, step through the three steps (the keypad does not move), and tap Place. The board changes and Undo restores it.
  - A digit repeated in its row is the first hint. Clear it empties the cell.

#### 6.3.3 Coach (patterns on the player's board)

The coach shows the player what to look for on their own board. It does not give the next digit. The player finishes the puzzle and learns the technique's name and shape.

- `CoachSession` (in ViewModels) sits over `LogicalSolver.patterns(board)`. The list holds every technique that changes the board now, with one step per technique name (Hidden Single in a box or a line counts once). The list is ordered simplest first, in solver order, and uses the player's notes where they exist. The same board gives the same list.
- Opening:
  - From "All patterns" on step 1 of a technique hint, or from the Hint tool once the player is stuck (below).
  - A mistake (or clashing import entries) opens the mistake hint instead. With no pattern, the normal hint opens.
  - Opening clears the selection, like a hint.
- The card:
  - It fills the hint slot, so nothing moves.
  - It shows the technique name (serif), its Learn tier, "2 of 5" and ×.
  - The body names the pattern on this board and asks the player to find the move. It is `TechniqueStep.reason` plus "Can you find the digit it places?" (for placements) or "Can you see which candidates it rules out?" (for eliminations). It never gives the result away before Show me.
- The board shows the pattern as step 2 of a hint does: spotlight, pattern fill and ringed key candidates. It never relies on hue alone.
- Footer:
  - The ‹ and › buttons move between patterns. A pattern stays revealed once shown.
  - "What is it?" swaps the body for the technique's one-line definition. The pagers give way to "Back" and "Lesson →" (Section 12.5).
  - "Show me" reveals the move with step-3 marks and the step-3 text. Then "Place 5 · assisted", "Remove 5 · assisted" or "Apply · assisted" applies it exactly as the hint's step 3 does.
  - While the coach is open, the Hint tool reads "Show me", then "Apply".
- Stats and learning:
  - Browsing patterns is free. It is not a hint, does not set `assisted` and does not stop mastery credit. A player who then makes the move earns it (Section 12.4).
  - Show me counts as one hint per revealed pattern (hint log, rung 3). The app logs it when the coach closes, even after the player pages away. It also tells the learning ledger that the move was shown, like a hint.
  - Applying sets `assisted`.
- Stuck:
  - With "Coach when I'm stuck" on (Journal, Assists; default on), the app offers the coach after 120 s of play time without a new correct digit. Pauses do not count.
  - The hint slot then says "Stuck? Tap Coach to see the patterns on your board." The Hint tool reads "Coach" and opens the coach.
  - There is no flash, sound, vibration or pop-up.
  - A new correct digit, another puzzle, a restart or opening the coach starts the 120 s again.
- VoiceOver:
  - The card is a container.
  - The body reads the full text. After Show me, it reads the hint's step-3 text.
  - The position reads "Pattern 2 of 5".
  - The pagers are "Previous pattern" and "Next pattern".

Tests:
- Unit:
  - Patterns are distinct by name, start with the technique of `nextStep`, and all change the board.
  - Browsing is not a hint and does not report to the ledger.
  - Show me counts one hint per revealed pattern, also after paging away.
  - Applying is assisted and places the step.
  - Restart closes the coach.
  - The definition toggles.
  - A mistake opens the mistake hint.
  - Stuck starts after 120 s. A correct digit resets it, also after an undo. It is off when the setting is off.
  - The setting round-trips and defaults to on.
- UI: open a hint, tap All patterns, page forward, tap Show me, and apply. The board changes and Undo restores it.

### 6.4 Reveal Puzzle

- The player confirms first, with a custom confirmation.
- On confirm:
  - Fill all cells with the solution values.
  - Set `isRevealed = true` on all cells.
  - Set `usedReveal = true`.
  - Set `isCompleted = true`.

Tests:
- Unit: after `revealPuzzle()` on a partially filled board, every `cell.value` equals the solution, every `isRevealed` is true, and `usedReveal` and `isCompleted` are true.

### 6.5 Reset Puzzle (restart the same puzzle)

- "Restart puzzle" is in the More menu. It asks first with a custom confirmation, never a system dialog (Section 11.4).
- On confirm:
  - Reset the cells to the initial puzzle state.
  - Set `elapsedSeconds = 0`.
  - Set `usedReveal = false` and `isCompleted = false`.

Tests:
- Unit: fill some cells, set some candidates and flags, then call `resetPuzzle()`. Only given values remain. Candidates, flags and the timer are reset.

### 6.6 New Puzzle (same difficulty)

- "Another" on the Solved panel starts it. The puzzle is already solved, so the app does not ask first.
- It loads a new `SudokuPuzzle` of the same difficulty, creates a fresh `GameState`, and replaces the active game for that difficulty.

Tests:
- Unit: after `newPuzzle()`, `GameState.puzzle.id` is different (if more than one puzzle exists), and all cells match the new puzzle's `initialGrid`.

### 6.7 Undo

- `GameView` has an Undo action.
- Each user-facing edit pushes a snapshot onto an undo stack: value set or clear, candidate toggle, hint, Reveal Cell, Reveal Puzzle and reset.
- Applying a hint step is one edit, even when it removes many candidates at once.
- Tapping Undo restores the previous state. Repeated taps walk back to the first change.
- Undo is disabled when there is no history or the game is completed.

Tests:
- Unit:
  - After two sequential value edits, Undo restores the previous value. The next Undo clears it.
  - Undo reverts candidate toggles.
  - One Undo reverts a whole applied hint step.

## 7. Theme and UI modes

### 7.1 Appearance

Settings holds this enum:

```swift
enum Appearance: String, Codable {
    case light, dark, night
}
```

Two more settings work with it:

- `Settings.nightAfterDark`: Night from sunset to sunrise, whatever Appearance says by day.
- `Settings.adoptsSystemStyle`: true until the app first resolves Light or Dark from the system style.

The resolved look (`Look`) is Day (Light), Dark or Night. The app works it out on read and never saves it.

- The look is Night when Appearance is Night, or when Night after dark is on and the time is inside its window.
- Otherwise the look is Light or Dark, as chosen.
- A fresh install follows iOS until the first screen appears, then keeps the style it found (`AppController.adoptSystemStyleIfNeeded`).
- There is no "Match iPhone" choice.
- Only Night brings the bedtime behaviour: the backlight (11.3), Drift, the first-night flow and runtime silence (11.7).
- Dark is an ordinary theme. Sounds and haptics follow settings, the player's brightness is untouched and Clarity applies.
- The display side effects (UIKit colours, brightness, first night) refresh whenever the look changes, including Light to Dark.

Night after dark is on by default. `AfterDarkScheduler` decides the window:

- With location (`useLocationForAfterDark` is on and a place is known): sunset to sunrise. The device works it out with the NOAA solar equations. No network is used.
- The place comes from CoreLocation with reduced accuracy (`NSLocationDefaultAccuracyReduced`). The app asks only when the player turns Night after dark on or taps "Use sunset and sunrise". If permission was given earlier, the place refreshes at launch without asking.
- Without location (off, denied, not known yet, or a day with no sunset): fixed hours, 9:00 PM to 6:30 AM by default. The player edits them in the Display sheet. If permission is taken away, the app drops the cached place.
- Each local day uses one source: the sun when it rises and sets that day, else the fixed hours.
- A day's sun times are those of the solar day whose noon falls on that local day. This holds across the date line. Near the poles, the sunset may be after midnight.
- The next boundary is the first moment Night really changes. The candidates are every sunrise and sunset, every fixed-hour start and end (including the end of a window that began the day before), and every local midnight, where a day can change source.
- While the app runs, when Night first comes on in Day, the app shows the first-night flow. The flow closes the Night sheet and the camera picker first.
- Fixed hours are instants on the calendar. A wall time that happens twice (clocks go back) means its first occurrence. A skipped wall time (clocks go forward) means the next valid time. The Night check and the boundary list use the same rule.
- The maths uses a Gregorian calendar in the device's current time zone, whatever calendar the device shows.
- A one-shot timer fires at the next boundary. The app re-arms it after any settings change, a new place, a permission change, a clock change (`significantTimeChangeNotification`) or a time zone change.
- The palette then changes inside a 600 ms fade (instant with Reduce Motion).

Colour scheme and injection:

- Light pins the light colour scheme. Dark and Night pin the dark one. Until the app adopts the system style, it leaves Light and Dark to iOS, so it can read the style without feedback.
- The palette (`PSPalette`) and type scale (`PSType`) reach views through the SwiftUI environment (`psPalette`, `psType`) from the app root. Views never hard-code colours.

Migration of older saved settings (each runs once):

- Older appearance values map as follows: day to Light, night to Night, afterDark to Light with Night after dark on, matchSystem to the system style (`adoptsSystemStyle`).
- Theme values map as follows: light to Light, dark to Night, system to the system style.
- `sleepBrightness` normal, dim and extraDim map to glow 55, 30 and 18.
- The active display profile (the bedtime profile when `bedtimeMode` is on) then sets glow = (1 − dimness) × 60, and warmth.
- Theme sleep, or `bedtimeMode` on, gives Night with the Lights out preset. If `hasCalibratedDisplay` is true, the profile wins instead.
- `autoCheckMistakes` true maps to Right away. False maps to When I check.
- `autoRemoveCandidates` maps to `tidyNotes`.
- `hasCalibratedDisplay` maps to `calibrated`.

### 7.2 Visual rules

#### Look

- The look is floating glass controls over a plain board, with one accent colour.
- State shows by shape or weight, never by hue alone (see "State by shape" below).

#### Type

- Display text uses Bricolage Grotesque (`.serif` in `psFont`). Everything else uses DM Sans.
- Both fonts are bundled in `Resources/Fonts` under the SIL Open Font License, with their licence files.
- Bricolage ships in weights 500 and 800 only. DM Sans ships in 400, 500, 600 and 700.
- `psFont` loads the faces by their PostScript names, for example `BricolageGrotesque96ptExtraBold-ExtraBold` and `DMSans9pt-SemiBold`.
- `psFont` keeps Dynamic Type scaling. Bricolage at 21 pt and above tracks −0.02 em.
- Times and counts use tabular digits.
- Board digits and keypad digits follow Clarity, not Dynamic Type (Section 9).

| Style | Font | Size | Weight | Use |
|---|---|---|---|---|
| title | Bricolage | 33 | 800 | Large title on Home, Learn, Journal, Lesson |
| level | Bricolage | 24 | 800 | Level name on the Continue card, Up next name |
| heading | Bricolage | 21 | 800 | Technique names, hint title, game level |
| row | Bricolage | 19 | 800 | First line of a list row |
| key | Bricolage | 28 | 800 | Keypad digits |
| body | DM Sans | 15 | 400 | Hint and lesson text |
| button | DM Sans | 15 | 700 | Button labels |
| label | DM Sans | 13 | 500 | Secondary lines, section labels |
| caption | DM Sans | 11 | 600 | Tab and tool labels, key counts |

#### Clarity

Clarity (Standard, Large, Bold) applies in every look. It scales the board and keypad. `PSType` holds the values:

| | Standard | Large | Bold |
|---|---|---|---|
| Digit size, × cell × 0.62 | 1 | 1.1 | 1.2 |
| Candidate size, × cell × 0.24 | 1 | 1.12 | 1.25 |
| Line scale | 1 | 1.5 | 2 |
| Keypad digit, × 28 pt | 1 | 1.06 | 1.12 |

- Minor line = max(1, round(line scale)) pt. Box line = 1 + round(line scale) pt.
- Given digits are weight 800 at every Clarity. Entered digits are weight 500 at every Clarity, because the bundled Bricolage has no 600 or 700.
- Clarity also sets the Night floor (see the Night palette below).

#### Day palette (Light, fixed)

- bg #F2F2F7, surface #FFFFFF, surface2 #E5E5EA.
- ink #000000. ink2 and ink3 #63636A.
- accent #007580, accentDim #7FBAC0.
- line #D4D4DA (Clarity Large or Bold: #BCBCC2), lineMajor #3A3A3C, hair #D4D4DA.
- sel #CCE5E7, peer #E6F2F3, same #DBEDEF, err #C4281C.
- Roles: btnBg #007580, btnInk #FFFFFF, fill #767680 at 14%, focus #007C89 at 10%, glass white 62% with a white 90% edge, segment #FFFFFF, pill black 7%. edge, btnEdge and fillEdge are clear.

#### Dark palette (fixed, Appearance Dark)

- bg #000000, surface #151517, surface2 #2C2C2E.
- ink #F2F2F7. ink2 and ink3 #A1A1AA.
- accent #5AD4E6, accentDim #2D6A73.
- line #48484A. With Clarity Large or Bold, or Increase Contrast: #545458. Line is lighter than every cell fill, the focus tint included.
- lineMajor #7C7C82, hair #2C2C2E.
- sel #163337, peer #0A1719, same #0F2427, err #FF6B5E, status #F2F2F7.
- Increase Contrast also uses ink2 and ink3 #C7C7CC, lineMajor #A1A1AA and hair #3A3A3C.
- Roles: btnBg #5AD4E6, btnInk #00262B, fill #767680 at 30%, focus #5AD4E6 at 13%, glass #48484E at 50% with a white 16% edge, segment #636366, pill white 12%.
- Contrast rules:
  - Text (ink, ink2, ink3, accent, err) keeps 4.5:1 on bg, surface and surface2.
  - ink, accent and err keep 4.5:1 on every cell fill.
  - Notes, ghost digits, rings, the accent button and the toggle keep 3:1 against what they sit on. The off toggle outline is ink3 in Dark.
- Fills step plain < peer < same < sel by at least 5 L*. Peer stays darker than line.
- Dark follows the Day rules for fills (filled primary buttons, cards and selected segments).
- Cell fills sel, peer and same are kept for Night. Light and Dark use the focus tint on the board.

#### Glass

Glass is for floating controls only: the tab bar, the tool bar, the keypad and round navigation buttons. The board, cards and lists use surface.

- iOS 26 and later: system Liquid Glass.
- Earlier iOS: `.ultraThinMaterial`, a 1 pt glassEdge stroke and a soft shadow (offset 10 pt down, blur 30 pt, black at 14% in Light and 60% in Dark).
- Night: no material, no blur and no shadow. The fill is black, so content that scrolls under the tab bar never shows through. A 1 pt glassEdge outline draws the shape.
- Reduce Transparency: surface plus a hair stroke.

#### Controls

- Primary button: btnBg pill with btnInk bold 15 pt text, 44 pt tall. At night it has a 1.5 pt btnEdge outline.
- Secondary button: fill pill with accent text. At night it has a fillEdge outline.
- Segmented control: fill pill track. The selected segment is a pill in the segment colour. At night it is a btnEdge ring.
- Switch: 51 × 31 pt. On = btnBg track with a btnInk knob.
- Slider: 4 pt line track, accent progress, a 26 pt bg thumb with a 2 pt accent ring.

#### Night palette

The app computes the Night palette from glow, warmth and Clarity. Never hard-code it. The source of truth is `PureSudoku/Theme/NightPalette.swift`.

- K is warmth mapped from 6500 K to 1200 K, interpolated in mireds and rounded to 50 K. Warmth 0, 45, 75 and 100 give 6500, 2200, 1500 and 1200 K.
- base is the blackbody colour of K (Tanner Helland approximation). accent is the blackbody colour of warmth × 0.55 + 52.
- s = floor + (1 − floor) × min(1, glow / 40)^0.9. Above glow 40, glow drives the backlight (Section 11.3).
- floor is 0.20, 0.30 and 0.38 for Clarity Standard, Large and Bold. Increase Contrast uses the Bold floor.
- bg is always #000 (OLED pixels off). surface and surface2 are #000 too. Nothing is lit behind text. Cards are drawn by their outline.
- Every other token is base or accent times a fixed share of s:
  - ink 1, ink2 0.85, ink3 0.78.
  - accent 0.96, accentDim 0.65.
  - line 0.30, so lines show on the stepped cell fills. lineMajor 0.60. Both are multiplied by a Clarity lift: 1 (Standard), 1.25 (Large) and 1.5 (Bold).
  - err is #FF4640 × s × 0.95. status is base × s × 0.44.
  - hair and edge 0.25. focus 0.08.
- btnInk is accent. btnEdge is accentDim. fillEdge and glassEdge are edge. btnBg, fill, glass, segment and pill are clear.
- The cell fills are sel 0.33, same 0.25 and peer 0.17, all of accent, so the steps hold at any warmth.
- Fill rules at full strength: plain < peer < same < sel by at least 5 L*. Peer stays darker than line. No fill is brighter than ink.
- At full palette strength (glow 40 and up, any warmth and Clarity), every cell mark keeps at least 3:1 against the fill it sits on. Cell marks are digits, notes, mistakes, ghost digits and rings.
- Below glow 40, contrast follows the player's floor. Make no contrast claim there.
- Never use a black overlay to dim. It dims everything by the same amount and makes small marks unreadable first.

#### Night rules

- No filled shape sits behind text.
- Primary buttons are outlines (1.5 pt accentDim stroke, accent text).
- Cards are transparent with a 1 pt hair border.
- Popovers over the board (the More menu and confirmations) fill #000, so the board does not show through.
- The tab bar, tab headers, Home and Journal follow the same rules: hairlines, and no fills behind text at night. Day keeps the surface fill on cards.
- The app shows no system alert and no system sheet at night, because they flash. It uses its own sheets and confirmations. The one system alert is the iOS location permission prompt (Section 11.7). The camera and the Photos picker are system screens the player opens (Section 3.4).
- The launch screen is black in every look.

#### State by shape

Every state shows by shape or weight, not by hue alone, in Day and at Night:

- Selection: a filled background plus a heavier outline.
- Same digit: the same fill and weight 800. At Night, also a thinner, inset ring (Section 7.3).
- Error: an underline bar plus the err colour.
- Hint roles: rings for evidence and targets, strike-through for eliminations.
- Import: the app rings unsure cells and underlines conflicts. Each legend line has a matching ring or underline swatch (Section 3.4).
- Learn status: each row shows its status as text, Mastered (with an accent check), Learning, Up next or New. VoiceOver reads the status.

### 7.3 Grid interaction visuals

Selecting a cell highlights its background, row, column and box. Selecting a number highlights all cells with that number.

Duplicate entry follows Show mistakes:

- Right away: the app marks conflicting cells as errors at once (error marker, Section 7.2).
- When I check: only Check marks wrong digits.
- Never: nothing is marked, even after Check. Switching to Never clears existing marks.
- Check marks are saved with the game (`GameState.checkedWrong`). A Check mark stays until its cell is edited, in any mode. A duplicate mark never becomes a Check mark.

Cell states:

- Given: ink, Bricolage 800.
- Entered: accent, Bricolage 500.
- Digit size is 0.62 × the cell × Clarity (Section 7.2). The weight gap keeps givens and entries apart at night, where ink and accent are close in colour.
- Selected: a 2 pt solid accent ring, inset 3 pt, radius 9.
  - In Light and Dark, the selected cell and its peers (row, column, box) get the focus tint. The same digit elsewhere gets the same fill and goes to weight 800. Matching notes do too.
  - Night keeps stepped fills (sel, peer, same). The same digit also gets a 1.5 pt accent ring, inset 3 pt with radius 4. It shows by shape, so it never reads as the selection ring.
  - The same-digit ring is skipped on the selected cell and on hint evidence and target cells. Priority: selection ring, then hint rings, then same-digit ring.
  - The ring applies wherever the board is drawn: game, practice and import review.
- Mistake: the err digit plus a 3 pt bar under it, 120% of the digit's width. The bar is err by day and ink at night, where err and accent look alike. VoiceOver adds "mistake" to the cell's value, and "given" for givens.
- Notes: a 3×3 mini grid, inset 3 pt top and bottom and 4 pt left and right. Each digit has a fixed place. Notes use DM Sans 600 at cell × 0.24 in ink2. A note that matches the selected digit is bold. A hint's key notes are bold accent.

Hint marks:

- The unit and pattern cells get the focus tint. At night, pattern cells keep the same fill.
- Proof cells get a 2 pt solid accent ring. The target gets a 2 pt dashed accent ring. Both are inset 3 pt with radius 9.
- At the Why step, the answer shows in accent at weight 800 inside the dashed ring. A mistake gets the ring without the answer.
- Ruled-out cells get a 1 pt dotted ink3 ring.
- The game board does not dim other cells. In lessons, digits outside the step's cells are ink2 at weight 500.
- VoiceOver adds "proof" and "hint target" to those cells' values.
- By step: step 1 shows the unit. Step 2 adds the pattern. Step 3 adds proof rings, the target and struck eliminations.

Hint highlights fade in over about 0.15 s. They never blink or pulse. They stay until the player moves to another step or closes the card.

Testing requirements:

- Unit tests:
  - Appearance is saved and restored. Older settings migrate (Section 7.1).
  - The Night palettes for the three presets match the snapshots in `NightPaletteTests` within ±1 per channel. Night surfaces, fills, glass and the primary button are black or clear.
  - Light, Dark, Reading lamp and Lights out keep ink, ink2, accent and err at 4.5:1, and lineMajor at 3:1, on bg and surface. Red light is dim by design.
  - The bundled fonts load under the names `psFont` uses.
  - Kelvin for warmth 0, 45, 75 and 100 is 6500, 2200, 1500 and 1200.
- UI tests (basic):
  - Switch the theme to Dark. Check that the background or some key element changes.
  - Show mistakes: place a conflicting number. Check that an error indicator shows.

---

## 8. Persistence and local storage

All persistence is local and offline. Use either UserDefaults or local JSON files via `FileManager` and `Codable`.

Persist:

1. Active games (per difficulty): one `GameState` for each level. Save:
   - every few seconds (debounced),
   - when the app goes to the background,
   - when the player leaves GameView.
2. Settings (Section 7.1):
   - appearance, glow, warmth, clarity, glowFloor, calibrated
   - drift, hideStatusBarInGames, useLocationForAfterDark, afterDarkStart, afterDarkEnd
   - soundsEnabled, hapticsEnabled
   - mistakes, tidyNotes, showTimer
   - cell-name style
   - keepImportImages, showBuildNumber
   - Older keys (theme, bedtimeMode, sleepBrightness, display profiles, autoCheckMistakes, autoRemoveCandidates) are read once and mapped (Section 7.1). The app never writes them.
3. Technique progress: one `TechniqueProgress` per technique (Section 2.3).
4. Imported games (BYOS.md):
   - Every unfinished import is kept.
   - Only the 20 most recently played solved imports are kept. The app also keeps any solved import still waiting to hand off a late best time, until its count finishes. Older solved imports are dropped on the next save.
   - Unused import photos are cleaned up only when the set of photos in use changes, not on every autosave.
5. Stats:

```swift
struct Stats: Codable {
    var totalPuzzlesSolved: Int
    var puzzlesSolvedByDifficulty: [Difficulty: Int]
    var bestTimeByDifficulty: [Difficulty: Int?] // seconds
    var totalSecondsPlayed: Int
    var currentStreakDays: Int
    var lastSolvedDate: Date?
    // The next three decode with decodeIfPresent and defaults.
    var solveTimes: [Difficulty: [Int]]  // last 50 unassisted times per level, for Typical
    var assistedSolves: Int
    var solvedDays: [Date]               // last 14 days with a counted solve, for the Journal week
    // Schema version 2: decodeIfPresent, empty for older files.
    var countedGameIDs: Set<String>      // games whose solve is in the stats
}
```

Damaged files:

- A file that reads but cannot be decoded is moved aside as `name.corrupt-<time>.json`. That data starts over.
- Home then shows a calm notice: a hairline box, no fill, with an outline OK button. It names what was reset and says "The old data was kept on this iPhone."
- The notice comes from the set-aside copies on disk, so it cannot be lost. It lists every copy the player has not acknowledged.
- Tapping OK saves the copy names as acknowledged in `reset_notice.json`. If that save fails, or that file is damaged, the notice shows again at the next launch.
- A later corruption shows the notice again for the new copy only.

Failed saves:

- The app tracks a failed save per file (each level's game, stats, settings, learning, imports, pending solves).
- An entry clears only when a later save to that same file works.
- While any entry is left, Home shows a calm notice in the same box, with no button: "Some progress could not be saved. PureSudoku will keep trying."
- Load errors stay with the reset notice.

Solve handoff. A solve reaches the stats through a handoff that a failed save or a relaunch can retry. It cannot lose a solve or count it twice.

1. When a game is solved, the app first writes a `PendingCompletion` to `pending_completions.json`. It holds the game id, level, time, date, assisted, whether it sets times, and source.
2. The app applies it to the stats once (skipped if `countedGameIDs` has the id) and saves the stats.
3. Only then does the app save the game as counted and remove the pending record.
4. Any failure keeps the record. It retries on the next stats save and at launch, with its original time and date.
5. The app also saves the game with `solvedAt`, the solve's date.
6. If the record itself could not be written, the next launch rebuilds it from a finished, uncounted game that has `solvedAt`.
7. Games saved before `solvedAt` existed never qualify, so the app never counts them again.
8. Games counted before `countedGameIDs` existed are never counted again, because only a pending record adds a solve.
9. Revealed solves and replays write no pending record.

Streak and stats rules. A puzzle completed without `usedReveal`:

- Updates the counts.
- Updates the best time and adds to `solveTimes`, only if assisted is also false (Section 6.3). An assisted solve adds to `assistedSolves` instead.
- Adds the day to `solvedDays`.
- Adds to `totalSecondsPlayed`. Time on an unfinished level game counts too when a new game replaces it, so the total never goes down.

More rules:

- A puzzle with several solutions (an import that any valid fill solves) counts like an unassisted solve but sets no best or typical time.
- An old import solved while its solution count is still running gets its best and typical time when the count finds one solution (`Stats.recordTime`). It is not another solve.
- Each puzzle counts once. `GameState.counted` is set when its completion reaches the stats (so not for a revealed solve). It survives Restart (Section 6.5).
- A replay of a counted puzzle adds its time to `totalSecondsPlayed` but adds no solve.
- Saves from before the field existed read it as `isCompleted && !usedReveal`.
- Restart of an unfinished game keeps its time in `totalSecondsPlayed`.
- The streak compares `lastSolvedDate` with today, where a day runs from 4 am to 4 am.

Testing requirements:

- Unit tests:
  - Stats streak logic:
    - Solve on day N (no previous): streak = 1.
    - Solve again on day N+1: streak = 2.
    - Skip day N+2, solve on N+3: streak resets to 1.
  - Best time: a faster solve updates the best. A slower one does not.
  - A faster assisted solve does not update the best time, but does update counts and streak.
  - Persistence: save a `GameState` and `Stats`, reload them and check equality.
- UI tests:
  - Solve a very simple puzzle (pre-wire a nearly complete puzzle for the UI test). Return to Home and check the stats, for example that "Total puzzles solved" went up.

---

## 9. Validation and non-functional requirements

Performance and offline use:

- The app launches quickly. Interactions feel instant.
- The app works completely without network.
- Hint latency: a hint (one solver step) is ready within 50 ms on the oldest supported iPhone. Grading a puzzle may take longer but runs off the main thread.
- Hint correctness: no hint ever removes a correct candidate or places a wrong digit.

Testability and code organization:

- The Sudoku engine and view models are unit-testable without UI.
- Keep logic out of SwiftUI views. Move it to view models.
- Keep engine, models and view models in separate groups.

Accessibility:

- Dynamic Type: chrome text scales from the design's size at the default text size, following the nearest system text style. Chrome text covers screen titles, rows, cards, Home, Learn, lessons, Journal, the Display sheet, hint and confirmation cards, Import and First night.
- At accessibility sizes, a label and its control stack instead of sitting side by side. Button pairs stack. Screens that no longer fit scroll.
- The game screen still fits one screen. The header, the tool row and the Solved panel stop growing at xxxLarge. The board and the 1×9 keypad keep a fixed size. The board has its own Clarity sizes, and candidate marks keep their minimum size.
- Keypad keys, tools, header icons and tab bar items show the Large Content Viewer on a long press.
- At accessibility sizes, the hint slot also takes the free room above the tools. Hint text that still does not fit steps down one size, then scrolls. It never truncates.
- VoiceOver can play a full game. Each cell reads its row, column, and value or candidates. Hints read their explanation.
- Reduce Transparency and Reduce Motion: see Sections 7.2 and 7.1. With Reduce Motion, fades are instant, except the solved fade (150 ms, Section 3.2).
- If iOS Bold Text or Increase Contrast is on, raise the app's weight and contrast floors.

Colour contrast:

- Day: at least 4.5:1 for digits and text, and 3:1 for grid lines and large or bold text.
- Night: the player chooses the glow. It may go below 4.5:1, because a dark room needs less contrast. The Clarity floor still applies: ink is at least 20%, 30% and 38% of the full blackbody colour.
- Night with iOS Increase Contrast on: the palette uses the Bold floor and line lift.

Testing requirements:

- Unit tests, at least:
  - `SudokuValidator` tests.
  - `GameViewModel` tests (input, check, reveal, reset, completion).
  - Stats streak and time tests.
  - Persistence round-trip tests.
  - Solver correctness oracle: run the logical solver step by step over a seeded corpus of puzzles (400 generated puzzles, plus the bundled pre-graded puzzles). Check every elimination and placement against the known solution. Zero failures are allowed.
  - Hint latency: an XCTest `measure` benchmark for one hint on a hard board. The simulator baseline fails the test on a large regression. Each release also gets a manual check on the oldest supported iPhone (iPhone 8 for iOS 16).
- UI tests, core happy paths:
  - Launch, pick Easy, enter a few cells, go back.
  - Launch, pick Hard, toggle Notes mode, add a note, reset.
  - Check that the app does not crash and key elements are present.

---

## 10. Code layout

Source is in `PureSudoku/`. Tests are in `Tests/`. The Xcode project uses classic groups, so add each new `.swift` file to `project.pbxproj`.

- `Models/`: `Difficulty`, `SudokuCell`, `SudokuPuzzle`, `GameState`, `GameSource`, `ImportedGame`, `InputMode`, `Settings`, `Stats`, `TechniqueProgress`.
- `Engine/`:
  - Puzzles and checks: `SudokuValidator`, `SudokuPuzzleRepository`, `BundledPuzzles`, `SudokuGeneratorCore`, `SudokuGeneratorService`, `PuzzleGrader`, `Board`, `TimeProvider`.
  - Import: `SudokuImageDetector`.
  - Logical solver (Section 12.3): `SolverBoard` (bitset board, `House`), `TechniqueStep` (`Technique`, `TechniqueStep`, explanation text, graduated hint fields), `CellNotation` (cell and house names in hint text), `LogicalSolver` (`nextStep`, solve loop, tie-break).
  - Detectors by family: `SinglesAndIntersections`, `SubsetDetector`, `FishAndWings`, `AdvancedDetectors` (single-digit patterns, more wings, coloring, uniqueness), `Chains` (XY-Chain).
- `Theme/`:
  - `NightPalette` (`Appearance`, `Look`, `Clarity`, `PSType`, `PSPalette`, `Blackbody`, `NightPreset`).
  - `PSFont`, `SheetTheme`, `SystemAppearance`, `ScreenBrightnessController`, `DriftController`.
  - `AfterDarkScheduler` (`Coordinate`, `SunTimes`, `SolarCalculator`, `AfterDarkScheduler`).
- `ViewModels/`: `AppController`, `GameViewModel`, `HintSession`, `CoachSession`, `ImportPuzzleViewModel`, `Lesson` (`Lesson`, `LearnTier`, `LessonScript`: the four written lessons), `MainMenuViewModel`, `SettingsViewModel`, `StatsViewModel` (the Journal's numbers).
- `Views/`:
  - `MainMenuView` (the three tabs, `PSTabBar`, `ScreenHead`, `NightButton`).
  - `HomeView` (Continue card, level rows, saved imports).
  - `JournalView` (streak, week, solved table, Assists, More, About).
  - `GameView`, `SudokuGridView`, `NumberPadView`.
  - `GameChrome` (glass, tools, More menu, Solved panel, Hush and Goodnight).
  - `HintCardView`, `CoachCardView`.
  - `NightSheetView` (the Display sheet), `NightControls` (segments, switch, slider, cards, sample strip, `CalibrateView`), `FirstNightView`, `Settings+Theme`.
  - `LearnView` (`LearnView`, `LessonView`).
  - `ImportPuzzleView`, `ImagePicker` (camera).
  - `Icons/BedtimeIcon`, `OnChangeCompat`.
- `Persistence/`: `PersistenceManager`, `ImportedImageStore`.
- `Resources/`: `Fonts/` (Bricolage Grotesque, DM Sans, licence files) and `Media/`.
- `Assets.xcassets`: the app icon "The hint" is three single-size 1024 px images: Any (light), Dark and Tinted (luminosity appearances, iOS 18). There is no landing icon.
- `Tests/PureSudokuTests/`: unit tests for the engine, models, view models, stats, persistence, Night and Learn. `Fixtures/` holds test images.
- `Tests/PureSudokuUITests/`: UI tests for the main flows and Dynamic Type.

---

## 11. Night and bedtime use

The app is comfortable to use in bed, in the dark, without waking someone nearby. This needs strict limits on brightness, animation, sound and interaction.

### 11.1 Bedtime usage goals

- The app emits little light, especially blue light.
- It makes no sound and no haptics by default.
- It avoids sudden bright flashes, animations and popups.
- It works one-handed (thumb only) when the player lies on one side.
- The player can open the app and resume a puzzle in Night in 1–2 taps.
- The player can play for a while and put the phone down at once, with no extra prompts or dialogs.

### 11.2 Default silent behavior

Sounds:

- The app is completely silent by default.
- No click sounds on key presses.
- No "success" chimes when a puzzle ends.
- No error beeps.
- Any sound added later is off by default and controlled by a Settings toggle.

Haptics:

- No haptics by default.
- Any haptic added later is off by default and controlled by Settings.

Testing requirements:

- Manual or UI test: launch the app on a device with volume on and system haptics on. Use the keypad and Check, Reveal and Restart. Check that no sound and no vibration occur.

### 11.3 Night screen (Glow, Warmth, Clarity)

Night has three controls. Glow is how much light the screen gives off. Warmth is the colour. Clarity trades a higher floor for readability.

Glow (0–100) works in two layers, so the whole slider visibly changes the screen:

1. Glow 0–40: the screen backlight sits at its hardware minimum. The palette's luminance scale (Section 7.2) rises from the Clarity floor to full strength: s = floor + (1 − floor) × (glow / 40)^0.9.
2. Glow 40–100: the palette stays at full strength. `UIScreen` brightness rises in a straight line from its minimum to 0.6 at glow 100.

Backlight rules:

- While the app is in front in Night, it owns the backlight.
- The app restores the player's brightness when it goes to the background or Night ends.
- The app keeps its backlight while inactive (Control Center), so the screen does not flash.
- If the player changes brightness themselves, the app keeps their choice until Glow changes or they calibrate.
- Drift lowers the backlight too above glow 40, because it uses the drifted glow.
- "Find my lowest glow" holds the backlight at its minimum while it is on screen, by day as well, because its tiles show the palette layer alone.

Glow scale migration: settings saved before this scale (no `glowScale` key, or `glowScale` 1) map `glowFloor` to the same palette strength, 40 × (floor / 100)^(1.15 / 0.9). Glow restarts at Lights out, or at the floor if that is higher.

Warmth (0–100) is the colour temperature, 6500 K to 1200 K. Warmth is a comfort setting. The app must not claim that warm colours protect sleep.

Clarity (Standard, Large, Bold) gives bigger, heavier digits, stronger lines and a higher Night floor (Section 7.2).

Presets:

- Reading lamp: glow 70, warmth 45.
- Lights out: glow 55, warmth 55. This is the default. It is mid-range so a first night is readable, and its backlight sits above the hardware minimum.
- Red light: glow 30, warmth 100.
- Settings saved at the earlier Lights out (45, 65) move once to (55, 55). `lightsOutRevision` 2 records the move. Any other saved glow, warmth, floor or calibration stays.
- A preset never sets glow below `glowFloor`.

Find my lowest glow:

- It shows six 76 pt tiles drawn in the night ink at glow 0, 4, 8, 14, 22 and 32. All sit inside the palette layer.
- "Use this" sets `glowFloor` = the pick, glow = max(Lights out, pick + 4) and `calibrated` = true.
- The slider and presets never set glow below `glowFloor`.
- The heading reads "Which is the faintest you can read?" Under it: "Give your eyes a moment in the dark first. Tap the dimmest digit you can read without effort."
- At night its heading is ink3, as dim as the body, so the words do not outshine the tiles. On the first-night screen it is centred vertically.

First night (`FirstNightView`):

- It shows the first time Night is active while `calibrated` is false. It is a full black screen.
- Steps: a welcome, then Find my lowest glow (no Cancel), then a result.
- Welcome: a greeting, "Good morning." 5:00–11:59, "Good afternoon." 12:00–17:59, else "Good evening." It is separate from the Solved greeting (Section 3.2) and has its own hours. The body reads "Before your first puzzle, let’s set the screen for your eyes and this room. It takes twenty seconds, and nothing will flash."
- Result: "Glow set to N%.", a sample strip and Start playing. The body reads "Warmth is <Kelvin>. You can change both any time from the moon at the top of every screen."
- "Skip for now — use Lights out" applies Lights out and sets `calibrated`.
- It appears once. `calibrated` is saved before the result screen.
- It is drawn above everything. The camera picker closes first, the More menu closes, and a running game timer pauses until the flow ends.
- It keeps the Night palette for its whole run, even if Night ends while it is open.
- VoiceOver treats it as modal.
- UI tests launch with `-uiTestSkipFirstNight` (Debug only). `-uiTestFirstNight` starts in Day before the first night, to walk through the flow.

Drift (`DriftController`):

- During a night game with Drift on, every 90 s glow drops by 1 and warmth rises by 1, up to 20 each.
- Glow never goes below `glowFloor`. Drift never raises it.
- Drift is a session offset. The app never saves it. It resets when the game closes or Night ends. It also resets after a gap of 30 minutes or more between updates (for example, the app was away through a whole day).
- The change fades over 600 ms.

Limits the app respects: it cannot go below the system brightness minimum, cannot read room light, and cannot turn on Reduce White Point.

Testing requirements:

- Unit tests: palette snapshots, Kelvin mapping, Clarity floor, migration of older settings, and brightness lowered only in Night and restored afterwards.
- Unit tests:
  - NOAA sunrise and sunset within ±2 minutes of published times (London, 21 June 2024; New York, 21 December 2024).
  - No sun times in polar night.
  - After dark boundaries with and without location.
  - Edited fixed hours.
  - Drift steps, stops at 20 and never goes below the floor.
  - The first-night flow appears exactly once, also after a relaunch.
- Manual test: with Night on at minimum system brightness, no filled area anywhere renders brighter than ink, including sheets and menus.

### 11.4 Calm visual design

Animations:

- Avoid rapid, attention-grabbing animations.
- Use only subtle fades or scale where needed (for example, when presenting menus).
- Motion is limited to fades of 600 ms or less.
- Puzzle completion is a slow fade with no bright burst.

Errors and conflicts:

- Error marks are subtle: the err colour plus an underline bar under the digit.
- No large full-screen flashes. No rapid blinking.

Dialogs:

- Confirmations (Restart) are custom popovers in the app palette. They are never system dialogs, so they cannot render light at night.

Hint card and lessons:

- Highlights fade in slowly. Nothing blinks.
- The card never advances on its own. Every step waits for a tap.
- Lesson steps change with a 250 ms fade (none with Reduce Motion). Next and Practise are outline buttons at night.
- The only fill behind text in a lesson is the dim pattern tint (same) that game hints use too (Section 7.3). Everything else is lines and rings.
- VoiceOver announces each new step.
- Each step has one or two short lines. The card has a fixed height, and long text shrinks to fit.
- At night the card has no fill, only a hairline, and its button is an outline (Section 7.2).

Import (Section 3.4):

- Steps change with a 300 ms fade.
- The photo is capped at ink3 at night.
- The only fills are the dim outside the found grid (black) and the progress bar. Neither sits behind text.

Testing requirements:

- Manual test: in Night, trigger Check Puzzle with errors, and the Restart and Reveal dialogs. Check that there is no bright white flash and no flashing or blinking animation.

### 11.5 One-handed and in-bed ergonomics

Design for thumb-only use.

Layout:

- The grid is centred. The main controls are near the bottom of the screen.
- The keypad is at the bottom edge.
- The tools (Undo, Erase, Notes, Hint) sit just above the keypad.
- Less common actions sit in the More menu: Check cell, Check puzzle, Reveal cell, Fill all notes, Clear generated notes, Restart and Hush.
- The hint card sits just above the tools. Its button, and the Hint tool ("Next step"), are in the thumb zone. Every card control has a 44 pt target.

Tap targets:

- Every interactive element is at least about 44×44 points (Apple HIG).
- Exception: the 1×9 keypad keys are about 38 pt wide on a 390 pt phone, but 64 pt tall. The single row is a design decision.

Gestures:

- Primary interactions are simple taps.
- No required control uses a complex gesture, such as long-press plus drag.

Testing requirements:

- Manual ergonomic test: on a typical iPhone (for example a 6.1-inch device), hold the phone in one hand. Tap cells across the board. Use the keypad, switch Normal and Notes, and use Check and Restart. Confirm that the thumb reaches every essential action from a natural bed grip.

### 11.6 Quick exit and resume

Resume:

- If an incomplete puzzle exists at any difficulty, Home appears quickly with its Continue card.
- The Continue card opens the last game at once, with no loading spinner.

Exit:

- No blocking dialog appears when the player hits the Home indicator, backgrounds the app or locks the device.
- The game autosaves quietly.

Testing requirements:

- Unit or UI test: start a game, make a few moves, background the app, then foreground it. Check that the grid state and `elapsedSeconds` resume correctly. Check that no modal dialog appears on resume unless it is needed.

### 11.7 Night shortcut and silence

The moon on every tab, on Import and in the game header opens the Night sheet.

Display sheet (`NightSheetView`):

- It is a custom bottom panel, drawn over every screen from the app root. It is never a system sheet.
- Top radius 28, bg fill, hair top edge (edge at night), and a 36 × 5 grabber.
- The backdrop is black at 55% at night and in Dark, and 18% in Light. Tapping the backdrop, or Done, closes the sheet.
- At least 56 pt of backdrop always shows. The panel scrolls.
- VoiceOver treats the panel as modal. It fades in and out.
- The screen behind repaints live. Changing Appearance re-themes the sheet at once.

Contents, top to bottom:

1. "Display" (Bricolage 28) and Done.
2. A preview strip: two givens and two entries in the current settings.
3. Appearance: Light, Dark and Night segments. Below them, a card with "Night after dark" ("Switches at sunset, back at sunrise") and a switch.
   - When the switch is on (and Appearance is not Night), the card also shows tonight's sun times, or the fixed hours with − and + buttons (15-minute steps).
   - It also shows "Use fixed hours instead" or "Use sunset and sunrise".
4. Night (always shown, applies whenever Night is on): Reading lamp, Lights out and Red light segments. Then a card with:
   - Glow (slider and %),
   - Warmth (slider and Kelvin),
   - Clarity (Standard, Large, Bold),
   - Drift ("Dims and warms slowly over 30 minutes").
5. A secondary "Find my lowest glow" button. Calibration holds the backlight at its minimum while it is on screen, in any look.

Night drawing rules for the sheet:

- The selected segment is a btnEdge ring, not a fill.
- The slider knob is a 2 pt accent ring on black.
- The on switch is an outline with an accent knob.
- These follow the Night fill rules (Section 7.2).

Status bar and home indicator:

- At night the Display sheet, the first-night screen and every screen but the game hide the white system status bar.
- The game follows Hide status bar in games (`hideStatusBarInGames`). In a Night game the home indicator auto-hides.
- Hush, Goodnight and the first-night screen hide both, in Day as well.
- The game reports this to `AppController` (`hidesHomeIndicator`). The root view applies it.

System alerts:

- The one accepted system alert is the iOS location permission prompt.
- It appears only after the player turns Night after dark on, or taps "Use sunset and sunrise". It follows the dark colour scheme at night.

Hush and Goodnight (Section 3.2) go to pure black in one tap.

When Night is active:

- Sounds and haptics are off at runtime, whatever the saved settings say. The app keeps the saved choice for Day and Dark.
- Every screen uses the dark appearance, including sheets the app presents. Avoid system views that cannot be themed dark, because they flash white.
- The screen brightness is lowered (Section 11.3).
- The launch screen is black in every mode (iOS shows a static launch screen).

Testing requirements:

- Unit tests:
  - With Night active: `soundsActive` and `hapticsActive` are false, the palette is the Night palette, and the colour scheme is dark.
  - With Appearance Dark: `isNight` is false, the palette is Dark, the colour scheme is dark, brightness is untouched, sounds and haptics follow settings, and the first-night flow does not appear. Check the Dark palette contrast pairs and fill ladder (Section 7.2).
- UI tests:
  - Turn Night on from the moon on Home and open a game.
  - The moon opens the Display sheet on Home and in a game. Done and the backdrop close it.
  - Every control in the sheet can be reached, also at the largest text size.

---

## 12. Teaching and hints

The app teaches the solving techniques from the Sudoku literature. A hint teaches the next idea, not the next digit.

### 12.1 Goals

- Every hint names a real technique and shows why it works on the player's own board.
- The board changes only when the player chooses (Apply).
- Help fades as the player masters a technique. Full worked examples help beginners but slow experts down.
- All teaching content follows the bedtime rules of Section 11.

### 12.2 Curriculum

- Four grading tiers exist: Basic, Intermediate, Advanced and Expert (`TechniqueTier`). They set puzzle levels (Section 2.2).
- HINT_STRATEGIES.md holds the full ordered list, with a short definition and score for each technique. It is the source of truth for technique order.
- The solver tries techniques in that order, so it always finds the simplest available step first.
- Learn and the hint card group techniques into five Learn tiers (`LearnTier`):
  - Beginner: singles.
  - Intermediate: intersections and subsets.
  - Advanced: fish, wings and single-digit patterns.
  - Expert: XY-Chain and Simple Coloring.
  - Esoteric: Unique Rectangle types and BUG+1, which work only because the puzzle has one solution.
- The app does not teach Exocet, Sue de Coq, 3D Medusa or Bowman's Bingo. Learn lists the 27 techniques the solver knows. Hidden Single (box) and Hidden Single (line) are one lesson.
- Learn tiers never change grading.
- Some ideas are taught as short concept lessons before the techniques that need them: candidates, strong link, bivalue cell, almost locked set.
- Out of scope: Exocet, Franken, Mutant and Kraken fish, templates, Nishio, Bowman's Bingo, brute force.

### 12.3 Logical solver

The logical solver solves like a person, one step at a time. It is separate from the generator's solver.

`nextStep(board) -> TechniqueStep?` tries each technique in curriculum order and returns the first step it finds. The caller applies the step and asks again. This one loop drives hints, grading and drills.

`TechniqueStep` is a `Codable` value type. It holds:

- the technique and its tier,
- placements (cell, digit) and eliminations (cell, digit),
- houses, each with a role (base or cover),
- pattern cells, each with a role (defining, fin, pivot, pincer),
- links (from, to, strong or weak) for chains,
- explanation text.

The explanation text comes from the step's own data, with one template per technique. The technique is the template key. The step's digits, houses and cells are its arguments. This makes the text testable and translatable.

Rules:

- The board is a 9-bit candidate mask per cell, with static peer and house tables.
- The solver is deterministic. Within a technique, it prefers the instance with the fewest pattern cells, then the most eliminations, then the lowest cell index. It never depends on `Set` or `Dictionary` order.
- Steps stack: after each step, the next search starts from the updated candidates.
- A hint carries its whole pattern, so the board can show it, not only a target cell and a message.
- Uniqueness techniques run only when `hasUniqueSolution` is true (Section 2.1).
- If no technique applies, `nextStep` returns nil. The hint then places the answer as an assisted step (Section 6.3.1). The solver never guesses and never uses trial and error.
- A board that needs a technique the solver lacks gets the honest "beyond what hints explain yet" fallback.
- The logical solver feeds every hint.

XY-Chain (`ChainDetector`):

- An XY-Chain is a chain of two-candidate cells, each seeing the next and sharing one digit with it.
- If one end is not X, the links force the other end to be X. So any cell that sees both ends can't be X.
- The detector searches breadth-first from each two-candidate cell, so each end gets its shortest chain. It skips chains that pass a cell twice.
- It runs after every other technique, so hints and grades of puzzles that never needed it do not change.
- It is Expert tier, score 260.

Testing requirements:

- Unit tests:
  - Hand-made boards for the elimination techniques (Pointing, Claiming, Locked Pair and Triple, Naked Pair and Quad, Hidden Quad, X-Wing, Swordfish, XY-Wing): the detector returns exactly the expected eliminations. This catches a detector that finds too few. Hidden Pair, Hidden Triple and Naked Triple rely on the corpus oracle.
  - Correctness oracle: over a seeded corpus of generated puzzles (400, plus the bundled pre-graded puzzles), every step agrees with the known solution. The test re-checks each step's pattern against the board.
  - Same board, same step, every run.
  - A board that needs two techniques in a row (for example pointing, then a naked pair) yields both steps in order.
  - XY-Chain: a hand-made four-cell chain gives exactly the eliminations seen by both ends. The corpus oracle walks every XY-Chain step link by link.

### 12.4 Mastery

A technique is mastered at 10 credits. Each unaided move earns one credit.

A move earns a credit when, on the board just before the move, some step of some technique makes exactly that change. The move is a correct placement, or the removal of a wrong note. All of these must hold:

- no hint for that technique was shown in this puzzle,
- no hint in this puzzle showed that cell and digit,
- the move was not credited before in this puzzle under any technique,
- the board has no mistake.

Each credit carries the puzzle id taken with the move. A credit that lands after a new puzzle loads still counts for its own puzzle.

Credit goes to the simplest such technique (curriculum order). The check looks at every step, not only the first one `nextStep` returns. So techniques like Naked Single can earn credit even when another single comes first. The check runs off the main thread.

Moves from the hint card (Place · assisted, Remove · assisted, Apply · assisted) never earn credit.

The learning ledger (`LearningLedger`):

- It is the one store for these exclusions. `AppController` owns it. The game view model only reports hints and moves.
- It is saved in `technique_progress.json` together with the progress, as one atomic file: `{ progress, ledger }`. An older file that holds only the progress loads with an empty ledger.
- It holds:
  - credited moves ("puzzle|kind|cell|digit"),
  - hinted cells and digits ("puzzle|cell|digit"),
  - hinted techniques ("puzzle|technique"). This is the lesson technique, so a Hidden Single (box) hint also blocks line credit.
- A hint is written the moment it opens, so Undo, Restart, Continue and reopening a practice puzzle cannot lose it.
- Games saved before the ledger seed their hinted techniques from the hint log when opened.
- The puzzle key is the puzzle id. Practice puzzles use "practice-" plus the whole starting grid. So two bundled puzzles never share a key, and a practice puzzle reopened later is the same puzzle.
- At launch the ledger keeps practice keys and the keys of saved games (level games and imports), and drops the rest, so it stays small.
- It skips this cleanup while any level game or the imports file fails to load. It also skips it while a copy set aside as unreadable (`name.corrupt-<time>.json`) is on disk, since those games may still be restored on a later launch.
- If `technique_progress.json` fails to load, no move earns credit and the app does not write the file that session (hints are noted in memory only). Credits and exclusions share the file, so losing it loses both together. A credited move can never earn again on top of its old credit.

Strength and progress:

- Each technique has a strength value (0–1) that decays over time (half-life model).
- Strength rises once per puzzle where the technique is found unaided. It falls when a hint for it is needed.
- Hidden Single (line) progress is stored and shown as Hidden Single (box), one lesson. Saves that hold line progress on its own are merged in on read.
- Saves from before credits decode. They get one credit per puzzle found. A technique mastered under the old rule (3 puzzles on 3 days) keeps 10.
- When strength falls low, the Learn screen offers an optional review drill. There are no streak alarms and no notifications.

Testing requirements:

- Unit tests:
  - Mastered at 10 credits.
  - Old progress decodes and keeps its old mastery.
  - A manual placement credits the technique the engine would use for it, once.
  - Strength decays over time.
  - Hint card moves (placements and eliminations), and the cell a hint showed, earn nothing.

### 12.5 Learn screen

The Learn tab, top to bottom:

- The line "27 techniques in 5 tiers", the moon and "Learn".
- The Up next card: the first technique in curriculum order that is not mastered. It shows "Up next · Tier", the name (Bricolage 24, 800), its one-line definition and a primary "Start lesson". There is no card once everything is mastered.
- The five Learn tiers (Section 12.2), each a label and a grouped list. A row shows the name (Bricolage 19, 800), its status and a chevron. The status is Mastered (with an accent check), Learning, Up next or New.
- The one-line definitions (one per technique) show on the Up next card and in the lesson. They say "row, column or box", never "house".

A lesson is pushed, never a sheet:

- A round glass Back, and "Tier · lesson N of 27".
- The title (Bricolage 33, 800) and its one-line definition.
- The board: screen width − 12, drawn by `SudokuGridView` with the hint marks. Digits outside the step's cells are ink2 at 500, not faded. Key candidates are bold accent. Eliminated candidates are struck through in err.
- A step card with "Step N of M" and the step text (15 pt). The lesson scripts have no step titles yet, so the card has no heading.
- Back (secondary, 104 pt) and Next (primary). Next becomes Practise on the last step. Before the last step, a text button reads "Practise on a real puzzle".

Lesson content:

- Four lessons are written by hand as data (`LessonScript`): Hidden Single (5 steps), Pointing (4), Naked Pair (4) and X-Wing (4).
- Their boards are drawn for teaching, not taken from a puzzle. Their text uses plain cell names.
- The boards are real Sudoku. Every note shown is a true candidate. Every pattern is the digit's full set of places. The solver's own detector finds the lesson's step on that board (a unit test checks this).
- Every other lesson uses the template: a bundled puzzle solved up to the first step of that technique. It shows the three hint steps: where to look, why, and what changes (removals struck, the placement as a ghost digit). Its text follows the cell-name setting.

Practice:

- Practise opens the first bundled practice puzzle that needs the technique (from the drill index). For the template, it is not the example puzzle.
- Practice puzzles are not saved. They do not count toward stats or the streak. They do count toward learning (mastery and strength).
- Every technique hint links to its lesson at step 3 (Lesson).

Testing requirements:

- Unit tests:
  - The four written lessons load with 5, 4, 4 and 4 steps and the expected marks.
  - Every technique sits in one of the five Learn tiers.
- UI tests:
  - Learn shows the five tiers.
  - A lesson steps forward and back. Practise on the last step opens a puzzle.
  - The hint card's Lesson opens that technique's lesson. Back returns to the same game.
