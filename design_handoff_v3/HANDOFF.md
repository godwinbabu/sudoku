# Sudoku Masters — v3 design handoff

Target: the existing SwiftUI iPhone app (repo `godwinbabu/sudoku`, app currently named PureSudoku). An Android app may follow later and will reuse `tokens.json`; nothing here needs to be cross-platform.

Written 21 Nov 2026. The author of this spec could not read the repository, so every statement about existing code comes from an earlier file map and must be checked against the code.

---

## 1. What v3 is

- **Look:** floating glass controls over a plain board. Native iOS, one accent colour, no decoration.
- **Three themes:** Light, Dark and Night. Night is not a darker Dark; it is a separate mode for dark-adapted eyes.
- **Type:** Bricolage Grotesque (display and every digit) and DM Sans (everything else).
- **Name:** Sudoku Masters.
- **Icon:** new, in `icon/`.

What does not change: the puzzle engine, the hint engine's logic, saved games, stats storage, the offline-only promise, and silence by default (no sound, no haptics).

## 2. Themes

All values are in `tokens.json` (`color.tokens`, one value per theme) and mirrored in `reference/V3Palette.swift`.

| Role | Light | Dark | Night | Use |
|---|---|---|---|---|
| `bg` | #F2F2F7 | #000000 | #000000 | Screen background |
| `surface` | #FFFFFF | #151517 | #000000 | Board, cards, list groups |
| `edge` | = surface | = surface | #3A2410 | 1pt outline of every surface |
| `ink` | #000000 | #F2F2F7 | #D08A3C | Givens, titles, body |
| `ink2` | #63636A | #A1A1AA | #A56A2E | Secondary text, notes, counts |
| `accent` | #007580 | #5AD4E6 | #D9602B | Entered digits, rings, active tab/tool |
| `btn-bg` / `btn-ink` / `btn-edge` | #007580 / #FFFFFF / none | #5AD4E6 / #00262B / none | clear / #D9602B / #8A3F1C | Primary button |
| `fill` / `fill-edge` | grey 14% / none | grey 30% / none | clear / #3A2410 | Secondary button, segmented track |
| `line` | #D4D4DA | #2C2C2E | #24160A | Cell lines, separators, slider track |
| `line-major` | #3A3A3C | #7C7C82 | #80522A | 2pt lines between boxes |
| `focus` | teal 10% | teal 13% | #140A02 | Tint of the unit a hint is about |
| `err` | #C4281C | #FF6B5E | #E0483A | Wrong digit and its bar |
| `glass` / `glass-edge` | white 62% / white 90% | grey 50% / white 16% | clear / #3A2410 | Floating controls |

### Night rules (check each one)

1. No lit fill behind text. `surface`, `glass`, `fill` and `btn-bg` are black or clear.
2. Every card and control is drawn by its 1pt outline only.
3. No blur, no material, no shadow.
4. Night has a single hue, so nothing may rely on colour:
   - given digits weight 800, entered digits weight 500
   - a mistake has a bar under it
   - the hint target has a dashed ring, proof cells a solid ring
5. The status bar is hidden in a night game and the home indicator is auto-hidden.
6. Never present a system alert or system sheet at night (they flash). Use the app's own sheets.
7. The launch screen is black in every theme.

### Night is continuous

The Night colours in the table are one snapshot (the default preset). The real palette is computed from three user controls, exactly as the v2 notes specified:

```
warmth w ∈ [0,100] → mired m = 153.8 + (833.3 − 153.8)·w/100 → K = 1e6/m      (6500 K … 1200 K)
base  = blackbody RGB(K)                                (Tanner Helland approximation)
glow g ∈ [0,100]  → s = floor + (1 − floor)·(g/100)^1.15       floor = 0.20 / 0.30 / 0.38 by Clarity
accent = blackbody RGB(K at warmth 0.55w + 52)                  (always warmer than ink)
```

