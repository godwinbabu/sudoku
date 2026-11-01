Static review only; no commands run or files changed.

#1 — AGREE

- Reason: [revealPuzzle()]( /Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:341) unconditionally schedules another completion callback, and [the menu item](/Users/godwin/projects/sudoku/PureSudoku/Views/GameView.swift:86) remains enabled. Repeated calls inflate counts and time; same-day calls do **not** increase the streak.
- Fix feedback: The guard and disabled menu item are minimal and appropriate. The regression test must await the scheduled callbacks before asserting their count.

#2 — AGREE

- Reason: [recordCompletion()](/Users/godwin/projects/sudoku/PureSudoku/Models/Stats.swift:22) ignores `usedReveal`, contradicting [CODESPEC.md:470](/Users/godwin/projects/sudoku/CODESPEC.md:470). [The test](/Users/godwin/projects/sudoku/Tests/PureSudokuTests/StatsTests.swift:15) explicitly asserts the incorrect behavior.
- Fix feedback: The early return is correct. Test that **all** stats remain unchanged, including counts, imported totals, total time, and last completion date.

#3 — PARTLY

- Reason: The supplied benchmark supports badly calibrated thresholds, and below-threshold candidates make Medium and Hard use the same maximum-rating selection logic ([SudokuGeneratorService.swift:66](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuGeneratorService.swift:66)). However, 200 samples do not establish “always,” arbitrary imports can rate above 20, generated puzzles retain their **requested** difficulty, and imports store a `nil` bucket ([AppController.swift:120](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:120)).
- Fix feedback: Recalibration is appropriate, but `1` and `3` are provisional thresholds. Use reproducible seeded samples, verify matching rates and bounded fallback behavior, and account for the existing `hardMax`/`veryHard` boundary. Also, this rating measures retained search-stack depth, rather than total guesses ([SudokuGeneratorCore.swift:34](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuGeneratorCore.swift:34)).

#4 — PARTLY

- Reason: The premature deletion is real: [saveImportedImage()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:155) cleans up before the new reference exists. However, removing the empty-ID exception as proposed would make [ImportedImageStore.save()](/Users/godwin/projects/sudoku/PureSudoku/Persistence/ImportedImageStore.swift:33) delete **every image, including the newly saved one**, through its own `cleanup(keeping: [])` call.
- Fix feedback: Separate image-count eviction from orphan cleanup. Preserve pending import images until commit/discard, then clean orphans after successful persistence; add the controller integration test and explicit discard cleanup.

#5 — AGREE

- Reason: [detectGrid()](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuImageDetector.swift:13) uses raw `cgImage` pixels without applying `UIImage.imageOrientation`; [Vision](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuImageDetector.swift:46) receives no orientation either. Non-upright images therefore have an actual orientation-handling defect, although its frequency has not been measured.
- Fix feedback: Normalize upright once before detection and warping. Passing orientation only to Vision is insufficient unless the subsequent Core Image coordinate handling is also made consistent; test rotated and mirrored inputs.

#6 — PARTLY

- Reason: The correctness mismatch is real: imports accept one solution ([AppController.swift:115](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:115)), while completion requires matching that particular solution ([SudokuValidator.swift:49](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuValidator.swift:49)). Such puzzles are finishable using the stored answer, but alternative valid completions are rejected.
- Fix feedback: Requiring uniqueness changes the confirmed policy in [BYOS.md:10](/Users/godwin/projects/sudoku/BYOS.md:10), and `checkPuzzle` is currently private ([SudokuGeneratorCore.swift:198](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuGeneratorCore.swift:198)). Preserve BYOS by accepting valid completed grids and making checks/hints/reveals consistent with the player’s extendable partial solution; uniqueness requires an explicit policy change.

#7 — AGREE

- Reason: [AppController.startNewGame()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:96) generates synchronously on `@MainActor`, reached directly from [the menu action](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/MainMenuViewModel.swift:36). The supplied timings establish a credible responsiveness problem, though they are not device measurements.
- Fix feedback: Calibrate difficulty and move generation off the main actor, publishing the result back on it. A plain `Task {}` created in this context inherits actor isolation and does not itself solve the blocking.

#8 — PARTLY

