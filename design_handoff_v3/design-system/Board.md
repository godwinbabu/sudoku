The 9×9 grid and the states a cell can be in.

## What you provide

81 cells, each with at most one of: a given digit, an entered digit, or a set of pencil notes. Optionally one hint: the unit it is about, its proof cells and its target cell.

## Rules

- The board is `board-w` wide on `surface` with `r-board` corners and a 1px `edge` outline. Cells are square.
- `line` (1px) between cells, `line-major` (2px) between boxes. No outer frame beyond the `edge` outline.
- Given digits use `digit-given` in `ink`; entered digits use `digit-entered` in `accent`. The weight difference must stay: at night the two colours are nearly the same hue.
- Notes use `note` in `ink2`, in a 3×3 mini grid inset 3px top and bottom, 4px left and right. A digit never moves from its place.
- During a hint, tint the unit with `focus`, give each proof cell a solid 2px `accent` ring and the target a dashed one, both inset 3px with `r-ring` corners.
- A mistake is the digit in `err` with a 3px bar under it.

## Don't

- Don't fill a selected or highlighted cell with a strong colour; rings and the `focus` tint are the only marks.
- Don't scale the board down to fit other content.
