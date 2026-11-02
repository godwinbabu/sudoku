# Claude Code brief — implement PureSudoku 2

Paste this into Claude Code from the root of `godwinbabu/sudoku`, with this handoff folder available (for example, copied to `design/v2/` in the repo).

---

You are implementing the PureSudoku 2 redesign in this SwiftUI app. The design references are in `design/v2/` (or it could be Design/v2 treat them as alias):
- Start with `design/v2/README.md`: exact tokens, screens, states and copy.
- Then `design/v2/DESIGN_NOTES.md`: the reasons behind the design.
- `design/v2/ui_kits/puresudoku-2/All Screens.html` is the visual spec. Open it in a browser and match it.
- The HTML/JSX files are references, not code to ship.

Follow the repo's `CLAUDE.md` and `AGENTS.md`:
- Work on a feature branch and open PRs with `gh`. Never commit to `main`.
- Add every new `.swift` file to `project.pbxproj`: a PBXFileReference, a PBXBuildFile, an entry in its group, and an entry in the Sources phase.
- Use hand-assigned 24-hex IDs.
- Run `/run-tests` after every phase.
- Lint only the files you changed.
- Update `CODESPEC.md` sections 3, 7 and 12 to describe the new behaviour, in the same PR as the code.

Constraints that must hold everywhere:
- **Offline only.** No network. CoreLocation (reduced accuracy) is allowed, and only after the user picks After dark.
- **Night:** canvas `#000`. No filled shapes behind text. Buttons are outlines. No system alerts, dialogs or sheets that could render light. Status bar hidden in games. Sound and haptics forced off.
- **Never use hue alone to carry meaning.** Mistakes get an underline bar; hint evidence and targets get rings.
- **Motion:** fades only, 600 ms or less. Respect Reduce Motion.
- All hit targets are 44 pt or larger.

## Phase 1 — Theme foundation (one PR)
1. Add `Theme/NightPalette.swift`, ported from `design/v2/swift_reference/NightPalette.swift` (`PSPalette`, `PSType`, `Blackbody`, `NightPreset`).
2. Replace `ThemeColors` / `AppColors` usage with `PSPalette`, injected through an `EnvironmentValues.psPalette` and `psType`. Delete `SleepDimmingOverlay` and `SheetTheme`'s overlay.
3. Migrate `Settings` to the v2 fields (`swift_reference/SettingsV2.swift`). Use `decodeIfPresent` with defaults and map the old keys as documented.
4. Add `BrightnessController`: it sets `UIScreen.main.brightness` toward the floor while the app is active in Night, and restores it on background or terminate.
5. Make the launch screen black.
- **Tests:**
  - Palette values for the three presets match the snapshots in `design/v2/styles.css`, within ±1 per channel.
  - Kelvin for warmth 0 / 45 / 75 / 100 is 6500 / 2200 / 1500 / 1200.
  - Settings migration round-trips.
  - Bedtime keys map to Night with Lights out.

## Phase 2 — Game screen
1. Rebuild `SudokuGridView` as boxes and cells, with the line widths from the Clarity table and every cell state in the README table. Add the hint marks: focus spotlight, evidence ring, dashed target with ghost digit, pattern fill, ruled-out ring.
2. Rebuild `NumberPadView` as a 1×9 keypad with remaining counts, faded completed digits and the notes-mode layout.
3. Replace the mode chips and action grid with the 4-tool row: Undo, Erase, Notes (ON/OFF badge), Hint.
4. Header: back, level and timer (tap to pause), moon, More. The More menu is a custom popover: Check puzzle, Fill all notes, Restart puzzle, Hush screen.
5. Paused state; Hush (two-finger tap gesture plus the menu item); Solved panel; Goodnight.
- **Tests:**
  - UI: two-finger tap shows Hush.
  - Completed digit keys become disabled.
  - The Notes badge toggles.

