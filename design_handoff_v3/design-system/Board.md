# Board

The 9×9 grid. Cell states, notes, and hint and import marks are in CODESPEC 7.3. The screen layout is in CODESPEC 3.2.

## Rules

- The board is `board-w` wide on `surface`, with `r-board` corners and a 1 px `edge` outline. Cells are square.
- Use `line` (1 px) between cells and `line-major` (2 px) between boxes. Draw no outer frame beyond the `edge` outline.
- Given digits use `digit-given` in `ink`. Entered digits use `digit-entered` in `accent`. Keep the weight difference, because at night the two colors are nearly the same hue.
- Notes use `note` in `ink2`, in a 3×3 mini grid inset 3 px top and bottom and 4 px left and right. A digit never moves from its place.
- During a hint, tint the unit with `focus`. Give each proof cell a solid 2 px `accent` ring and the target a dashed one. Inset both 3 px with `r-ring` corners.
- A mistake is the digit in `err` with a 3 px bar under it.
- Do not fill a selected or highlighted cell with a strong color. Rings and the `focus` tint are the only marks.
- Do not scale the board down to fit other content.
