The two glass bars pinned to the bottom of the game: four tools above a single row of nine digit keys.

## What you provide

For each digit, how many are still to place. Which tool, if any, is active, and whether Notes is on.

## Rules

- Both bars are glass with `r-group` corners, `space-3` from the screen's left and right edges, `space-2` apart, 28pt above the bottom edge.
- Tool bar: `tools-h` tall, four equal columns — Undo, Erase, Notes, Hint. Icon over a `caption` label. The Notes label reads "Notes on" or "Notes off".
- The active tool is `accent` with a 700 label and a 2.2 stroke icon. Nothing else changes; no filled chip behind it.
- Keypad: `key-h` tall, nine equal columns. Each key is the digit in `key` with the remaining count under it in `caption`, `ink2`.
- Keys have no individual backgrounds or borders. A digit with none left fades to `ink2` and its count is removed.

## Don't

- Don't split the keys over two rows.
- Don't tint the bars with `accent`.