## Phase 3 — Graduated hints and assisted solves
1. Extend the `SudokuHintEngine` output with: `nudge`, `technique`, `tier`, `short`, `why`, `focus`, `evidence`, `pattern`, `elim` and `target`. Match `engine.js`: check mistakes first, then singles (box before row before column), then locked candidates, then naked pairs, and so on.
2. Add a `CellNotation` formatter ("row 5, column 2" / "R5C2"; boxes "box 4" / "B4") and use it for every message. Get the article right ("an 8").
3. Add `HintCardView`, which fills the fixed 124 pt slot, with three steps and the "Place N · assisted" button.
4. Add `GameState.hints` and `GameState.assisted`. When a solve is assisted, `Stats.recordCompletion` keeps the streak and counts but skips the best and typical times. Reveal Puzzle stays fully excluded.
5. Add `techniquesNeeded(for:)`, which replays the hint engine from the givens, for the Solved summary.
- **Tests:**
  - A wrong entry is the first hint.
  - Each step's level advances correctly.
  - Placing from a hint sets `assisted`.
  - Assisted solves don't update the best time but do update the streak.
  - Notation strings are correct in both modes.

## Phase 4 — Night sheet, Display & Night, first night
1. `NightSheetView`, reachable from the moon on every screen: appearance segments, presets, Glow and Warmth sliders (with the Kelvin-gradient track), Clarity, Drift, and Find my lowest glow.
2. `DisplaySettingsView` (Journal → Display & Night): all sections in the README, including the After dark block.
3. `AfterDarkScheduler`: reduced-accuracy location, sunrise/sunset on the device (NOAA), fixed-hours fallback, and a timer that switches the palette at the boundary with a 600 ms fade.
4. `DriftController`: a session offset applied during night games (−1 glow / +1 warmth every 90 s, max 20 each, floored at `glowFloor`).
5. `FirstNightView`: welcome → calibrate (6 tiles at glow 0, 6, 14, 24, 38 and 56) → result. Shown when Night first activates and `calibrated == false`. Skip applies Lights out.
- **Tests:**
  - After dark boundaries with and without location.
  - Drift never goes below the floor.
  - The first-night flow appears exactly once.

## Phase 5 — App structure, Home, Journal, five levels
1. TabView: Play / Learn / Journal, styled per the README. Remove the main-menu bedtime bar.
2. `HomeView`: Continue card with a mini board, five level rows with tier glyphs and technique limits, and the Import row.
3. Add `.expert` and `.master` to `Difficulty`. Add generator rating buckets: Expert needs wings or fish, Master needs chains. Use the engine's hardest technique as the rating, and benchmark the way `docs/audit/bench-ratings.swift` does.
4. `JournalView`: streak and week, the solved table with the assisted line, Settings → Display & Night, Assists (mistakes mode, tidy notes, cell names, timer), and Privacy.
- **Tests:** the Expert and Master generators produce puzzles whose hardest technique matches the bucket.

## Phase 6 — Learn
1. `LearnView`: Up next and 17 techniques in 5 tiers, with mastery dots.
2. `LessonView`: a step-through diagram board, plus Practise. Port the four scripted lessons from `Learn.jsx` (Hidden Single, Pointing, Naked Pair, X-Wing) as data, and use the template for the rest.
3. Mastery: on each manual placement, credit the technique the engine would have used for that cell and digit. Mastered at 10 or more.
4. Link the hint card's "Lesson →" to `LessonView`.
- **Tests:** mastery credit happens only for unaided placements.

## Phase 7 — Import restyle and icon
1. Restyle the BYOS screens to the Source / Reading / Check-the-grid designs. Keep the existing logic.
2. Replace the `AppIcon.appiconset` images with `design/v2/assets/app-icon/AppIcon-{dark,light,tinted}-1024.png`, using the iOS 18 single-size Any, Dark and Tinted entries.

## Definition of done
- Every screen in `All Screens.html` matches in Day, the Lights out preset and the Red light preset. Check at Clarity Standard and Bold.
- With Night on at the minimum system brightness, no frame anywhere renders a filled area brighter than `ink`. That includes sheets, menus and keyboards; verify with screenshots.
- All unit and UI tests pass, and `CODESPEC.md` is updated.
