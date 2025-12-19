# Hint Strategy Order (PureSudoku)

This document defines the ordered list of strategies that the Hint engine will use.
Hints are **placement-only**: a hint always identifies a specific cell and digit to fill.
Eliminations may be used internally to derive a placement, but the hint returned to the
player is always a concrete placement.

## Order (simple -> complex)

### Beginner
1. Full House
   - A row/column/box has exactly one empty cell.
2. Naked Single
   - A cell has exactly one remaining candidate.
3. Hidden Single
   - In a row/column/box, a digit fits only one cell.

### Intermediate
4. Locked Candidates (Pointing)
   - In a box, all candidates for a digit lie in one row/column; remove that digit
     from the rest of the row/column outside the box.
5. Locked Candidates (Claiming)
   - In a row/column, all candidates for a digit lie in one box; remove that digit
     from the rest of the box.
6. Naked Pairs
7. Naked Triples
8. Naked Quads
   - If N cells in a unit contain exactly N digits among them, remove those digits
     from other cells in the unit.

### Advanced
9. X-Wing
10. Y-Wing (Bent Triple)
11. Swordfish

### Expert
12. XY-Chain
13. Unique Rectangles
14. Medusa / 3D Medusa

### Esoteric
15. Exocet
16. Sue de Coq
17. Bowman's Bingo (last resort; trial-and-error to contradiction)

## Notes
- The first strategy that yields a placement is used.
- If a strategy only yields eliminations, the engine may apply those eliminations
  internally and then look for a resulting placement before moving on.
- Hint text should mention the strategy that led to the placement.
