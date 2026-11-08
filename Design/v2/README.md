# Handoff: PureSudoku 2 — full app redesign

## Overview
This is a redesign of the PureSudoku iPhone app (`github.com/godwinbabu/sudoku`, SwiftUI, iOS 16+, MVVM). The goals:
1. **Bedtime-safe play.** Continuous Night controls (Glow, Warmth, Clarity) replace the theme picker, Bedtime toggle and 3-step brightness. A true-black canvas, no lit fills, and quick ways to go dark.
2. **Teach real technique.** Graduated hints (Where → Which technique → Why → Place) and a new **Learn** tab with 17 techniques in 5 tiers.
3. **A calmer, more precise game screen.** A 1×9 keypad with remaining counts, a 4-tool row, and a fixed hint slot.
4. **Five difficulty levels**, each labelled by the hardest technique it needs. A **Journal** tab (stats + settings), a restyled import flow, and a **new app icon**.

Rationale, principles and every decision are in `DESIGN_NOTES.md`. Read it first. Paste-ready Claude Code instructions are in `CLAUDE_CODE_PROMPT.md`.

## About the design files
The HTML/JSX files here are **design references**: prototypes that show the intended look and behaviour. They are not code to ship. The task is to **recreate them in the existing SwiftUI codebase**, using its patterns: MVVM, `AppController`, `PersistenceManager`, XCTest. Two pieces are exact and should be ported, not re-invented:
- `ui_kits/puresudoku-2/night.js` — the Night colour maths. It is already ported to `swift_reference/NightPalette.swift`.
- `ui_kits/puresudoku-2/engine.js` — the hint *copy and structure* (nudge / technique / why / evidence cells). The real engine stays `Engine/SudokuHintEngine.swift`; extend its `GeneratorHint` output to carry the same fields.

## Fidelity
**High fidelity.** Colours, type, spacing, states and copy are final. Recreate them pixel-for-pixel, using SF Pro and New York (system fonts, already on iOS) and SF Symbols. Two things are approximations: the prototype draws its icons as SVG (use the SF Symbols mapped below), and on non-Apple machines it falls back to Newsreader.

## How to view
Open the files in a desktop browser. A Mac with Safari or Chrome shows the real system fonts.
- `ui_kits/puresudoku-2/index.html` — the clickable app. Two-finger tap or the **H** key = Hush.
- `ui_kits/puresudoku-2/All Screens.html` — 38 static screens in 6 rows (pan/zoom canvas). **This is the spec sheet.**
- `ui_kits/puresudoku-2/App Flow.html` — the first-night, settings and assisted-solve flows.
- `assets/app-icon/app-icon.html` — the final icon in all three variants.
- `preview/*.html`, `components/*/*.html` — token and component cards.
- `current_app_screenshots/` — the app before the redesign, for comparison.

---

## Design tokens

### Fonts
- UI and digits: **SF Pro** (`.system`). Display/titles: **New York** (`.system(design: .serif)`, weight `.medium`, tracking −1%).
- Use New York only for: screen titles (30), the wordmark, technique names (21 in hints, 24–34 in Learn), *Solved.* (44), *Paused* (28), the Journal streak number (56), first-night headings (36) and "Sleep well." (30).
- Section labels: 11–12 pt, `.semibold`, uppercase, tracking +8%, `ink3`.
- All numbers use `.monospacedDigit()`.

| Style | Size | Weight | Notes |
|---|---|---|---|
| Solved | 44 | NY medium | |
| Screen title | 30 | NY medium | |
| Lesson title | 34 | NY medium | line-height 1.1 |
| Card title | 24 | NY medium | Continue card, Up next |
| Technique (hint) | 21 | NY medium | |
| Body / list title | 16–17 | regular | |
| Secondary | 15 | regular | |
| Footnote | 13 | regular | `ink3` |
| Label | 11 | semibold | uppercase, +8% tracking |
| Keypad digit | 30 × uiScale | regular | |
| Keypad count | 10.5 | medium | `ink3`, tabular |
| Tool label | 11 | medium | |