- Reason: [requestHint()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:294) reasons from current entries but autofills from the stored answer, so advice and inserted values can disagree. [Bowman’s Bingo](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuHintEngine.swift:772) also assumes that disproving one of two candidates proves the other, without first establishing that the current board is solvable.
- Fix feedback: Comparing against the answer is minimal for uniquely solved generated puzzles. For permitted nonunique imports, check whether current entries admit a solution instead; an alternative valid entry must not be labelled wrong.

#9 — AGREE

- Reason: Load failures become defaults in [AppController.swift:34](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:34), and later [atomic saves](/Users/godwin/projects/sudoku/PureSudoku/Persistence/PersistenceManager.swift:41) can overwrite the original files. No supplied view displays `lastPersistenceError`.
- Fix feedback: Preserve failed-decode files using collision-safe backup names before allowing replacement. Distinguish decoding failures from temporary read failures, and handle backup failure; blindly renaming every load error is insufficient. Retain or replace error reporting rather than simply deleting it.

#10 — AGREE

- Reason: [makeImportedGameViewModel()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:82) never assigns `onNewGame`, so [the confirmed action](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:445) does nothing.
- Fix feedback: Hiding the item for imported games is minimal. Exposing whether the view model supports the action would also avoid showing unsupported controls.

#11 — AGREE

- Reason: The supplied project excerpts include the folder in both resource phases, while [the repository](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuPuzzleRepository.swift:58) exclusively generates puzzles and the supplied resource-lookup search found no consumers. The exact 3.5 MB saving cannot be independently established from the excerpts.
- Fix feedback: Remove the unused resources and their project references. The supplied grep shows **six** associated project entries, rather than four.

#12 — PARTLY

- Reason: Most listed APIs have no callers in the supplied source, and [the daily seed](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuPuzzleRepository.swift:83) is unsuitable for stable cross-launch generation. However, telemetry **is read** during initialization ([SudokuPuzzleRepository.swift:34](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuPuzzleRepository.swift:34)), and `allowVeryHard`/`veryHardMin` are consulted by [active generation logic](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuGeneratorService.swift:150).
- Fix feedback: Removing unused features and placeholder techniques is reasonable. Remove their connected configuration and branches together; do not characterize referenced configuration as individually unused. Either enforce or remove the discarded validation result.

#13 — PARTLY

- Reason: Board conversion, peer calculation, and classification are duplicated, but the conflict routines have different contracts: import review needs [all conflicting indices](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/ImportPuzzleViewModel.swift:197), gameplay excludes givens, and `hasContradiction` returns only a Boolean ([SudokuValidator.swift:59](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuValidator.swift:59)).
- Fix feedback: Shared conversion and peer helpers are appropriate. Replacing import conflict detection with `hasContradiction` would lose highlighting; share a conflict-index primitive with explicit policies instead. Classification also needs an explicit mapping from bucket to difficulty.

#14 — AGREE

- Reason: [SudokuHintEngine.swift:48](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuHintEngine.swift:48) repeats the same wrapper thirteen times, including two no-op techniques.
- Fix feedback: An ordered list of technique/apply pairs is reasonable. Preserve the current behavior of starting each technique from the original candidate masks; accumulating eliminations would be a separate behavioral change.

#15 — AGREE

- Reason: The supplied tests do not protect against these four regressions: [the stats test](/Users/godwin/projects/sudoku/Tests/PureSudokuTests/StatsTests.swift:15) asserts the bug, [generation tests](/Users/godwin/projects/sudoku/Tests/PureSudokuTests/SudokuPuzzleRepositoryTests.swift:5) do not check difficulty separation, and [image tests](/Users/godwin/projects/sudoku/Tests/PureSudokuTests/ImportedImageStoreTests.swift:6) bypass controller ordering. The supplied unit files contain 34 test methods, rather than 27; their execution results are not verifiable here.
- Fix feedback: Add the proposed regressions, with awaited completion callbacks, deterministic generation inputs, and checks that actual referenced image files survive. A random average-only difficulty test is insufficient.

#16 — PARTLY

- Reason: Every tick publishes state and explicitly [recomputes candidates](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:550), including three board scans per empty cell ([GameViewModel.swift:567](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:567)). This invalidates dependent views, but does not prove that SwiftUI redraws all 81 cells.
- Fix feedback: Removing candidate refresh from `tick()` is correct and minimal. Separating timer publication is optional and should follow profiling.

#17 — AGREE