| Role | Level × s |
|---|---|
| `ink` | 1.00 |
| `accent` | 0.96 |
| `ink2` | 0.70 |
| `line-major` | 0.42 |
| `edge`, `glass-edge`, `fill-edge` | 0.22 |
| `line` | 0.17 |
| `focus` | 0.08 |

- **Clarity** (Standard / Large / Bold): digit size ×1 / 1.1 / 1.2; given weight 800 in all three; entered weight 500 / 600 / 700; line widths ×1 / 1.5 / 2.
- **Glow below the hardware minimum:** first lower `UIScreen.main.brightness` toward the user's floor while the app is frontmost and restore it on background; below that, scale the palette. Do not use a black overlay.
- **Drift:** over 30 minutes glow eases down by up to 20 points (never below the floor) and warmth eases up by up to 20.
- **Presets:** Reading lamp, Lights out (glow 18, warmth 75), Red light. Pick values for the other two so the Reading lamp default lands near the snapshot colours above, and list what you chose.

If the app already has a night or bedtime brightness model, adapt it to this rather than writing a second one.

## 3. Glass

Glass is for controls that float above content: tab bar, game tool bar, keypad, round navigation buttons. The board, cards and lists are content and use `surface`.

- **iOS 26 and later:** use the system's Liquid Glass (`glassEffect`, `GlassEffectContainer`, glass button styles, and the standard `TabView` and toolbar, which adopt it automatically). Check Apple's current documentation for the exact API before using it. Prefer system components over custom drawing.
- **Earlier iOS:** `.ultraThinMaterial` with a 1pt `glass-edge` stroke and a soft shadow (`0 10 30`, black 14% light / 60% dark).
- **Night, any iOS:** no material at all. Clear fill, 1pt `glass-edge` stroke, no shadow. This applies even where the system would supply glass, so the tab bar and toolbars may need a custom background at night.
- Never place glass on glass. Tint only the single primary action on a screen.
- Respect Reduce Transparency: replace glass with `surface` plus the stroke.

Check the deployment target before choosing; say in your plan which path applies.

## 4. Type

| Style | Font | Size / line | Weight | Use |
|---|---|---|---|---|
| `title` | Bricolage Grotesque | 33 / 38 | 800 | Large title on Home, Learn, Journal, Lesson |
| `level` | Bricolage Grotesque | 24 / 28 | 800 | Level name on the Continue card |
| `heading` | Bricolage Grotesque | 21 / 26 | 800 | Technique names, hint title, game nav title |
| `row` | Bricolage Grotesque | 19 / 24 | 800 | First line of a list row |
| `digit-given` | Bricolage Grotesque | 26 | 800 | Given digits |
| `digit-entered` | Bricolage Grotesque | 26 | 500 | Entered digits |
| `key` | Bricolage Grotesque | 28 | 800 | Keypad digits |
| `body` | DM Sans | 15 / 20 | 400 | Hint and lesson copy |
| `button` | DM Sans | 15 | 700 | Button labels |
| `label` | DM Sans | 13 / 16 | 500 | Secondary lines, section labels |
| `caption` | DM Sans | 11 / 13 | 600 | Tab and tool labels, key counts |
| `note` | DM Sans | 10 | 600 | Pencil notes |

- Letter spacing −0.02em on Bricolage at 21pt and above. Tabular numerals on every digit and time.
- Board digit sizes are for a 42pt cell; scale them with the cell (digit ≈ 0.62 × cell, note ≈ 0.24 × cell).
- **Font files:** `fonts/` holds Latin-subset TTFs converted from the Fontsource packages (SIL Open Font License). Their PostScript names are unusual: `BricolageGrotesque96ptExtraBold-Medium`, `BricolageGrotesque96ptExtraBold-ExtraBold`, `DMSans9pt-Regular`, `DMSans9pt-Medium`, `DMSans9pt-SemiBold`, `DMSans9pt-Bold`. Prefer downloading the official variable TTFs from Google Fonts and using those; fall back to these files if you cannot. Register them under `UIAppFonts` and include the OFL licence text in the app's acknowledgements.
- Use `Font.custom(_:size:relativeTo:)` so text scales with Dynamic Type. The board digits and keypad do not scale with Dynamic Type; they scale with Clarity.