### Day palette (fixed)
`bg #F4F1E9` · `surface #EBE6DA` · `surface2 #E2DCCD` · `ink #1B1A17` · `ink2 #57534B` · `ink3 #8A857A` · `accent #9A5712` · `accentDim #C9A27A` · `line #CFC8B8` (Clarity ≥ Large: `#B9B1A0`) · `lineMajor #2E2B25` · `hair #D8D1C1` · `sel #EFD9B0` · `peer #ECE6D9` · `same #F1E2C6` · `err #B3261E` · `focusDim 0.28`

### Night palette (computed — never hard-code)
```
K      = kelvin(warmth)  : mired-interpolated 6500 → 1200 K, rounded to 50 K
base   = blackbody(K)    : Tanner Helland approximation (0…255)
accent = blackbody(kelvin(min(100, 0.55·warmth + 52)))
s      = floor + (1 − floor) · min(1, glow/40)^0.9  floor = 0.20 / 0.30 / 0.38 (Clarity)
lift   = 1 / 1.25 / 1.5 (Clarity)
```
| Token | Value |
|---|---|
| bg | `#000000` always |
| surface / surface2 | base × 0.07s / 0.11s |
| ink / ink2 / ink3 | base × s / 0.78s / 0.62s |
| accent / accentDim | accent × 0.96s / 0.65s |
| line / lineMajor | base × 0.22s·lift / 0.60s·lift |
| hair | base × 0.25s |
| sel / same / peer | accent × 0.20s / accent × 0.12s / base × 0.055s |
| err | (255, 70, 64) × 0.95s |
| status (status bar on non-game screens) | base × 0.44s |
| focusDim | 0.22 |

Presets: **Reading lamp** (glow 70, warmth 45 → 2200 K), **Lights out** (45, 65, the default), **Red light** (30, 100 → 1200 K). Glow above 40 also raises the screen backlight (CODESPEC 12.3). The `styles.css` preset snapshots predate this scale and are superseded by `NightPaletteTests`.

**Night rules** (required, and testable):
- No filled shapes behind text.
- Primary buttons are outlines: 1.5 pt `accentDim` stroke, `accent` text.
- Cards are transparent with a 1 pt `hair` border.
- Switches show an outline track with an `accent` knob.
- Keys have no background.

### Clarity (Day and Night)
| | Standard | Large | Bold |
|---|---|---|---|
| Digit size | cell × 0.60 | × 0.66 | × 0.72 |
| Given weight | semibold | bold | heavy |
| Entered weight | regular | medium | semibold |
| Candidate size | cell × 0.25 | × 0.28 | × 0.31 |
| Minor / box line | 1 / 2 pt | 2 / 3 pt | 2 / 3 pt |
| Keypad digit | 30 | 31.8 | 33.6 |
| Night glow floor | 0.20 | 0.30 | 0.38 |

### Spacing, radii, sizes
- Spacing: 4 · 8 · 12 · 16 · 22 (screen side inset) · 28 · 40.
- Radii: cell marks 4 · board 6 · key/tool 12 · card 18 · sheet top 28 · pill 999.
- Minimum hit target: 44 pt.
- Reference device: 390 × 844 pt (iPhone 15/16). Status area: 54 pt. Tab bar: 84 pt (with 8 pt top padding, includes the home indicator).
- Shadows: none in the app UI. Depth comes from hairlines.

### Motion
- Fades only, 150 ms (UI state) to 600 ms (the board dimming to 30% on solve).
- The launch screen is black. Day mode fades up from black over 300 ms.
- No spring, scale or confetti. Respect Reduce Motion: make fades instant.

---

## Screens
The All Screens IDs are in brackets. Measurements are at 390 pt width.