- Reason: [updateSettings()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:143) and [updateStats()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/AppController.swift:175) defer mutations despite already being main-actor isolated. Immediate reads therefore observe stale values.
- Fix feedback: Remove the dispatch wrappers and unnecessary `@escaping`. This also reduces the window between game completion persistence and stats persistence.

#18 — AGREE

- Reason: [isCorrect()](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuValidator.swift:36) reconstructs the character array for each checked editable cell in [isSolved()](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuValidator.swift:49). The repeated allocation is real but small.
- Fix feedback: Parse once locally within `isSolved`. Changing the persisted puzzle representation is unnecessary for this optimization.

Important missed issues:

1. **Saved imports cannot be reopened.** [MainMenuView.swift:80](/Users/godwin/projects/sudoku/PureSudoku/Views/MainMenuView.swift:80) offers a fresh import form, and [openImportedGame()](/Users/godwin/projects/sudoku/PureSudoku/Views/MainMenuView.swift:222) is reached only after creating an import; there is no saved-import list. Import a puzzle, leave it unfinished, and relaunch: its persisted progress has no accessible resume path, contrary to BYOS.

2. **There is no periodic gameplay autosave.** [tick()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:550) updates memory without saving; saves occur on disappearance, pause, or completion ([GameViewModel.swift:100](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:100)). Play for twenty minutes and crash before a lifecycle save: all those moves can disappear, contrary to CODESPEC’s every-few-seconds requirement.

3. **Timer lifecycle breaks after New Puzzle, completed-game Reset, and foregrounding.** [load()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:406) stops the timer without restarting it, and [resetPuzzle()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:371) does not restart a completed game’s stopped timer. Backgrounding also sets the manual-pause flag, while [the scene handler](/Users/godwin/projects/sudoku/PureSudoku/Views/GameView.swift:126) does nothing on `.active`: returning requires manual Resume, and new/reset games can remain playable with a frozen timer.

4. **Undo erases elapsed play time.** [recordUndoPoint()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:472) snapshots the entire state, and [undo()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/GameViewModel.swift:458) restores its old elapsed time without reconciling the running timer. Make an edit at 10 seconds, wait until 70 seconds, then Undo: elapsed time returns to 10 seconds, corrupting best times and totals.

5. **Unique Rectangle elimination is mathematically invalid.** [SudokuHintEngine.swift:645](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuHintEngine.swift:645) finds two matching bivalue corners and removes **extra digits** from the other corners, without valid uniqueness-pattern prerequisites. For example, masks `{3,5}` at r1c1/r1c2, `{3,4,5}` at r5c1, and `{2,3,5}` at r5c2 are compatible with the supplied solution, yet the helper removes its correct values `4` and `2`; disable this technique until correctly implemented and tested.

6. **Medusa combines unrelated coloring components.** [SudokuHintEngine.swift:684](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuHintEngine.swift:684) colors disconnected components into one dictionary, then applies [eliminations globally](/Users/godwin/projects/sudoku/PureSudoku/Engine/SudokuHintEngine.swift:698). A concrete candidate case is digit `5` restricted in column 5 to r1c5/r5c5 and in box 4 to r4c2/r5c1, with other masks unrestricted: independent component orientations can make r1c1 see opposite colors and lose `5`, although the supplied solution places `5` there. Track component identity and apply coloring rules within each component.

7. **Bedtime Mode does not force maximum dimming.** [Settings.swift:29](/Users/godwin/projects/sudoku/PureSudoku/Models/Settings.swift:29) leaves brightness unchanged, and [sleepOverlayOpacity](/Users/godwin/projects/sudoku/PureSudoku/Views/Settings+Theme.swift:22) directly uses that setting. Select Normal brightness and enable Bedtime Mode: overlay opacity remains zero, violating CODESPEC.md:696.

8. **Stale OCR tasks can overwrite newer input.** [updateImage()](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/ImportPuzzleViewModel.swift:121) launches detection without cancellation or request identity, and [completion](/Users/godwin/projects/sudoku/PureSudoku/ViewModels/ImportPuzzleViewModel.swift:161) unconditionally replaces the grid. Select a photo, then remove it and manually edit before detection finishes: the old result overwrites those edits; overlapping photo selections can likewise display one image with another image’s grid.

VERDICT: NOT ALIGNED