## 5. Layout constants

- Design size 390 × 844 pt. Lay out with safe areas, not fixed offsets.
- Screen side padding 16. Board: screen width − 12 (6 from each edge), so 378 wide and 42pt cells at 390. On wider phones the board grows with the screen; never shrink it to fit other content.
- Radii: ring 9, board 12, card 22, group 26, tab bar 31 (pills are half their height).
- Hit targets at least 44 × 44.
- Tab bar: 62 tall, 21 from left, right and bottom. Game tool bar 52 tall and keypad 64 tall, 12 from the sides, 8 apart, 28 above the bottom edge.

## 6. Screens

Reference renders: `screens/<name>-<theme>.png`. Design source: `source/`.

### 6.1 Home (`home-*.png`, replaces the main menu)

Top to bottom: date line (`label`, `ink2`) with a 44pt round glass Night button at the right; large title "Sudoku Masters"; Continue card; "New puzzle" label; one grouped list of five levels; floating tab bar.

- **Continue card:** `surface`, radius 26, padding 16. A 72pt progress ring (7pt stroke, `line` track, `accent` progress = filled cells ÷ 81) with the filled count inside; "Continue", the level name (`level`), "time · N of 81"; a primary pill button "Resume" (44 tall). Hidden when there is no game in progress.
- **Levels:** Easy — Singles; Medium — Pointing and claiming; Hard — Naked pairs and triples; Expert — X-Wing, Y-Wing, Swordfish; Master — XY-Chain and beyond. Row 60 tall, name in `row`, technique limit in `label`/`ink2`, chevron. Show only the levels the generator can actually produce; do not ship Expert or Master rows that fall back to Hard.
- **Tab bar:** Play, Learn, Journal, plus a separate 62pt round glass button for "Import a puzzle from a photo". Selected tab: `accent`, heavier icon and label, on a subtle pill (no pill at night).
- Remove any bedtime banner or theme picker from this screen; the Night button opens the Display sheet.

### 6.2 Game (`game-*.png`)

Top to bottom: navigation row; board; hint card (only while a hint is open); tool bar; keypad. Tool bar and keypad are pinned to the bottom. No tab bar.

- **Navigation row (44 tall):** round glass Back; centre "Level" (`heading`) and the timer (`label`, tap to pause); a glass capsule holding Night and More.
- **Board:** `surface`, radius 12, clipped. 1pt `line` between cells, 2pt `line-major` between boxes, no other frame (a 1pt `edge` outline at night).

| Cell state | Appearance |
|---|---|
| Given | `digit-given`, `ink` |
| Entered | `digit-entered`, `accent` |
| Notes | 3×3 mini grid inset 3pt top/bottom and 4pt left/right; each digit in its fixed place (1 top-left … 9 bottom-right); `note`, `ink2` |
| Selected | 2pt solid `accent` ring inset 3pt, radius 9; peers (same row, column, box) get the `focus` tint |
| Same digit as selected | digit and matching notes switch to weight 800 |
| Mistake (per the Show mistakes setting) | digit in `err` plus a 3pt bar under it |
| Hint: unit | every cell of the unit gets the `focus` tint |
| Hint: proof cell | 2pt solid `accent` ring inset 3pt |
| Hint: target | 2pt dashed `accent` ring inset 3pt; at the Why step the answer is shown in `accent`, weight 800 |

  The mock shows a hint, not a plain selection; selection and same-digit states are specified here only.
