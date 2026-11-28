# Brand book

Sudoku Masters is an offline iPhone Sudoku app for learning solving techniques and for playing in bed without lighting the room. The look is floating glass controls over a plain board, in three themes. Token values are in `tokens.json`. Palette rules are in CODESPEC 7.2.

## Themes

- Light is for daytime. Grey `bg`, white `surface`, black `ink`, teal `accent`.
- Dark follows the iPhone's dark appearance. True-black `bg`, a slightly raised `surface` for the board and cards, off-white `ink`, a lighter teal `accent`.
- Night is for dark-adapted eyes. Everything is black. Only digits, hairlines and small marks give off light, in dim warm amber. The player chooses it. It is not a darker Dark.

In the app, Night colors are computed from Glow, Warmth and Clarity (CODESPEC 7.2). The Night values in `tokens.json` are the reference palette.

To show a theme inside an element, put `data-theme="dark"` or `data-theme="night"` on it.

## Night rules

- Never put a lit fill behind text. `surface`, `glass`, `fill` and `btn-bg` are all black or clear at night.
- Draw every card and control with its 1 px outline instead: `edge` for surfaces, `glass-edge` for glass, `fill-edge` for the secondary button and `btn-edge` for the primary button.
- Drop the backdrop blur and `glass-shadow`.
- Night has one hue, so nothing may depend on color. Given and entered digits differ by weight (800 and 500). A mistake has a bar under it. The hint target has a dashed ring and its proof cells a solid ring.

## Color

- `ink` is for givens, titles and body. `ink2` is for secondary lines, notes and counts. Both read on `bg` and `surface`.
- `accent` means "yours or active": entered digits, hint rings, the selected tab and tool. Tint only the one primary action on a screen with `btn-bg`. Leave other glass controls untinted.
- `focus` tints the single unit a hint is about. Do not use it to select large areas.
- `err` always comes with its underline bar.

## Glass

- Glass is for controls that float above content: the tab bar, the tool bar, the keypad and round navigation buttons.
- Glass uses the `glass` fill, a 22 px backdrop blur at 180% saturation, a 1 px `glass-edge` and `glass-shadow`.
- The board, cards and lists are content. They use `surface`, never glass.
- Never stack glass on glass.

## Type

- `display` (Bricolage Grotesque, weight 800) is for titles, level and technique names, list row titles and every digit. Entered digits are the one place it runs at 500.
- `text` (DM Sans) is for everything else.
- Digits use tabular numerals.
- Both families are bundled in the app (`PureSudoku/Resources/Fonts`) and in `fonts/`.

## Layout

- Design at 390 × 844. The top safe area is 54 pt. Bottom controls sit 28 pt above the bottom edge.
- The board is `board-w` wide: 6 pt from each screen edge, so a cell is 42 pt. To make room for other things, shrink the hint card, not the board. The one exception is a screen too short to show the keypad: the game then shrinks the board (CODESPEC 3.2).
- Game screen, top to bottom: navigation row (44 pt), board, hint card, tool bar, keypad. The tool bar and keypad are pinned to the bottom.
- Notes sit in a 3×3 mini grid inside the cell. Each digit keeps its fixed place: 1 top-left, 5 centre, 9 bottom-right.
- Hit targets are at least `hit-min`.

## Voice

Calm, plain and precise. Sentence case. One idea per line. No exclamation marks, no emoji, no streak pressure. Write positions as "row 5, column 2". A hint is a short lesson: where to look, which technique, why, then "Place 5 · assisted".

## Icons

The app uses SF Symbols. In mock-ups, use matching line icons: a 24 px box, 1.8 stroke, round caps, and 2.2 stroke for the selected one. The app icon is in AppIcon.md.

## Naming

The app is called "Sudoku Masters". Write it as two words, both capitalised. It is the large title on Home. Do not put the name inside components.
