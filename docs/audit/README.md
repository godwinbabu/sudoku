# Audit, 1 Nov 2026

**Summary**
- Claude audited the repo and found 18 issues. Codex (GPT-6.1) reviewed them over 7 rounds and added 14 more. Both agreed on the final set.
- All agreed fixes are on branch `audit-fixes`, one commit per fix or group. Unit and UI tests pass on iPhone 18 Pro, iOS 27.2.
- Biggest wins: stats can't be faked, Medium and Hard are now harder, imported photos are kept, and games autosave.
- Needs a real device: reading a camera photo (#5) and the saved-imports list (N1).

## Files

| File | What it is |
|---|---|
| `claude-findings-v1.html` | The first audit report (18 findings) |
| `codex-review-rN.md` | Codex's review for each round (1–7) |
| `claude-response-rN.md` | Claude's reply and plan for each round |
| `codex-prompt-r1.md` | The instructions given to Codex |
| `bench-ratings.swift` | Benchmark behind the difficulty limits (#3) |
| `screenshots/` | Main menu, a Hard game, and the dimmed Settings and Stats sheets in Bedtime Mode |
| `bundles/` (not in git) | The full code bundles sent to Codex. Codex's own shell tool failed, so it read the code from these. |

## What changed

| Area | Fixes |
|---|---|
| Stats | Revealed or re-revealed puzzles no longer count (#1, #2). Completion is reported at once with the finished state. |
| Difficulty | New limits measured on 400 puzzles, documented in CODESPEC 2.2 (#3). Puzzles are made off the main thread (#7). Overlapping New Puzzle taps are ignored. |
| Import | Photos are kept until the game exists (#4). Camera photos are read upright (#5). Puzzles with several solutions accept any valid answer (#6). Late photo reads are ignored (N8). Unfinished imports are listed on the main menu (N1). Images are capped at 2048 pixels. |
| Play | Autosave (N2). The timer resumes after the app comes back and restarts after Reset or New Puzzle (N3). Undo keeps the time (N4). Check never un-flags a wrong value. Hints point at a wrong entry first (#8). |
| Hints | The technique list is a table (#14). Removed wrong Unique Rectangle and Medusa steps (N5, N6). Fixed Y-Wing. |
| Bedtime | Bedtime Mode forces maximum dimming (N7). Settings and Stats sheets get the Sleep palette and dimming. |
| Saves | A file that fails to load is moved aside, never overwritten (#9). |
| Cleanup | Removed 3.5 MB of unused puzzle JSON (#11), about 150 lines of unused code (#12), and 5 copies of board logic (#13). |

App Swift code is about 70 lines shorter overall, even with the new features.