### Arrive
- **Launch [1.3]:** pure black with "Pure Sudoku" in New York 30 at `ink3`. The `UILaunchScreen` background is black.
- **First night — welcome [1.4]:** shown when Night first becomes active and `calibrated == false`. 30 pt side padding; top padding 150.
  - Moon symbol 30 pt `accent`, then "Good evening." (NY 36), then body 17 `ink2`: *"Before your first puzzle, let's set the screen for your eyes and this room. It takes twenty seconds, and nothing will flash."*
  - Pinned to the bottom: a full-width 50 pt primary button **Find my lowest glow**, and the text link *"Skip for now — use Lights out"* (15, `ink3`). Skipping sets glow 18 / warmth 75 and `calibrated = true`.
- **Find my lowest glow [1.5]:** title *"Which is the faintest you can read?"* (NY 24), then hint text 14 `ink3`.
  - Six 76 pt-tall tiles in a row (8 pt gap, radius 12, 1 pt `hair` ring). Each shows a digit (8, 3, 6, 5, 9, 2) in the night `ink` computed at glow 0 / 6 / 14 / 24 / 38 / 56.
  - The selected tile gets a 2 pt `accent` ring.
  - **Use this** sets `glowFloor = pick` and `glow = max(Lights out, pick + 4)`. First-run shows no Cancel.
- **Result [1.6]:** *"Glow set to N%."* (NY 36), a line giving the Kelvin value, a 5-cell sample strip, and **Start playing**.

### Play tab (Home) [2.1, 2.2]
- Header row, 52 pt: "Pure Sudoku" (NY 30) on the left; the moon button (44 pt, `moon` SF Symbol) on the right.
- Sub-line: *"Saturday night · 6-night streak"* (14, `ink3`), 22 pt inset, 20 pt below.
- **Continue card** (only if an unfinished game exists):
  - 16 pt margin, 14 pt padding, radius 18. Mini board 112 pt (non-interactive) on the left, 16 pt gap.
  - Text: label "CONTINUE", the level in NY 24, *"6:52 · 44 of 81"* (14, `ink2`), and a 3 pt progress bar (`hair` track, `accentDim` fill).
  - Tap opens that game.
- **NEW PUZZLE** label, then 5 rows, each 64 pt, with `hair` dividers:
  - On the left, a tier glyph: 5 bars 3 pt wide, 3 pt gap, heights 6.6 / 9.2 / 11.8 / 14.4 / 17, the first N bars `accent` and the rest `hair`.
  - Then the level name (17 medium) over its technique limit (13, `ink3`), the best time on the right (13, `ink3`), and a chevron.

  | Level | Hardest technique needed |
  |---|---|
  | Easy | Singles only |
  | Medium | Pointing & claiming |
  | Hard | Pairs & triples |
  | Expert | Wings & fish |
  | Master | Chains & beyond |

  Tapping a level always starts a **new** puzzle at that level.
- **Import a puzzle from a photo** row: camera symbol 20, text 15 `ink2`, 44 pt tall.
- **Tab bar:** Play (`square.grid.3x3`), Learn (`book`), Journal (`chart.bar`). Active = `accent` with semibold label; inactive = `ink3`. 1 pt `hair` top border, `bg` fill.

### Game [2.3–2.7]
Vertical stack:
- **Status area (54):** in a night game the status bar is hidden (`hideStatusBarInGames`) and the home indicator auto-hides.
- **Header (48):** back chevron (44); centre column with the level label (11 semibold caps, `ink3`) over the timer (15 medium, tabular, `ink2`); moon (44); `ellipsis` (44). Tapping the centre column pauses.
- **Board:** 366 pt square, 6 pt below the header, centred.
  - Build it as 3×3 boxes on a `lineMajor` background, padding and gap = box line width. Each box is 3×3 cells on a `line` background, gap = minor line width. Cells are filled with `bg`. Radius 6.
