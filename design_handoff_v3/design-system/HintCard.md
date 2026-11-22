The card under the board that walks through a hint in three steps, and the two button styles it carries.

## What you provide

The step (1 Where, 2 Which, 3 Why), the technique name, one or two sentences of explanation, and the digit to place.

## Rules

- `surface` with a 1px `edge` outline and `r-card` corners, as wide as the screen padding allows. It sits between the board and the tool bar and never covers the board.
- Top row: the technique name in `heading`; at the right "Hint · 3 of 3" in `label`, `ink2`.
- Body in `body`, `ink`. Two lines is the target, three the limit. Name positions as "row 5, column 2".
- Steps 1 and 2 show one button, "Next". Step 3 shows "Lesson" (secondary) and "Place 5 · assisted" (primary). The word "assisted" stays: placing from a hint marks the solve.
- Primary button: `btn-bg` fill, `btn-ink` label, 1.5px `btn-edge` outline, 44pt tall. One per screen.
- Secondary button: `fill` with a 1px `fill-edge` outline and an `accent` label.

## Don't

- Don't make the card glass; it is content.
- Don't add an icon or illustration to it.
