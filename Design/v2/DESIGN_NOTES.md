# PureSudoku 2 — Design Notes

Working document for the redesign. Prototype: `ui_kits/puresudoku-2/index.html`. Every screen: `ui_kits/puresudoku-2/All Screens.html`. Flow board: `ui_kits/puresudoku-2/App Flow.html`. Tokens: `styles.css`. Night model: `ui_kits/puresudoku-2/night.js`.

Built from `godwinbabu/sudoku@main` (Nov 2026: hint engine, BYOS import, 3-step bedtime brightness, audit fixes) and the audit screenshots in `docs/audit/screenshots/`.

---

## 1. The person we design for

It's 11:40 pm. He's on his side, phone in one hand, inches from his face. His wife is asleep a foot away and doesn't love this habit. If the screen flashes white, if anything buzzes, or if the room glows, he'll hear about it. He's 58, his near vision isn't what it was, and his eyes have been adjusting to the dark for twenty minutes. He wants a hard puzzle and maybe to get better at them. When he's done he wants to put the phone down without fuss.

The same app has to work for a 30-year-old on the train at noon.

## 2. Principles (each one can be checked)

1. **Light is the budget.** At night the canvas is true `#000`, so OLED pixels are off. Only digits, hairlines and small marks give off light. **No lit fills behind text at night:** primary buttons become outlines, cards are hairlines, and the keypad has no key backgrounds. The brightest thing on screen is a digit.
2. **Continuous, not toggles.** Eyes differ and nights differ. Night has three controls: **Glow** (how much light), **Warmth** (colour temperature) and **Clarity** (size and weight). Three presets give a one-tap start. **Find my lowest glow** sets a personal floor.
3. **Never use hue alone to carry meaning.** At 1200 K everything is one hue, and older lenses yellow and lose blue–yellow contrast. So state uses luminance, weight and shape:
   - givens are brighter and heavier; entered digits are the accent colour, lighter and thinner
   - a mistake gets an underline bar, not just red
   - candidates matching the selected digit turn bold
   - the hint target has a dashed ring; the cells that prove it have a solid ring
4. **Teach, don't tell.** A hint is a short lesson: *Where to look → Which technique → Why → Place.* Each step links to the matching lesson. The player can stop at any step.
5. **Silent and still.** No sound and no haptics by default (as now). Motion is limited to fades of 600 ms or less. Solving gets no confetti or bounce — just the word *Solved.*
6. **Partner-safe exits.** A two-finger tap anywhere turns the screen black (**Hush**). **Goodnight** ends a session on black. In a night game the status bar is hidden and the home indicator is dimmed.
7. **Thumb zone.** The board sits on top and stays passive. Every control is in the bottom 45%: a hint slot, four tools, and a single row of 9 keys. Hit targets are 44 pt or larger.

## 3. Night model (spec)

```
warmth w ∈ [0,100] → mired m = 153.8 + (833.3 − 153.8)·w/100 → K = 1e6/m   (6500 K … 1200 K, perceptually even)
base = blackbody RGB(K)         (Tanner Helland approximation; blue = 0 below ~1900 K)
glow g ∈ [0,100]  → s = floor + (1 − floor)·(g/100)^1.15      floor = 0.20 / 0.30 / 0.38 by Clarity
accent = blackbody RGB(K at warmth 0.55w + 52)   — always warmer than ink
```

| Role | Level × s | Use |
|---|---|---|
| ink | 1.00 | givens, titles |
| accent | 0.96 | entered digits, active state |
| ink2 | 0.70 | body, candidates |
| ink3 | 0.50 | labels, counts |
| lineMajor | 0.42 (× clarity lift) | box borders |
| line / hair | 0.17 / 0.15 | cell lines, card outlines |
| sel / same / peer | 0.20 / 0.12 / 0.055 | selection fills (small areas only) |

Clarity: digit size ×1 / 1.1 / 1.2, given weight 600 / 700 / 760, entered weight 400 / 500 / 600, line weight ×1 / 1.5 / 2. Clarity also raises the glow floor, so text stays readable.