- **Hint slot:** 124 pt tall, 12 pt margin top and sides. It always reserves space, so nothing shifts.
  - Empty, unless Notes is on: then it shows *"Notes on — digits go in as pencil marks"* (13, `ink3`, centred).
- *Flexible spacer.*
- **Tools:** a 4-column grid, 18 pt side padding, each tool 54 pt tall with a 23 pt icon over an 11 pt label.
  - Undo `arrow.uturn.backward`, Erase `eraser`, Notes `pencil` (with an ON/OFF badge: 9 pt bold, radius 6; ON uses an `accent` fill in Day, outline in Night), Hint `lightbulb`.
  - When a hint is open, the Hint label reads "Next step".
  - Default colour `ink2`; active `accent`; disabled at 35% opacity.
- **Keypad:** 1×9 grid, 4 pt gap, 8 pt side padding, 6 pt top and 30 pt bottom padding.
  - Each key is 64 pt tall with the digit (30 × uiScale, regular, `ink`) over the remaining count (10.5 medium, `ink3`).
  - A digit with 0 remaining shows at 28% opacity, disabled, with no count.
  - Notes mode: each key shows its digit small (13, bold, `accent`) in its pencil-mark position inside a 30 pt 3×3.
  - Pressed state: `surface2` fill, radius 12 (Day only; at night keep it at most 120 ms).

**Cell states.** Meaning must never depend on hue alone.
| State | Fill | Ring | Digit |
|---|---|---|---|
| Given | — | — | `ink`, given weight |
| Entered | — | — | `accent`, entered weight |
| Selected | `sel` | 2 pt inset `accent` | — |
| Peer (row / col / box of selected) | `peer` | — | — |
| Same digit as selected | `same` | — | — |
| Mistake | — | — | `err`, plus a 2 pt `err` bar under the digit (120% of its width) |
| Notes | — | — | 3×3 at cell × 0.25, `ink2`; a candidate matching the selected digit is bold `accent` |
| Hint spotlight | — | — | everything outside `focus` at `focusDim` |
| Hint evidence | — | 1.5 pt inset `accent` | — |
| Hint target | — | 1.5 pt dashed `accent`, inset 3, radius 4 | ghost digit at 55% |
| Pattern (pair / X-Wing corners) | `same` | — | — |
| Ruled out (lessons) | — | 1 pt dotted `ink3`, inset 4 | — |

- **Mistakes:** "Show mistakes" setting: Right away / When I check / Never.
- **More menu:** popover 230 pt wide, top-right under the header, radius 14, `surface2`, `hair` dividers. Rows (15 pt): **Check puzzle**, **Fill all notes**, **Restart puzzle**, **Hush screen** (with "2-finger tap" in 12 `ink3`).
- **Paused [2.7]:** the board is replaced by a 366 pt `hair`-bordered box showing "Paused" (NY 28) and a **Resume** button. The timer stops.

### Hints [3.1–3.5]
- **Card:** fills the hint slot. `surface` fill (transparent at night) with a 1 pt `hair` border, radius 18, padding 12/14/12/16.
  - Top row: progress pills (5 × 5 pt, the current one 14 pt wide, `accent` up to the current step, `hair` after), a step label (11 caps `ink3`), "· Tier" at level ≥ 2, and a close ×.
  - Body: level 1 at 16 `ink`; levels 2–3 at 14 `ink2`, line-height 1.35. Level 2 shows the technique in NY 21 above.
  - Footer: "Lesson →" (13 `ink2`, left; only at level ≥ 2 when a lesson exists) and a primary 34 pt button (right).

| Step | Board | Card copy (example) | Button |
|---|---|---|---|
| 1 Where to look | spotlight on the unit | *"Look at box 4. Where can 5 go?"* | Which technique? |
| 2 Technique | + pattern fill | **Hidden Single** · *"A digit with only one possible home in a row, column or box."* | Show me why |
| 3 Why | + evidence rings, dashed target, ghost digit | *"Every other empty cell in box 4 already sees a 5. So 5 can only go in row 5, column 2."* | **Place 5 · assisted** |