- **Hint card:** `surface`, radius 22, padding 12/16/14. Top row: technique name (`heading`) and "Hint · 3 of 3" (`label`, `ink2`). Body in `body`, two lines ideally, three at most. Steps: 1 Where (unit tinted, one "Next" button), 2 Which (technique name and one-line definition, "Next"), 3 Why (rings shown; "Lesson" secondary 104 wide, "Place 5 · assisted" primary). If any entry is wrong, the hint points at the mistake first. The card's slot is reserved so the board never moves when it opens.
- **Tool bar:** Undo, Erase, Notes ("Notes on" / "Notes off"), Hint. Icon over `caption` label. Active tool: `accent`, heavier. No filled chip.
- **Keypad:** one row of nine. Digit in `key`, remaining count under it in `caption`/`ink2`. A finished digit fades to `ink2` and loses its count. In Notes mode the bar gains a 1.5pt `accent` outline.
- **More menu:** Check puzzle, Fill all notes, Restart. Use an app-drawn menu at night.
- Motion: fades only, 200–300 ms; nothing bounces. Respect Reduce Motion.

### 6.3 Display sheet (`display-*.png`, opened by the Night button anywhere)

- Live preview strip: two given and two entered digits in the current settings.
- **Appearance:** segmented Light / Dark / Night. Below it one row, "Night after dark — Switches at sunset, back at sunrise", with a switch.
- **Night** (always visible, applies whenever Night is on): preset segmented control (Reading lamp / Lights out / Red light); Glow slider with a percentage; Warmth slider with the Kelvin value; Clarity segmented (Standard / Large / Bold); Drift switch; a secondary button "Find my lowest glow".
- Controls: segmented track is `fill` with a `fill-edge` outline, selected segment white (light), #636366 (dark) or an `btn-edge` outline (night). Switch on = `btn-bg` with a `btn-ink` knob. Slider = 4pt `line` track, `accent` progress, 26pt thumb with a 2pt `accent` ring on `bg`.
- Changing Appearance re-themes the sheet immediately.

**Settings model.** Replace whatever exists (the earlier notes mention `AppTheme {system, light, dark, sleep}`, `bedtimeMode`, `SleepBrightness`) with: `appearance {light, dark, night}`, `nightAfterDark: Bool`, `glow`, `warmth`, `clarity`, `glowFloor`, `drift: Bool`. Migrate stored values: sleep or bedtime → night; system → the current system style. Night always means silent, dim and warm; there is no separate bedtime toggle.

"After dark" hours: local sunset to sunrise computed on the device from reduced-accuracy location, requested only when the switch is turned on. If location is denied, use fixed hours (9:00 PM to 6:30 AM, editable).

Open question for the owner: there is no "match iPhone" option in this design. Until he chooses otherwise, a fresh install starts in the system's current light or dark style.

### 6.4 Journal (`journal-*.png`, replaces Stats and Settings)

Large title "Journal"; top line "Nothing here leaves this iPhone". A streak card (count in 40pt Bricolage, "days in a row", seven day markers); a "Solved" table (Level, Solved, Best, Typical; en dash where there is no data); an "Assists" group: Show mistakes (Right away / When I check / Never), Tidy notes, Show timer, Cell names in hints ("Row 5, column 2" / "R5C2"). The numbers in the mock are sample data. Day markers are filled circles in light and dark, ring-with-dot at night.

### 6.5 Solved (`solved-*.png`)

The finished board fades to 30% opacity over 600 ms. Then "Solved" (52pt Bricolage 800), "Level · time", "This grid needed" with one outlined chip per technique, and two buttons: "Another" (secondary) and "Goodnight" (primary; ends the session on a black screen). No confetti, sound or haptic. A solve that used "Place" is marked assisted: the streak continues but no best time is set.

### 6.6 Learn and Lesson (`learn-*.png`, `lesson-*.png`) — new feature

