# Hint Strategies and Curriculum (PureSudoku)

This file is the source of truth for **which techniques PureSudoku teaches and in what order**.
CODESPEC.md Section 13 defines how the logical solver, the hint ladder and the Learn screen use it.

Rules:
- The logical solver tries techniques **in the order of this table** and returns the first step it finds
  (the simplest available step). After each step it starts again from the top.
- A hint is a full step: placements **or** eliminations, plus the pattern that justifies them.
  Hints are no longer placement-only.
- **Score** is the step score used for puzzle grading (CODESPEC 2.2). Values follow HoDoKu's
  defaults, an established desktop solver; they are tuning values, not exact science.
- **Gated** techniques assume the puzzle has exactly one solution. They run only when
  `hasUniqueSolution` is true (CODESPEC 2.1).
- **Concept** rows are short lessons, not solver steps.
- **Phase** is the build phase that adds the technique (CODESPEC 13.6). X-Wing, Swordfish and XY-Wing
  come early (phase 2) because the current engine already has them.
- **Today** shows what the current `SudokuHintEngine.swift` does, so the gap is clear.

## Tier 1: Basic

| # | Technique | Score | Phase | What it is | Today |
|---|---|---|---|---|---|
| 1 | Full House | 4 | 2 | A house (row, column or box) has one empty cell left. | Yes |
| 2 | Hidden Single (box) | 14 | 2 | In a box, a digit fits in only one cell. | Yes |
| 3 | Hidden Single (row/column) | 14 | 2 | In a row or column, a digit fits in only one cell. | Yes |
| 4 | Naked Single | 4 | 2 | A cell has only one candidate left. | Yes |
| – | Concept: candidates | – | 2 | Pencil marks: the digits a cell can still hold. | – |

## Tier 2: Intermediate

| # | Technique | Score | Phase | What it is | Today |
|---|---|---|---|---|---|
| 5 | Pointing | 50 | 2 | In a box, a digit's candidates lie on one row/column; remove it from the rest of that line. | Yes |
| 6 | Claiming | 50 | 2 | In a row/column, a digit's candidates lie in one box; remove it from the rest of the box. | Yes |
| 7 | Locked Pair / Triple | 40 / 60 | 2 | A naked pair/triple that is also inside one box and one line; eliminates from both. Listed before Naked Pair so it is found first. | No |
| 8 | Naked Pair | 60 | 2 | Two cells in a house hold the same two candidates; remove those digits from the house's other cells. | Yes |
| 9 | Hidden Pair | 70 | 2 | Two digits fit only in the same two cells of a house; remove other candidates from those cells. | No |
| 10 | Naked Triple | 80 | 2 | Three cells in a house hold only three digits between them. | Yes |
| 11 | Hidden Triple | 100 | 2 | Three digits fit only in the same three cells of a house. | No |
| 12 | Naked / Hidden Quad | 120 / 150 | 2 | The same idea with four cells. Rare; brief lesson. | Naked only |

## Tier 3: Advanced

