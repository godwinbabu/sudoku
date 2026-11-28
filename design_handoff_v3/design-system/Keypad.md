# Keypad and tool bar

The two glass bars pinned to the bottom of the game: four tools above a row of nine digit keys. Behaviour, sizes and strings are in CODESPEC 3.2.

## Rules

- Both bars are glass with `r-group` corners, `space-3` from the left and right screen edges, `space-2` apart, and 28 pt above the bottom edge.
- Tool bar: `tools-h` tall, four equal columns: Undo, Erase, Notes, Hint. Each is an icon over a `caption` label. The Notes label reads "Notes on" or "Notes off".
- The active tool is `accent`, with a 700 label and a 2.2 stroke icon. Nothing else changes. Add no filled chip.
- Keypad: `key-h` tall, nine equal columns, in one row. Each key is the digit in `key`. The count of digits left sits under it in `caption`, `ink2`, only in Notes mode. In Notes mode a finished digit shows no count and its key stays on.
- Keys have no individual backgrounds or borders. Outside Notes mode, a digit with none left fades to `ink2` and its key is disabled.
- Do not tint the bars with `accent`.
