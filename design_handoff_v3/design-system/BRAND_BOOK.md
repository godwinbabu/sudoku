An offline iPhone Sudoku app for learning real solving techniques and for playing in bed without lighting the room. This is the v3 look: floating glass controls over a plain board, in three themes.

## The three themes

- **Light** is for daytime. Grey `bg`, white `surface`, black `ink`, teal `accent`.
- **Dark** follows the iPhone's dark appearance. True-black `bg`, a slightly raised `surface` for the board and cards, off-white `ink`, a lighter teal `accent`.
- **Night** is for dark-adapted eyes. Everything is black; only digits, hairlines and small marks give off light, in dim warm amber. It is a separate mode the player chooses, not a darker Dark.

Put `data-theme="dark"` or `data-theme="night"` on an element to show that theme inside it.

## Night rules

- Never put a lit fill behind text. `surface`, `glass`, `fill` and `btn-bg` are all black or clear at night.
- Draw every card and control with its 1px outline instead: `edge` for surfaces, `glass-edge` for glass, `fill-edge` for the secondary button, `btn-edge` for the primary button.
- Drop the backdrop blur and `glass-shadow`.
- Night has one hue, so nothing may depend on colour. Given and entered digits differ by weight (800 and 500). A mistake has a bar under it. The hint target has a dashed ring and its proof cells a solid ring.

## Colour

- Text: `ink` for givens, titles and body; `ink2` for secondary lines, notes and counts. Both read on `bg` and `surface`.
- `accent` means "yours or active": entered digits, hint rings, the selected tab and tool. Tint only the one primary action on a screen with `btn-bg`; leave other glass controls untinted.
- Board lines: `line` between cells, `line-major` (2px) between boxes.
- `focus` tints the single unit a hint is about. Do not use it for selection of large areas.
- `err` always comes with its underline bar.

## Glass

- Glass is for controls that float above content: the tab bar, the tool bar, the keypad and round navigation buttons. Fill `glass`, 22px backdrop blur with 180% saturation, 1px `glass-edge`, `glass-shadow`.
- The board, cards and lists are content. They use `surface`, never glass.
- Never stack glass on glass.

## Type

- `display` (Bricolage Grotesque, weight 800) for titles, level and technique names, list row titles and every digit. Entered digits are the one place it runs at 500.
- `text` (DM Sans) for everything else.
- Digits use tabular numerals.
- Both families are loaded from Google Fonts; there are no font files here.

## Layout

- Design at 390 × 844. Top safe area 54pt; bottom controls sit 28pt above the bottom edge.
- The board is `board-w` wide: 6pt from each screen edge, so a cell is 42pt. Do not shrink the board to make room for other things; shrink the hint card.
- Game screen, top to bottom: navigation row (44pt), board, hint card, tool bar, keypad. The tool bar and keypad are pinned to the bottom.
- Pencil notes sit in a 3×3 mini grid inside the cell. Each digit keeps its fixed place: 1 top-left, 5 centre, 9 bottom-right.
- Hit targets are at least `hit-min`.

## Voice

Calm, plain and precise. Sentence case. One idea per line. No exclamation marks, no emoji, no streak pressure. Write positions as "row 5, column 2". A hint is a short lesson: where to look, which technique, why, then "Place 5 · assisted".

## Icons

SF Symbols in the app. In mock-ups use matching line icons: 24px box, 1.8 stroke, round caps; 2.2 stroke for the selected one.

## App icon

A 3×3 box in solid blocks: four solved cells, two proof cells, two empty cells, and the answer 5 in the centre. Use the files in the `app-icon` asset group as they are; never redraw it. The same artwork is used for the light and dark appearances; `AppIcon-tinted` is the greyscale version iOS tints.

## Naming

The app is called "Sudoku Masters". Write it as two words, both capitalised. It is the large title on Home; do not put the name inside components.
