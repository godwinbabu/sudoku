# Hint Strategies and Curriculum

This file lists which techniques the app teaches and in what order. CODESPEC 12 defines how the logical solver, the hint card and the Learn tab use it.

## Rules

- The logical solver tries techniques in the order of the tables below. It returns the first step it finds, which is the simplest one. After each step it starts again from the top.
- A hint is a full step: placements or eliminations, plus the pattern that justifies them.
- Score is the step score for puzzle grading (CODESPEC 2.2). The values follow the defaults of an established desktop solver. They are tuning values, not exact science.
- Gated techniques assume the puzzle has exactly one solution. They run only when `hasUniqueSolution` is true (CODESPEC 2.1).
- Concept rows are short lessons, not solver steps.
- "In app" shows whether the solver (`LogicalSolver`) has the technique.

## Tier 1: Basic

| # | Technique | Score | What it is | In app |
|---|---|---|---|---|
| 1 | Full House | 4 | A row, column or box has one empty cell left. | Yes |
| 2 | Hidden Single (box) | 14 | In a box, a digit fits in only one cell. | Yes |
| 3 | Hidden Single (row/column) | 14 | In a row or column, a digit fits in only one cell. | Yes |
| 4 | Naked Single | 4 | A cell has only one candidate left. | Yes |
| - | Concept: candidates | - | Pencil marks: the digits a cell can still hold. | - |

## Tier 2: Intermediate

| # | Technique | Score | What it is | In app |
|---|---|---|---|---|
| 5 | Pointing | 50 | In a box, a digit's candidates lie on one row or column. Remove it from the rest of that line. | Yes |
| 6 | Claiming | 50 | In a row or column, a digit's candidates lie in one box. Remove it from the rest of the box. | Yes |
| 7 | Locked Pair / Triple | 40 / 60 | A naked pair or triple that is also inside one box and one line. It removes digits from both. It comes before Naked Pair so the solver finds it first. | Yes |
| 8 | Naked Pair | 60 | Two cells in a house hold the same two candidates. Remove those digits from the house's other cells. | Yes |
| 9 | Hidden Pair | 70 | Two digits fit only in the same two cells of a house. Remove the other candidates from those cells. | Yes |
| 10 | Naked Triple | 80 | Three cells in a house hold only three digits between them. | Yes |
| 11 | Hidden Triple | 100 | Three digits fit only in the same three cells of a house. | Yes |
| 12 | Naked / Hidden Quad | 120 / 150 | The same idea with four cells. It is rare, so the lesson is brief. | Yes |

A house is a row, column or box.

## Tier 3: Advanced

| # | Technique | Score | What it is | In app |
|---|---|---|---|---|
| - | Concept: strong link | - | A digit has exactly two places in a house. If one is false, the other is true. | - |
| 13 | X-Wing | 140 | A digit has two places in each of two rows, in the same two columns (or the reverse). Remove it from the rest of those columns. | Yes |
| 14 | Skyscraper | 130 | Two strong links on one digit share one end line. Cells that see both free ends lose the digit. | Yes |
| 15 | 2-String Kite | 150 | A row link and a column link on one digit, joined through a box. The cell that sees both free ends loses the digit. | Yes |
| 16 | Empty Rectangle | 120 | A box's candidates for a digit form an L or cross shape. With a strong link, this removes the digit from one cell. | Yes |
| 17 | Swordfish | 150 | The X-Wing idea on three rows and three columns. Jellyfish (four lines) is a note only. | Yes |
| - | Concept: bivalue cell | - | A cell with exactly two candidates. | - |
| 18 | XY-Wing | 160 | A pivot cell (XY) sees two pincers (XZ and YZ). Cells that see both pincers lose Z. | Yes |
| 19 | XYZ-Wing | 180 | Like XY-Wing, but the pivot also holds Z. Cells that see all three lose Z. | Yes |
| 20 | W-Wing | 150 | Two identical bivalue cells joined by a strong link on one of their digits. Cells that see both lose the other digit. | Yes |
| 21 | Simple Coloring | 150 | Color one digit's chain of strong links in two colors. A contradiction, or a cell that sees both colors, gives eliminations. | Yes |
| 22 | Unique Rectangle Type 1 | 100 | Gated. Four cells in two boxes would allow two solutions. Remove the pair from the one cell that breaks it. | Yes |
| 23 | Unique Rectangle Types 2 and 4 | 100 | Gated. Further rectangle forms. | Yes |
| 24 | BUG+1 | 100 | Gated. Every cell is bivalue except one. That cell must take the digit that appears three times in its houses. | Yes |

## Tier 4: Expert

| # | Technique | Score | What it is | In app |
|---|---|---|---|---|
| 25 | Finned / Sashimi X-Wing | 130 / 150 | An X-Wing with extra candidates (a fin) in one box. It eliminates only where the fin is also seen. | No |
| 26 | X-Chain | 260 | An alternating chain of strong and weak links on one digit. Cells that see both ends lose it. It generalizes Skyscraper, Kite and coloring. | No |
| 27 | XY-Chain | 260 | A chain of bivalue cells. Cells that see both ends lose the shared digit. It runs after every Advanced technique. | Yes |
| 28 | AIC / Nice Loop | 280 | An alternating inference chain that mixes digits and cells. It generalizes X-Chain and XY-Chain. | No |
| 29 | Grouped AIC | 300 | An AIC whose links may use groups of cells in one box line. | No |
| 30 | Multi-Coloring | 200 | Simple coloring across two linked clusters. 3D Medusa is the many-digit version. Teach one, not both. | No |
| 31 | Finned Swordfish | 200 | A Swordfish with a fin. | No |
| - | Concept: almost locked set (ALS) | - | N cells in a house that hold N+1 candidates. | - |
| 32 | ALS-XZ | 300 | Two ALSs linked by a restricted common digit X. Cells that see every Z in both lose Z. | No |
| 33 | ALS-XY-Wing | 320 | Three ALSs in a wing shape. | No |
| 34 | Sue de Coq | 250 | A box and line intersection plus two ALSs that together lock their digits. | No |
| 35 | Death Blossom (optional) | 360 | A stem cell whose candidates each link to an ALS petal. | No |
| 36 | Forcing Chains | 500 | The last logical step. Every candidate of a cell (or every place of a digit in a house) leads to the same result. | No |

## Out of scope

The app does not teach or use these: Exocet, Franken, Mutant and Kraken fish, templates, Nishio, Bowman's Bingo (trial and error) and brute force.

If no technique in the tables applies, the hint says so and places the answer as an assisted step (CODESPEC 6.3.1).
