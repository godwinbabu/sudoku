# BYOS (Bring Your Own Sudoku) – Design Doc

## Goals
- Let users import Sudoku puzzles from photos or screenshots, review/edit detection, validate, and start a normal game.
- Remain offline-only and privacy-first (no server uploads).
- Preserve calm, minimal UX and Bedtime-friendly visuals.

## Decisions (Confirmed)
- Imported puzzles **do** contribute to stats/streaks.
- Validation requires **solvable** (not necessarily unique).
- Keep images locally but prevent storage bloat.
- Imported games should be labeled in Stats UI.
- Unsolved imported puzzles are persisted separately (not just as active games).

---

## User Flow

1) **Main Menu**
- Add a new CTA: **“Import Puzzle”** (camera or photo library).

2) **Import Source Screen**
- Options: **Camera** or **Photo Library**.
- Tip text: “Center the grid, avoid notes, good lighting helps.”
- Cancel exits without changes.

3) **Processing Screen**
- Status: “Detecting grid… Reading digits…”
- If detection fails: show error + retry + manual grid entry option.

4) **Review & Edit Screen (Pre-Game)**
- Shows detected 9×9 grid; user can tap cells to correct values.
- Clear/reset tools and a numeric keypad.
- Inline validation:
  - Conflicts (row/col/box) are highlighted.
  - “Solvable” status shown (non-blocking until Start).
- **Discard** button to exit without saving.
- **Start Puzzle** enabled only when:
  - No conflicts, and
  - Solver confirms solvable.

5) **Game Start**
- Creates `GameState` and enters GameView.
- Grid becomes non-editable.
- Hints work as normal.

---

## Detection & Reconstruction (Offline Only)

### Preferred Pipeline (On-device)
1) **Grid detection**
   - Use `VNDetectRectanglesRequest` to find Sudoku boundary.
   - Perspective-correct the grid into a square.

2) **Cell extraction**
   - Split corrected grid into 81 equal cells.

3) **Digit recognition**
   - Option A (phase 2): Vision text recognition.
   - Option B (phase 3): Small CoreML digit classifier for higher accuracy.

4) **Ignore candidates/notes**
   - Reject small glyphs by bounding box area threshold.
   - Prefer centered glyphs (candidate notes are often cornered).
   - Use confidence threshold to keep uncertain cells empty.

If detection is partial or uncertain, still present the grid for manual correction.

---

## Validation Rules
- **Conflict check**: row/column/box duplicates.
- **Solvable check**: reuse existing solver to ensure at least one solution.
- Block “Start Puzzle” if invalid or unsolvable; allow edits until valid.

---

## Data Model & Persistence

### New Metadata
```swift
enum GameSource: String, Codable {
    case generated
    case imported
}
```

Extend `SudokuPuzzle` with:
- `source: GameSource`
- `importedAt: Date?`
- `importImageID: String?`

### Stats
- Imported puzzles **count** toward stats and streaks.
- Add a Stats UI label for imported totals (e.g., “Imported: 12”).

### Imported Puzzle Storage
- Persist imported puzzles separately from active games so users can return to them later.
- Track the imported puzzle list in local storage (e.g., `imported_puzzles.json`).

---

## Image Storage Policy (Prevent Bloat)

**Goal:** keep the “wow” factor (image preview/edit) without unbounded storage.

### Policy
- **Default limit:** keep the most recent **50 images**.
- **Size cap:** downscale to max **2048 px** on the longest side.
- **Compression:** JPEG at ~0.7 quality.
- **Cleanup:** on each new import:
  - delete oldest images beyond the limit.
  - remove any orphaned images not referenced by active/imported puzzles.

### User Control (Settings)
- “Keep import images” toggle (default: ON).
- “Clear imported images” action to delete all cached images.
- Optional: “Image cache size” indicator (MB).

### Tradeoffs
Pros:
- Keeps storage bounded and predictable.
- Still allows review and corrections.
Cons:
- Old imports may lose their original image (puzzle itself remains playable).

---

## UX Principles
- Clean, calm visuals; no flashing overlays.
- Sleep theme respected in all screens.
- Clear, actionable error messages.
- “Discard” always available before puzzle creation.

---

## Testing Plan (High-Level)

**Unit Tests**
- Import validation: conflicts and solvability.
- Persistence: imported puzzle metadata round-trip.
- Image cache cleanup policy.

**UI Tests**
- Import flow: select image -> review -> edit -> start -> play.
- Invalid puzzle blocks start.
- Discard exits without starting a game.

---

## Implementation Phases

**Phase 1: Manual BYOS (no OCR)**
- Add Import flow and Review/Edit grid screen.
- Validation + solvability checks.

**Phase 2: Basic OCR (Vision)**
- Rectangle detection + cell splitting.
- Vision text recognition.

**Phase 3: Custom Digit OCR**
- CoreML digit classifier.
- Better candidate/notes suppression.

**Phase 4: Heuristics & Polish**
- Confidence indicators.
- Better grid detection fallback.

---

## Open Items
- None. Ready for implementation.