- **Learn:** large title; an "Up next" card (tier, technique name, one-sentence definition, primary "Start lesson"); grouped lists per tier. Row: technique name (`row`), status (Mastered with a check, Learning, Up next, New), chevron. Tiers: Beginner (Full House, Naked Single, Hidden Single), Intermediate (Pointing, Claiming, Naked Pair, Naked Triple, Naked Quad), Advanced (X-Wing, Y-Wing, Swordfish), Expert (XY-Chain, Unique Rectangle, 3D Medusa), Esoteric (Exocet, Sue de Coq, Bowman's Bingo).
- **Lesson:** Back; "Tier · lesson N of 17"; technique name; one-line definition; a full-width board diagram where only the cells that matter are at full strength (other digits `ink2`, weight 500); a step card (step title, "Step N of M", two or three lines); "Back" and "Next"; a text button "Practise on a real puzzle".
- Mastery: a technique is mastered after about 10 unaided uses, detected by asking the hint engine which technique each placed digit needed.

This is new functionality, not a restyle. Build it last, and only after confirming with the owner how many lessons to write for the first release.

## 7. Copy

Calm, plain, precise. Sentence case. No exclamation marks, emoji or streak pressure. Positions read "row 5, column 2". Use the exact strings in the mocks.

## 8. Accessibility

- VoiceOver: each cell announces "row R, column C, value / empty / notes 1, 4, 7", plus "given" or "mistake". Rings announce as "hint target" and "proof". Keys announce "N, M left".
- Dynamic Type on all text outside the board and keypad; lists and cards must grow, not truncate.
- Differentiate Without Colour is already met by the rules in section 2; do not regress them.
- Reduce Transparency: glass becomes `surface` plus a stroke. Reduce Motion: no fades longer than 150 ms.
- Contrast: every text token is at least 4.5:1 on `bg` and `surface` in every theme; `line-major` is at least 3:1.

## 9. Mapping to the code (unverified)

| Screen | Files named in the earlier notes |
|---|---|
| Home | `PureSudoku/Views/MainMenuView.swift`, `ViewModels/MainMenuViewModel.swift` |
| Game | `Views/GameView.swift`, `SudokuGridView.swift`, `NumberPadView.swift`, `ViewModels/GameViewModel.swift` |
| Hints | `Engine/SudokuHintEngine.swift`, `HINT_STRATEGIES.md` |
| Display sheet | `Models/Settings.swift`, `AppTheme.swift`, `Theme/ThemeColors.swift`, `Theme/SheetTheme.swift`, `Views/Settings+Theme.swift` |
| Journal | `Views/StatsView.swift`, `SettingsView.swift`, `Models/Stats.swift` |
| Import | `BYOS.md`, `Views/ImportPuzzleView.swift` (not redesigned; apply the theme and button styles only) |
| Learn, Lesson | none yet |

## 10. Phases

Each phase ends with a build, tests, simulator screenshots in all three themes, and a commit.

1. **Foundation.** Three-theme palette in the existing theme layer, fonts, text styles, glass modifier with its night and fallback paths, primary and secondary button styles, segmented, switch and slider styles. Display name "Sudoku Masters". New app icon (`icon/AppIcon-default-1024.png` for Any and Dark, `icon/AppIcon-tinted-1024.png` for Tinted). Black launch screen.
2. **Game.** Board, cell states, notes mini grid, hint card, tool bar, keypad, navigation row.
3. **Home and tab bar.**
4. **Display sheet and the settings model,** including migration and the continuous night palette.
5. **Journal.**
6. **Solved.**
7. **Learn and Lesson** (after confirming scope).

Not designed yet; leave as they are, themed: the first-night "find my lowest glow" flow, photo import, the More menu's contents beyond the three items above.

## 11. Things to check and report

- The display name "Sudoku Masters" may be truncated under the home-screen icon. Report what the simulator shows.
- Which glass path the deployment target allows.
- Any place where the existing behaviour contradicts this spec.
