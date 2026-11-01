RESOLVED. The MainActor guard sets `isPreparingNewPuzzle` before launching generation, preventing overlapping confirmed requests; the menu also disables New Puzzle until completion. No concrete regression identified in this fix.

Source review only; commands and tests were not run.

VERDICT: ALIGNED