- **Mistake first:** if any entry is wrong, the hint targets it first. Step 2 label: "Mistake". Copy: *"The 7 in row 3, column 4 can't be right — the puzzle doesn't solve with it."* Button: **Clear it**. Clearing a mistake does not mark the solve assisted.
- **Assisted:** steps 1–3 are free. Placing a digit from a hint sets `assisted = true`. An assisted solve keeps the streak but does **not** set best or typical times.
- **Notation:** with `notation == .grid`, cells read "R5C2", rows "R5", columns "C2" and boxes "B4"; sentences keep their wording. Implement it as a formatter used by the hint engine messages. Mind the article: "an 8".
- **Hint text grammar** (port from `engine.js`): nudge, technique name, one-line definition, why-sentence, and focus/evidence/pattern/elim/target cell lists.

### Endings [3.6–3.8]
- **Solved:** the board fades to 10% over 600 ms (was 30%; the digits fought the summary, QA #45). Centred over it: *Solved.* (NY 44), then *"Easy · 6:24 · 2 hints"* (15 `ink2`).
  - If assisted, a pill reads *"Assisted · counts for your streak, not best times"* (13, `hair` ring).
  - Then *"This grid took Hidden Single ×38, Naked Single ×9."* (13 `ink3`), from replaying the hint engine.
  - Buttons: **Another** (ghost) and **Goodnight** (primary).
- **Hush:** a two-finger tap anywhere in the game, or the More menu, pauses the game and shows pure black. *"Tap anywhere to return"* (13 `ink3`) fades out after about 3.5 s. Any tap returns.
- **Goodnight:** pure black with "Sleep well." (NY 30 `ink3`) fading out. A tap returns to Home.

### Night sheet (moon button, any screen) [4.1, 4.2]
- Bottom sheet: top radius 28, `bg` fill with a 1 pt `hair` top border, grabber 36 × 5. The backdrop is black at 55% at night, warm at 18% in Day. The screen behind repaints live.
- Contents:
  1. "Night" (NY 26) and a close button.
  2. Segmented control: Day · Night · After dark. The segments are 34 pt tall, radius 9, inside a 1 pt `hair` ring; the selected one is `surface2` and semibold.
  3. (Night only) three preset chips: 36 pt tall, radius 18, 1.5 pt ring (`accentDim` when active).
  4. (Night only) **Glow** slider with its % value. Sub-text: *"Below your iPhone's lowest brightness."* up to glow 40, else *"Above 40%, the screen itself gets brighter."* (CODESPEC 12.3: glow above 40 drives the backlight)
  5. (Night only) **Warmth** slider with its Kelvin value (e.g. "1,500 K"). The track is a gradient of real Kelvin colours at 75% of the current luminance. Sub-text: *"Blue light about N% lower than daylight white."*
  6. **Clarity** segmented control: Standard · Large · Bold, with *"Bigger, heavier digits and stronger lines. Readable at lower glow."*
  7. Rows: **Drift** (toggle) and **Find my lowest glow** (Start).
- Sliders: 6 pt track (`hair`), 28 pt `ink` thumb with a 5 pt `bg` halo.

### Display & Night page (Journal → Settings) [4.3, 4.4]
- Back button; title "Display & Night" (NY 30); a card holding the live preview strip (five 52 pt cells: given 5, entered 3, selected 7, mistake 4, notes).
- **APPEARANCE:** a list with checkmarks.
  - **Day** — *"Warm paper. For daylight and lamps."*
  - **Night** — *"Black screen, warm digits, silent."*
  - **After dark** — *"Sunset to sunrise where you are."*
  - **Match iPhone** — *"Follows Light and Dark in iOS Settings."*
- When After dark is chosen, an extra block appears:
  - With location: *"Tonight · Sunset 6:12 PM → sunrise 6:41 AM"* and *"Worked out on this iPhone from your rough location and the date. Nothing leaves the phone."*
  - Without: *"Hours · 9:00 PM → 6:30 AM"* (editable).
  - A switch-source chip.
- **NIGHT SCREEN:** presets, Glow and Warmth, as in the sheet.
- **YOUR EYES:** Clarity; **Lowest readable glow** *"Set at N%. Glow and Drift never go below it."* with **Check again**.
- **QUIET:** Drift; Hide status bar in games; Sounds; Vibration (*"Night always keeps sound and vibration off."*).
- Footnote explaining Hush.

### Learn [5.1–5.6]
- **List:**
  - Title "Learn" and the sub-line *"6 of 17 techniques in your hands"*.
  - **Up next** card: label "UP NEXT · 3 MIN", NY 24 name, and a reason line.
  - Then 5 tiers, each with a label and rows: a status dot (12 pt; mastered = filled `accent`, learning = half-filled, new = `ink3` ring), name (16), one-liner (13 `ink3`), and "112×" seen-count or "Lesson".
  - Techniques by tier:
    - Beginner: Full House, Naked Single, Hidden Single
    - Intermediate: Pointing, Claiming, Naked Pair, Naked Triple, Naked Quad
    - Advanced: X-Wing, Y-Wing, Swordfish
    - Expert: XY-Chain, Unique Rectangle, 3D Medusa
    - Esoteric: Exocet, Sue de Coq, Bowman's Bingo
- **Lesson:**
  - Header label "TIER · LESSON", title (NY 34), intro (15 `ink2`).
  - Board at 342 pt using the cell marks above, plus candidate marks (key = bold `accent`, eliminated = `ink3` with a 1.5 pt `err` strike-through).
  - Step text (17 `ink`, minimum height 92).
  - Footer: back circle, step pills, and **Next**, which becomes **Practise** on the last step (it opens a new puzzle at the level that first needs this technique).
- Four lessons are fully scripted in `Learn.jsx`: Hidden Single (5 steps), Pointing (4), Naked Pair (4), X-Wing (4). The other 13 use the "Step-by-step lesson in progress" template until they're written.
- **Mastery:** a technique is mastered after about 10 unaided uses. For each manual placement, run the hint engine on the board *before* the move. If it would have suggested the same cell and digit, credit that technique.

### Journal [6.1, 6.2]
- Big streak number (NY 56) with "nights in a row" and 7 week-day dots (10 pt).
- **SOLVED** card: a 4-column table (level, Solved, Best, Typical); the footer line reads *"N assisted solves kept your streak but don't set best times."*
- **SETTINGS:** Display & Night row.
- **ASSISTS:**
  - Show mistakes: Right away / When I check / Never.
  - Tidy notes.
  - Cell names in hints: "row 5, column 2" / "R5C2", with an explanation line.
  - Show timer.
- **PRIVACY:** *"Everything stays on this iPhone. No account, no network, no analytics. Silent by design — no sounds or vibration unless you turn them on."*

### Import (BYOS) [6.3–6.5]
- **Source:** close button; "Import a puzzle" (NY 32); *"From a newspaper, a book or a screenshot. The photo is read on this iPhone and never uploaded."*
  - Three option cards: Take a photo / Choose from Photos / Type it in.
  - Tips: *"Fill the frame with the grid · Good light, no glare · Pencil marks are ignored"*.
- **Reading:** the photo with the detected grid outline in `accent` and the area outside dimmed; *"Reading digits…"* (NY 26); *"Grid found · 61 of 81 cells checked"*; a 3 pt progress bar.
- **Check the grid:**
  - Board with low-confidence cells ringed and conflicts underlined.
  - Legend lines: *"3 unsure. Ringed cells were hard to read — tap to confirm or fix."* and *"Two 4s in row 4. Fix one before starting."*
  - A 1×9 keypad (52 pt).
  - **Clear cell** and **Start puzzle**. Start is disabled until there are no conflicts and the puzzle is solvable.

---

## Interactions & state
- **Navigation:** TabView (Play / Learn / Journal) with a NavigationStack per tab. The game is a full-screen push from Play or from Lesson → Practise. The Night sheet is a `.sheet` with custom styling — never a system sheet in Night. Display & Night is pushed from Journal.
- **No system UI at night:** no `UIAlertController`, no `confirmationDialog`. Use custom confirmations styled like the More menu.
- **Glow, implemented in layers:**
  1. While the app is in front, set `UIScreen.main.brightness` toward the glow floor. Restore it on background or terminate.
  2. Below the hardware minimum, rely on the palette's luminance scaling.
  - Remove `SleepDimmingOverlay`.
- **Drift:** during a night game, every 90 s apply glow −1 and warmth +1, up to 20 each, never below `glowFloor`. Reset when leaving the game. It's a session offset; don't write it to settings.
- **After dark:** request `CLLocationManager` reduced accuracy only when the user picks After dark. Compute sunset/sunrise on the device (NOAA algorithm, no network). If location is denied, fall back to fixed hours.
- **Silence:** Night forces `soundsEnabled = false` and `hapticsEnabled = false` at runtime.
- **Hint state:** `hint: (hint: Hint, level: 1…3)?`. Hint taps advance a level; step 3's button places the digit. The game state gets `hints: Int` and `assisted: Bool`. Stats: when `assisted`, `recordCompletion` updates the streak and counts but not the best or typical times. This replaces the current "usedReveal → no stats" rule; keep Reveal Puzzle as fully excluded.
- **Persistence:** add the new `Settings` fields with `decodeIfPresent` defaults, and migrate the old keys (see `swift_reference/SettingsV2.swift`). Add `GameState.hints` and `GameState.assisted`. Add per-technique mastery counts to `Stats`.

## Assets
- **App icon "The hint" (final):** `assets/app-icon/AppIcon-{dark,light,tinted}-1024.png` and `.svg`. They are square and unmasked, so iOS applies the corner shape. Digits are outlined paths (Newsreader Medium, SIL OFL), so there is no live text. Put them in `AppIcon.appiconset` as Any / Dark / Tinted. Also replace `LandingIcon`, or drop it: Home no longer shows the icon.
- **SF Symbols:**

  | Use | Symbol |
  |---|---|
  | Back | `chevron.left` |
  | More | `ellipsis` |
  | Night | `moon` |
  | Undo | `arrow.uturn.backward` |
  | Erase | `eraser` |
  | Notes | `pencil` |
  | Hint | `lightbulb` |
  | Play tab | `square.grid.3x3` |
  | Learn tab | `book` |
  | Journal tab | `chart.bar` |
  | Import | `camera` |
  | Disclosure | `chevron.right` |
  | Close | `xmark` |
  | Check | `checkmark` |

  Weight `.regular`, about 22–23 pt in tools and headers.
- The import photo is a placeholder in the mocks; use the real captured image.

## Files in this bundle
| Path | What |
|---|---|
| `DESIGN_NOTES.md` | Principles, night model, decisions, open questions |
| `CLAUDE_CODE_PROMPT.md` | Paste-ready implementation brief, in phases |
| `swift_reference/NightPalette.swift` | Exact palette maths, Clarity scale, presets |
| `swift_reference/SettingsV2.swift` | New settings model and old → new mapping |
| `styles.css` | Tokens (Day + 3 night presets) |
| `ui_kits/puresudoku-2/` | Prototype: `index.html`, `All Screens.html`, `App Flow.html`, `night.js`, `engine.js`, screen JSX |
| `components/` | Board, Keypad, HintCard reference components + cards |
| `preview/` | Token and pattern cards |
| `assets/app-icon/` | Final icon files, review pages, generator |
| `current_app_screenshots/` | Before |
