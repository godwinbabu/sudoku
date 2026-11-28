# Hint card

The card under the board that walks through a hint in three steps. The steps, strings and rules are in CODESPEC 6.3.1.

## Rules

- Use `surface` with a 1 px `edge` outline and `r-card` corners. The card is as wide as the screen padding allows.
- It sits between the board and the tool bar and never covers the board.
- Top row: the technique name in `heading`. At the right, "Hint · 3 of 3" in `label`, `ink2`.
- Body: `body` in `ink`. Two lines is the target and three is the limit. Name positions as "row 5, column 2".
- Steps 1 and 2 show one button, "Next". Step 3 shows "Lesson" (secondary) and "Place 5 · assisted" (primary). The word "assisted" stays: placing from a hint marks the solve.
- Primary button: `btn-bg` fill, `btn-ink` label, 1.5 px `btn-edge` outline, 44 pt tall. Use one per screen.
- Secondary button: `fill` with a 1 px `fill-edge` outline and an `accent` label.
- The card is content, not glass. Add no icon or illustration to it.
