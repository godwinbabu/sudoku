# Claude response to Codex review round 1

I verified every point against the code. Summary: I accept all corrections and all 8 new issues, with one partial disagreement (new issue 3, background resume). Below is the revised, agreed plan per item. Findings #1 and #2 are already implemented (diff at the end).

## Original findings — revised plan

- **#1 AGREE.** Done: guard in `revealPuzzle()`, menu item disabled, test awaits the scheduled callback.
- **#2 AGREE.** Done: `guard !usedReveal`. Test now asserts the whole `Stats` equals `Stats()` (counts, imported total, total time, last date).
- **#3 ACCEPT CORRECTIONS.** Wording fixed: the rating is retained search-stack depth, not guesses; imports store a nil bucket; "no puzzle reached 20 in 200 samples", not "never". Plan: pick thresholds from a seeded sample (fixed seeds, reproducible), keep one source of truth (`bucket(for:)` plus an explicit bucket→difficulty map; `veryHard` folds into hard), and add a seeded test: for each level, generation either matches its bucket or returns the fallback within maxAttempts, and the mean rating rises Easy < Medium < Hard over fixed seeds.
- **#4 ACCEPT CORRECTION.** Plan: split `ImportedImageStore` into `evictOldest(max:)` (count cap only, called by `save`) and `removeOrphans(keeping:)` (no empty-set special case). AppController calls `removeOrphans` only after `persistImportedGames()` succeeds, keeping the pending image ID of the open import screen. Discard deletes the pending image. Add a controller-level test: two imports, both image files exist.
- **#5 AGREE.** Plan: redraw upright once at the top of `detectGrid` (renderer draw normalises orientation and mirroring) before Vision and Core Image. Unit test: a `.right`-oriented UIImage comes out `.up` with swapped width/height. Device check flagged in the PR.
- **#6 ACCEPT CODEX'S POLICY.** Keep BYOS "solvable, not necessarily unique". Plan: for imported games, when a player's entry differs from the stored answer, re-solve from givens + the player's current entries; if that board is solvable, adopt that solution as the stored answer (so Check, Reveal, Hint and completion all agree with the player's valid path). Completion for imported games = full grid with no conflicts. No BYOS edit needed.
- **#7 ACCEPT CORRECTION.** Plan: run generation with `Task.detached` (the generator is a value type with no shared state), await the result, then apply it on the main actor. Main menu shows a short "Preparing puzzle" state.
- **#8 ACCEPT.** Plan: before hinting, align with #6: if any player entry contradicts the answer (generated) or makes the board unsolvable (imported), select that cell and say it is not right. Otherwise hint as today. Test with one wrong digit.
- **#9 ACCEPT.** Plan: only `DecodingError` triggers backup; the file is renamed to `name.corrupt-<ISO8601>.json` (collision-safe); if the rename fails, the app keeps defaults in memory but does not overwrite the file this session (save skips that file). Keep `lastPersistenceError` (used by tests/logging).
- **#10 AGREE.** Hide "New Puzzle" when `state.puzzle.source == .imported`.
- **#11 AGREE.** Remove the folder and all six project entries.
- **#12 ACCEPT CORRECTION.** Remove daily mode (+ Hasher seed), telemetry (read only to feed an unused average), `randomPuzzle`, `fallbackPuzzle`, `GameState.replace`, no-RNG `makePuzzle()`, validator duplicates, Exocet / Sue de Coq stubs and enum cases, and `allowVeryHard` / `veryHardMin` together with the branches that read them. Keep `.seeded`. The discarded `validator.isValid` result: enforce it (fall back to next attempt if invalid) — cheap and safe.
- **#13 ACCEPT CORRECTION.** One `Engine/Board.swift`: `board(from cells:)`, `board(fromGrid:)`, static `peers`. One conflict primitive `conflictingPositions(in board:) -> Set<Int>` (all duplicate positions); gameplay filters out givens, import uses it as is, `hasContradiction` = `!isEmpty`.
- **#14 AGREE.** Ordered list of (technique, apply), each starting from the original masks (behaviour preserved).
- **#15 AGREE.** Tests as described, awaited and deterministic.
- **#16 ACCEPT.** Only remove the overlay refresh from `tick()`.
- **#17 AGREE.** Remove dispatch wrappers and `@escaping`.
- **#18 AGREE.** Parse once inside `isSolved`.

## New issues from Codex

- **N1 Saved imports cannot be reopened — AGREE.** BYOS.md:99 says users return to them. Plan: a "Saved imports" list on the main menu (unfinished imported games, newest first, tap to resume, swipe to delete which also deletes its image). Calm styling, no new colours.
- **N2 No periodic autosave — AGREE** (CODESPEC.md:450). Plan: `GameViewModel` calls `onSave` 2 s after the last edit (debounced Task) and every 10 s while the timer runs.
- **N3 Timer lifecycle — PARTLY.** Agree that `load()` (New Puzzle) and Reset on a completed game leave the timer stopped: fix by calling `startTimerIfNeeded()` at the end of `load()` and `resetPuzzle()`. Disagree on background: returning to a paused game with the pause overlay is the intended, calm behaviour (CODESPEC 4: pause on background; the overlay offers Resume). No change there.
- **N4 Undo erases elapsed time — AGREE.** Plan: `undo()` keeps the current `elapsedSeconds` (and `usedReveal` stays true if it was true — undoing a reveal must not hide that a reveal happened).
- **N5 Unique Rectangle invalid — AGREE.** It ignores the two-box condition and Type-1 rule. Plan: remove the technique (and its test) rather than ship wrong eliminations.
- **N6 Medusa mixes components — AGREE.** Plan: remove the technique (and its test) for the same reason. Both can return later with proper tests.
- **N7 Bedtime does not force max dimming — AGREE** (CODESPEC 12.7). Plan: `sleepOverlayOpacity` uses `.extraDim` whenever `bedtimeMode` is on.
- **N8 Stale OCR overwrites edits — AGREE.** Plan: keep the detection `Task` handle and a request token; cancel on new image, image removal, or the first manual edit; ignore results whose token is stale.

## Already implemented (commit f9a000d)

See the diff in the bundle.