| # | Technique | Score | Phase | What it is | Today |
|---|---|---|---|---|---|
| – | Concept: strong link | – | 5 | A digit has exactly two places in a house: if one is false, the other is true. | – |
| 13 | X-Wing | 140 | 2 | A digit has two places in each of two rows, in the same two columns (or the reverse); remove it from the rest of those columns. | Yes |
| 14 | Skyscraper | 130 | 5 | Two strong links on one digit share one end line; cells that see both free ends lose the digit. | No |
| 15 | 2-String Kite | 150 | 5 | A row link and a column link on one digit joined through a box; the cell that sees both free ends loses the digit. | No |
| 16 | Empty Rectangle | 120 | 5 | A box's candidates for a digit form an L/cross shape that, with a strong link, removes the digit from one cell. | No |
| 17 | Swordfish | 150 | 2 | The X-Wing idea on three rows and three columns. (Jellyfish, four lines, is a note only.) | Yes |
| – | Concept: bivalue cell | – | 5 | A cell with exactly two candidates. | – |
| 18 | XY-Wing | 160 | 2 | A pivot cell (XY) sees two pincers (XZ, YZ); cells that see both pincers lose Z. | Yes (as "Y-Wing") |
| 19 | XYZ-Wing | 180 | 5 | Like XY-Wing, but the pivot also holds Z; cells that see all three lose Z. | No |
| 20 | W-Wing | 150 | 5 | Two identical bivalue cells joined by a strong link on one of their digits; cells that see both lose the other digit. | No |
| 21 | Simple Coloring | 150 | 5 | Color one digit's strong-link chain in two colors; a contradiction or a cell seeing both colors gives eliminations. | No |
| 22 | Unique Rectangle Type 1 | 100 | 5 | Gated. Four cells in two boxes would allow two solutions; removes the pair from the one cell that breaks it. | No |
| 23 | Unique Rectangle Types 2 and 4 | 100 | 5 | Gated. Further rectangle forms. | No |
| 24 | BUG+1 | 100 | 5 | Gated. Every cell is bivalue except one; that cell must take the digit that appears three times in its houses. | No |

## Tier 4: Expert

| # | Technique | Score | Phase | What it is | Today |
|---|---|---|---|---|---|
| 25 | Finned / Sashimi X-Wing | 130 / 150 | 6 | An X-Wing with extra candidates (a fin) in one box; eliminates only where the fin is also seen. | No |
| 26 | X-Chain | 260 | 6 | An alternating chain of strong and weak links on one digit; cells that see both ends lose it. Generalizes Skyscraper, Kite and coloring. | No |
| 27 | XY-Chain | 260 | 6 | A chain of bivalue cells; cells that see **both ends** lose the shared digit. | Partial (bug: needs the ends to see each other) |
| 28 | AIC / Nice Loop | 280 | 6 | Alternating inference chain mixing digits and cells. Generalizes X-Chain and XY-Chain. | No |
| 29 | Grouped AIC | 300 | 6 | An AIC whose links may use groups of cells in one box line. | No |
| 30 | Multi-Coloring | 200 | 6 | Simple coloring across two linked clusters. (3D Medusa is the many-digit version; teach one, not both.) | No |
| 31 | Finned Swordfish | 200 | 6 | A Swordfish with a fin. | No |
| – | Concept: almost locked set (ALS) | – | 6 | N cells in a house that hold N+1 candidates. | – |
| 32 | ALS-XZ | 300 | 6 | Two ALSs linked by a restricted common digit X; cells that see every Z in both lose Z. | No |
| 33 | ALS-XY-Wing | 320 | 6 | Three ALSs in a wing shape. | No |
| 34 | Sue de Coq | 250 | 6 | A box/line intersection and two ALSs that together lock their digits. | No |
| 35 | Death Blossom (optional) | 360 | 6 | A stem cell whose candidates each link to an ALS petal. | No |
| 36 | Forcing Chains | 500 | 6 | Last logical step: every candidate of a cell (or every place of a digit in a house) leads to the same result. | No |

## Out of scope

Not taught and not used by the solver: Exocet, Franken / Mutant / Kraken fish, templates, Nishio,
Bowman's Bingo (trial and error), brute force.
If no technique in this table applies, the hint says so and offers Reveal Cell (CODESPEC 6.3).

## Changes from the previous version

- Hints are full steps (placements or eliminations), not placement-only.
- Added: Hidden Pair/Triple/Quad, Locked Pair/Triple, Skyscraper, 2-String Kite, Empty Rectangle,
  XYZ-Wing, W-Wing, simple and multi-coloring, finned fish, X-Chain, AIC, ALS techniques, Forcing Chains.
- Removed: Exocet, Bowman's Bingo. 3D Medusa is folded into multi-coloring.
- Unique Rectangles and BUG+1 are gated on a unique solution, because imported puzzles may have more than one.