**SwiftUI implementation notes**
- Glow uses two layers. (1) While the app is in front, set `UIScreen.main.brightness` toward the user's floor, and restore it on background or exit. (2) Below the hardware minimum, scale ink luminance in the palette. Don't use a black overlay: on OLED, scaling the palette gives the same result with no extra blending, and on LCD (SE / 11) an overlay doesn't dim the backlight anyway.
- Compute the palette as `Color` values (an extension of `ThemeColors`). Don't apply `colorMultiply` filters to the whole view tree.
- In a night game: `prefersStatusBarHidden = true` and `prefersHomeIndicatorAutoHidden = true`.
- The launch screen is always black. Day mode fades up from black over 300 ms, so opening the app at night never flashes.
- No `UIAlertController` or system sheets (in light mode they flash white). Use our own sheets and confirmations.
- The keyboard never appears.
- Night Shift and Reduce White Point stack with our warmth. We can't detect them, so Calibrate covers it.
- Drift: over 30 minutes, glow eases down by up to 20 points (never below the floor) and warmth eases up by up to 20. The change is too slow to notice. The prototype runs it about 5× faster.

**Settings model change:** `AppTheme {system, light, dark, sleep}` + `bedtimeMode` + `SleepBrightness` → `appearance {day, night, afterSunset}` + `glow` + `warmth` + `clarity` + `glowFloor` + `drift`. Night replaces Bedtime Mode: being in Night always means silent, dim and warm.

## 4. Difficulty

Rate a puzzle by the **hardest technique it needs**, not by how many givens it has. The Home screen shows that limit, so the player knows what's coming:

| Level | Hardest technique needed | Engine status |
|---|---|---|
| Easy | Singles | exists |
| Medium | Pointing / Claiming | exists |
| Hard | Naked pairs and triples | exists |
| Expert | X-Wing, Y-Wing, Swordfish | needs generator buckets |
| Master | XY-Chain and beyond | needs generator buckets |

The Solved screen lists the techniques the grid needed (from `techniquesNeeded`, which replays the hint engine).

## 5. Hints

