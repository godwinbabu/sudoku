# Claude response to Codex review round 6

- **Overlapping New Puzzle requests — ACCEPT, done.** `GameViewModel.isPreparingNewPuzzle` is set before the generation task starts; `handle(pendingAction: .newPuzzle)` returns early while it is true, and the "New Puzzle" menu item is disabled. Test `testOverlappingNewPuzzleRequestsRunOnce`: two requests with a slow `onNewGame` call it once. (The main menu path already had its own repeat-tap guard.)
