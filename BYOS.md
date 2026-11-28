# BYOS: Bring Your Own Sudoku

BYOS lets a player import a printed or on-screen puzzle as a photo, a screenshot or pasted text. The app reads the grid on the device, the player checks it, and a normal game starts. The screens, strings and tests are in CODESPEC 3.4. This file holds the goals, the reading pipeline, validation, data and photo storage.

## Goals

- Import a puzzle from a photo or screenshot, check the read, and start a normal game.
- Stay offline. The photo is read on the iPhone and never uploaded.
- Keep the visuals calm and the Night appearance intact.
- Count imported games in stats and streaks.
- Keep photos on the device without letting storage grow without limit.

## Reading pipeline

`SudokuImageDetector` runs on the device with Apple's Vision framework. Reading runs off the main thread and can be cancelled.

1. Orient the image. A camera photo is stored sideways with a rotation flag, so the detector redraws it upright first.
2. Find the grid. `VNDetectRectanglesRequest` looks for one near-square rectangle (aspect ratio 0.8–1.2, confidence at least 0.6). A perspective correction then flattens it into a square.
3. Fallback for a cropped screenshot. If no rectangle is found, the detector looks for the box around everything that differs from the page colour. The box must be roughly square (ratio 0.8–1.25). Otherwise the read fails with "grid not found".
4. Fit the grid lines. The detector fits ten evenly spaced lines on each axis to the dark pixel profile. Box lines are thicker, which tells the right fit from one shifted by a cell. A frame or margin around the grid does not move the edge cells.
5. Cut 81 cells. Each cell is cut twice: the whole cell, and an inner area with 18% trimmed from each side to drop the lines.
6. Normalise each cell to grey. Light digits on a dark fill are inverted, so every cell looks like dark ink on paper.
7. Read each cell with Vision text recognition, in fast mode first. A read counts as a digit only when it is one character, 1–9, and the text:
   - is at least 36% of the cell's height, which drops pencil-mark notes;
   - covers at least 6% of the cell's area;
   - sits near the cell's centre.
8. Read again when unsure. A cell with an unsure digit, with text seen but not read, or with ink but no read is read again from its inner area on a plain white margin, fast then accurate.
9. Settle the result. A sure read wins. Unsure reads that agree, with none that differ, count as sure. A lone "I", "l" or "|" reads as 1. One central character that is not a digit leaves the cell blank and ringed as unsure. Longer text or text near the edge counts as grid lines.

A read digit is unsure when its own Vision confidence (`VNRecognizedText.confidence`, not the observation's) is below 0.6.

If the read is partial or fails, the player still gets the grid to correct by hand. The 0.6 limit comes from simulator screenshots only. Tune it with real photos of printed puzzles.

## Validation

- Conflicts: a repeated digit in a row, column or box blocks Start.
- Clues: Start needs at least 10 digits.
- Solvable: the existing solver must find at least one solution. An unsolvable grid blocks Start.
- Solution count: the app counts solutions, stopping at 2, off the main thread. `hasUniqueSolution` is true only when the count is exactly 1. More than one solution does not block Start. The player sees a note.
- When `hasUniqueSolution` is false, hints skip the techniques that assume one solution: Unique Rectangle, BUG+1, Hidden and Avoidable Rectangle. Check and Reveal compare against a solution that fits the player's entries. See CODESPEC 2.1 and HINT_STRATEGIES.md.
- Grading: an import gets a level from the techniques it needs. A grid the solver cannot finish is Master (CODESPEC 2.2).

## Data model and persistence

- `SudokuPuzzle` carries `source` (`generated` or `imported`), `importedAt`, `importImageID` and `hasUniqueSolution`.
- An imported game is an `ImportedGame`: its `GameState`, `createdAt` and `lastOpened`. The list is saved in `imported_games.json`, apart from the games for each level.
- The app keeps every unfinished import and the 20 most recently played solved ones (CODESPEC 8).
- Imported puzzles count in stats and streaks. Stats keep a separate total of imported puzzles solved.
- If `imported_games.json` fails to load, the app skips photo cleanup for that session, because the photos may still belong to games in a saved copy.

## Photo storage

`ImportedImageStore` keeps photos in `Application Support/PureSudoku/ImportedImages`, one JPEG per photo, named by its ID.

- Longest side at most 2048 px, JPEG quality 0.7.
- The folder is excluded from backups. Photos stay on the iPhone.
- After a new photo is saved, the store deletes the oldest photos beyond 50. It never deletes a photo an import still shows, so the folder can hold more than 50.
- The app removes photos that no import uses. It scans only when the set of photos in use changes.
- If the list of imports is unknown (it failed to load), nothing is deleted.
- A photo that is never used is deleted when the player leaves Import.
- Journal has "Keep import photos" (default on) and "Imported photos: Clear". See CODESPEC 3.3.
- An old import can lose its photo. The puzzle stays playable.

## Open items

- Tune the unsure limit with real photos of printed puzzles.
- No on-device digit classifier exists. Vision text recognition reads every digit. A trained classifier could read thin 1s and faint print better.
- Journal does not show the size of the photo store.