- **Mistake first:** if any entry is wrong, the hint points at it first (matches audit fix #8).
- Steps: (1) **Where** — spotlights one unit and dims the rest of the board; (2) **Which** — technique name, tier and a one-line definition; (3) **Why** — rings the cells that prove it, dashes the target and shows a ghost digit; (4) **Place**.
- **Proposal:** steps 1–3 are free. Only Place marks the puzzle as *assisted*. Today, using Reveal stops a puzzle counting in stats.
- Copy pattern: *"Look at box 4. Where can 5 go?"* → *"Hidden Single"* → *"Every other empty cell in box 4 already sees a 5. So 5 can only go in row 5, column 2."* Positions are written as "row 5, column 2", not "r5c2" (an R1C1 notation option is an open question).

## 6. Learn

- 17 techniques in 5 tiers, matching `HINT_STRATEGIES.md`: **Beginner** (Full House, Naked Single, Hidden Single), **Intermediate** (Pointing, Claiming, Naked Pair/Triple/Quad), **Advanced** (X-Wing, Y-Wing, Swordfish), **Expert** (XY-Chain, Unique Rectangle, 3D Medusa), **Esoteric** (Exocet, Sue de Coq, Bowman's Bingo).
- Lesson template: intro line → 3–5 steps on one diagram (spotlight, ring, dashed target, struck-through candidates) → **Practise** opens a real puzzle at the level that needs the technique. The prototype has four full lessons: Hidden Single, Pointing, Naked Pair and X-Wing.
- **Mastery without quizzes:** each time the player places a digit, the engine works out which technique that move needed at that moment. A technique is *mastered* after about 10 unaided uses. **Up next** suggests the lowest-tier technique the player hasn't mastered yet, preferring ones needed at the level they play.

## 7. Screen notes

- **Play (Home):** a serif wordmark; a quiet line with the date and streak (streaks are mentioned, never pushed); a **Continue** card with a mini board; five levels, each with its technique limit and best time; and a small **Import a puzzle from a photo** row. Imports keep the existing BYOS flow, which isn't restyled yet.
- **Game:** back, level and timer (tap to pause), Night, More. The board is 366 pt wide. Next comes a 124 pt hint slot, so nothing shifts when a hint opens. Tools: Undo, Erase, Notes (shows ON/OFF), Hint. Keys are 1×9 and show how many of each digit are left; finished digits fade out. In Notes mode each key shows its digit in its pencil-mark position. More menu: Check puzzle, Fill all notes, Restart, Hush.
- **Night sheet:** Day / Night / After sunset; three presets; Glow (with a "below your iPhone's lowest brightness" note); Warmth (the slider track is drawn in real Kelvin colours, with a K value and blue-light estimate); Clarity; Drift; Calibrate.
- **Journal:** big serif streak number and a week of dots, a solved/best/typical table, Assists (Show mistakes: Right away / When I check / Never; Tidy notes; Show timer), and a privacy statement.
- **Solved:** the board fades to 30%, then *Solved.*, the time, the techniques used, and two buttons: **Another** / **Goodnight**.

## 8. Mapping to the current app

| Now | Redesign |
|---|---|
| Theme picker + Bedtime toggle + 3-step brightness | Night sheet (continuous controls, presets, calibrate) |
| Bright amber "Enable Bedtime Mode" bar on the main menu | Removed. The moon icon on every screen opens Night |
| Normal / Candidate chips | Notes tool with ON/OFF badge |
| 5×2 number pad with filled keys | 1×9 row with counts, no fills |
| Show Candidates / Hint / Check Cell / Check Puzzle grid | Hint (graduated) as a tool. Check and Fill notes move to More |
| Stats sheet | Journal tab |
| No guide | Learn tab, lessons, and hint → lesson links |
| `Easy / Medium / Hard` | Five levels, each labelled with its technique limit |

## 9. Decisions and open questions

**Decided (1 Nov 2026)**
- **Expert and Master ship in v2.** The generator needs rating buckets for X-Wing/Y-Wing/Swordfish and for chains.
- **Placing a digit from a hint makes the solve *assisted*.** The streak continues, but no best time is set and the solve doesn't count toward typical time. Hint steps 1–3 are free. The Place button says "· assisted" so it's clear up front.
- **The first night launch asks him to run Find my lowest glow** (flow 1b–1d). "Skip for now" falls back to Lights out. The pick becomes `glowFloor`, and glow starts at floor + 4.

**Display & Night settings (flow row 2)**
- One settings model, two ways in. The **moon sheet** is quick and reachable from any screen, including mid-game. **Journal → Display & Night** is the full page.
- Appearance has four options: **Day** · **Night** · **After dark** · **Match iPhone** (follows the iOS Light/Dark setting). The sheet shows the first three.
- **After dark hours (decided):** sunset to sunrise at local time, worked out on the device from rough location (`CLLocationManager` reduced accuracy, requested only when After dark is chosen) plus the date. No network is needed. If location is denied or unavailable, use fixed hours (9:00 PM → 6:30 AM, user-editable). The settings page shows which is in use and lets him switch.
- The full page adds: a live preview strip, Clarity, Lowest readable glow (Check again), Drift, Hide status bar in games, and Sounds/Vibration (off; Night forces them off).

**Still open**
1. Should Expert and Master ship with v2, or stay hidden until the generator can rate puzzles that hard?
2. Does Place make a puzzle *assisted* (no best time, but the streak continues)? Or do all hints count?
3. Default glow and warmth on first launch at night: **Lights out** (18 / 75) or ask with Calibrate on first launch?
4. ~~After dark hours~~ — decided: local sunset/sunrise, with fixed hours as the fallback.
5. ~~"Last puzzle" reminder~~ — decided: no.
6. ~~R1C1 notation~~ — decided: yes. Journal → Assists → Cell names in hints: "row 5, column 2" or "R5C2" (R row, C column, B box).
5. ~~"Last puzzle" reminder~~ — decided: no.
7. ~~Day accent~~ — decided: keep burnt amber `#9A5712`. The original amber `#F5B754` gives about 1.7:1 contrast on paper, which is too low for entered digits. The brown reads as the same family as the night ink and passes 4.5:1.
8. ~~App icon~~ — decided: **The hint** (option 2c in `assets/app-icon/Icon Options.html`). A 3×3 box: two proof cells in solid amber rings, the answer 5 glowing in a dashed ring, and four solved cells in dim ink. It uses the same marks the hints teach with. The dashed ring is built from explicit segments: four identical curved corner dashes and four straight dashes of the same length. Refined hierarchy (chosen from `2c Review.html`, option B): the answer leads with heavier dashes and a wider glow; proof rings are thinner and dimmer; solved digits and lines step back. Variants: Dark, Light and Tinted (iOS 18). Digits are outlined to paths (Newsreader Medium, SIL OFL), so the icon has no live text. Shipping files: `assets/app-icon/AppIcon-{dark,light,tinted}.svg` and `-1024.png`. They are square and unmasked, because iOS applies the corner shape.

## 10. Prototype limits

- Puzzles are fixed (Easy, Medium and Hard from the app's own screenshot). Expert and Master reuse Hard.
- The JS hint engine covers singles, pointing/claiming and naked pairs. Anything harder falls back to "Advanced".
- Stats, mastery and streak are sample data.
- Use a Mac browser for real SF Pro / New York fonts. Elsewhere it falls back to Newsreader and the system sans.
- Shortcuts: two-finger tap or the **H** key = Hush.
