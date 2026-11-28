# AGENTS

PureSudoku is an offline iPhone Sudoku app. It is comfortable to use in bed, in the dark, without waking someone nearby. These rules apply to every coding agent.

## Source of truth

- Read `CODESPEC.md` before any task. Search it for the sections your change touches.
- Do not build behaviour that contradicts `CODESPEC.md`.
- If a request conflicts with the spec, adapt the request to the spec. Or ask the user whether to change the spec, then update the tests to match.
- If the spec is silent, follow its spirit: minimal, offline, calm. For a significant change, suggest a spec update first.
- If two spec rules conflict, follow the most recent and most specific one.

## Fixed rules

- Offline only. Add no backend, network call, remote analytics or cloud sync unless the spec says so.
- Display name: `Sudoku Masters`. Code name: `PureSudoku`. Keep the code name in the targets, the module and the tests (`PureSudokuTests`, `PureSudokuUITests`).
- Do not rename the app or change the bundle id unless the user asks.
- Do not build a future feature until it is in `CODESPEC.md`.

## Night and calm

Night (CODESPEC 11.3, 11.7) is a core feature. Check every new feature against these rules.

- Add no sound effects, haptics, flashes or bright full-screen overlays. If one is needed, keep it off by default and put it behind a setting that follows the spec.
- Animations are subtle. Error marks are gentle.
- While Night is on:
  - Use the Night palette and a dark colour scheme on every screen, including sheets. Avoid system views that flash white.
  - No fill is brighter than the ink.
  - `soundsActive` and `hapticsActive` are false, whatever the saved settings say.
  - Follow the player's Glow, never below `glowFloor`. Restore their brightness when the app goes to the background or Night ends.
  - Hush and Goodnight go to pure black in one tap.
- Do not claim that warm colours protect sleep.

## Architecture

- Use MVVM with SwiftUI.
- Put logic in `Engine/`, `Models/` and `ViewModels/`. Keep views simple: they show state and forward user actions.
- Prefer clear, small types over clever code. Follow Apple and Swift style guides.
- Do not hardcode behaviour that the spec makes configurable (for example auto-remove notes or auto-check mistakes).
- Keep models as plain `Codable` types. Treat persistence as an adapter around them.

Layout: `PureSudoku/` holds `Models/`, `Engine/`, `ViewModels/`, `Views/`, `Theme/` and `Persistence/`. Tests are in `Tests/`.

## UI

- Make tap targets at least 44x44 pt.
- Keep the keypad and key actions at the bottom, in reach of one hand.
- For a major visual change, check Light, Dark and Night at low Glow. Check Night that comes from After dark too.

## Workflow

1. Read the request. Read the relevant `CODESPEC.md` sections. Check the existing code and tests.
2. Change the engine and view models first. Then change the views.
3. Update persistence for any model you change (`GameState`, `Stats`, `Settings`).
4. Add or update tests, then run the full suite.

## Tests

Tests are mandatory.

- Add unit tests for every feature or fix: logic, state, persistence, stats. Add a regression test for each bug.
- Add UI tests when a user-visible flow changes. Use accessibility identifiers. Avoid exact-text checks where you can.
- Never delete a test without a strong reason that the spec backs.
- Cover these areas:
  - Engine: row, column and box validation, completion.
  - Game state: Normal and Notes mode, check, reveal, reset, new puzzle, timer start, pause and resume.
  - Stats: streak, best time per difficulty, total time, puzzles solved.
  - Persistence: save and load equality for `GameState` and `Stats`. Settings (appearance, glow, warmth, `glowFloor`, toggles).
  - Night: the rules above, and the first-night flow appears exactly once.

## Refactors

- Run the tests before and after. If they fail, fix the cause or roll back.
- Change only what the design needs.
- Keep behaviour the same: UX, data formats and visible strings stay unless the spec or the user asks.
