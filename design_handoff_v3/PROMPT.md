# Kickoff prompt for Claude Code

You are implementing the v3 redesign of this iPhone Sudoku app (SwiftUI). The app is being renamed from PureSudoku to **Sudoku Masters**. Everything you need is in this folder, `design_handoff_v3/`.

## Read first, in this order

1. `HANDOFF.md` — the full spec: themes, tokens, every screen, states, accessibility, and the phased plan.
2. `screens/*.png` — reference renders of every screen in light, dark and night (390 × 844 pt at 2x). Look at them; they are the target.
3. `tokens.json` and `reference/V3Palette.swift` — exact colour, type, spacing and radius values.
4. `design-system/` — the brand book and per-component guidelines.
5. `source/*.dc.html` — the design source for each screen. The CSS in each file is exact; use it to settle any measurement the PNGs leave unclear. Ignore the `sc-for` / `{{ }}` templating.

Then read the app's own code before planning: at least the views, view models, `Theme/`, `Models/Settings.swift`, `AppTheme.swift`, and `Engine/`. The file map in `HANDOFF.md` section 9 was written without access to this repository, so treat it as a guess and correct it.

## How to work

- Create a branch `v3-redesign` and work only there.
- Before writing code, reply with a short plan: what exists today for each screen, what you will change, what you are unsure about. Wait for my go-ahead.
- Work one phase at a time, in the order in `HANDOFF.md` section 10. After each phase: build, run the tests, launch in the simulator, take a screenshot of the screen you changed in light, dark and night, compare it to the reference PNG, fix differences, then commit and stop for my review.
- This is a visual and settings-model redesign. Do not change puzzle generation, solving, hint logic, saved-game format or stats storage unless `HANDOFF.md` says so. If a change seems to need it, stop and ask.
- Do not change the bundle identifier, the Xcode target name or the module name. The rename is the display name only.
- Keep every existing test passing. Add tests for anything you add to the settings model.
- If the spec and the existing code disagree, or something is not specified, ask rather than guess. List open questions at the end of each phase.

Start now with the reading and the plan.
