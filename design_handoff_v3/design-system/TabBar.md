# Tab bar

The floating glass tab bar on Play, Learn and Journal, with a round button beside it that imports a puzzle from a photo. Behaviour and strings are in CODESPEC 3.1.

## Rules

- A glass capsule `tabbar-h` tall with `r-bar` corners, `space-5` from the left, right and bottom edges. Content scrolls underneath it.
- Three equal tabs, each an icon over a `caption` label.
- The selected tab sits on a `pill`, in `accent`, with a 700 label and a 2.2 stroke icon. At night the pill is clear, so color and weight carry it.
- The round button is its own glass circle of the same height, 10 pt to the right of the capsule.
- The game screen has no tab bar. It uses the same glass for a 44 pt round Back button and a 44 pt capsule that holds Night and More.
- Do not add a fourth tab. Night lives behind the moon button on every screen.
- Do not place the bar on top of another glass control.
