# AGENTS for PureSudoku

This repository contains **PureSudoku**, a no-frills iOS Sudoku app optimized for:
- Clean, NYT-like gameplay
- Offline, local-only behavior
- Bedtime / partner-friendly use (Sleep theme + Bedtime Mode)

All agents **must treat `CODESPEC.md` as the source of truth** for behavior, features, and tests.

---

## 0. Global Rules for All Agents

1. **Always read `CODESPEC.md` first**
   - Before starting any task, skim `CODESPEC.md` and search for relevant sections.
   - Do **not** implement features or behaviors that contradict `CODESPEC.md`.
   - If a user request conflicts with `CODESPEC.md`, either:
     - Adapt the request to fit the spec, or
     - Ask the user if they want to change the spec (and update tests accordingly).

2. **Never introduce a backend**
   - PureSudoku is **offline-only**, with all data stored locally on the device.
   - Do NOT add network calls, remote analytics, or cloud sync unless the spec is explicitly updated.

3. **App identity is fixed**
   - App name: `PureSudoku`
   - Keep this consistent in:
     - Targets
     - Bundle display name
     - Tests (`PureSudokuTests`, `PureSudokuUITests`)
   - Do not rename the app or change the product bundle id without explicit user instruction.

4. **Testing is mandatory**
   - Every new feature or bug fix must be accompanied by:
     - Appropriate **unit tests** (Sudoku logic, state, persistence, stats).
     - **UI tests** for core flows when relevant.
   - Never delete tests without a strong reason and a spec-backed explanation.

5. **Respect Bedtime / Partner-Friendly constraints**
   - Sleep theme / Bedtime Mode are first-class features, not “nice-to-have”.
   - Do not introduce:
     - Sound effects
     - Haptics
     - Bright flashes or high-contrast modals
   - If you must add any of these, they must be OFF by default and controlled via settings in line with `CODESPEC.md`.

6. **MVVM + SwiftUI architecture**
   - Business logic should live in:
     - Engine / Models
     - ViewModels
   - SwiftUI Views should be as “dumb” as possible, focused on rendering state and forwarding user actions.

7. **Prefer clarity over cleverness**
   - Choose simple, readable implementations over overly clever tricks.
   - Follow Apple & Swift style guides:
     - Clear naming
     - Small, focused types
     - Avoid large monolithic views or view models.

---

## 1. Agents Overview

### 1.1 Codegen Agent

**Role:** Primary implementer of features described in `CODESPEC.md`.

**Responsibilities:**

- Implement features in this order when starting a fresh codebase (see Section 11 in `CODESPEC.md`):
  1. Models & Difficulty enum
  2. Sudoku puzzle repository
  3. Sudoku validator
  4. GameState & GameViewModel
  5. Timer logic
  6. GameView (grid, number pad, modes)
  7. Check / Reveal / Reset / New Puzzle features
  8. Persistence (games, settings, stats)
  9. MainMenuView with stats
  10. Theme & SettingsView
  11. Bedtime / Partner-Friendly Mode behavior

- For incremental work:
  - Read the relevant sections in `CODESPEC.md`.
  - Check existing code and tests.
  - Extend **view models** and **engine** first, then wire into Views.

**Rules:**

- Do not hardcode behavior that is specified as configurable (e.g., auto-remove candidates, auto-check mistakes).
- When adding a new feature:
  - Update any relevant models (e.g., `GameState`, `Stats`, `Settings`).
  - Update persistence for those models.
  - Add or update tests.

---

### 1.2 Test Agent

**Role:** Ensure the test suite matches the spec and covers new behavior.

**Responsibilities:**

- Maintain:
  - `PureSudokuTests/` (unit tests)
  - `PureSudokuUITests/` (UI tests)
- For each change:
  - Confirm affected code paths are covered by tests.
  - Add regression tests for previously failing bugs.
  - Avoid fragile UI tests (use accessibility identifiers, avoid depending on exact text where possible).

**Key Areas to Cover (per CODESPEC):**

- Sudoku engine:
  - Row/col/box validation
  - Completion detection
- Game state / GameViewModel:
  - Normal vs Candidate mode behavior
  - Check cell / check puzzle
  - Reveal cell / reveal puzzle
  - Reset puzzle / new puzzle
  - Timer behavior (start/pause/resume)
- Stats:
  - Streak logic
  - Best time per difficulty
  - Total time / puzzles solved
- Persistence:
  - GameState and Stats round-trip (save/load equality)
  - Settings persistence (theme, toggles, bedtimeMode)
- Bedtime/Partner-friendly:
  - Bedtime Mode forces:
    - `AppTheme.sleep`
    - `soundsEnabled == false`
    - `hapticsEnabled == false`
    - Dimming overlay applied (where implemented)

---

### 1.3 Refactor Agent

**Role:** Improve structure and clarity without changing behavior.

**Responsibilities:**

- Identify duplication and extract reusable components (e.g., grid rendering, cell view, overlays).
- Keep MVVM boundaries strong:
  - Logic out of views, into view models/engine.
- Improve naming and file structure to match:
  - `Models/`
  - `Engine/`
  - `ViewModels/`
  - `Views/`
  - `Persistence/`
  - `Tests/`

**Rules:**

- Before refactoring:
  - Ensure tests pass.
- During refactor:
  - Change only what is needed to improve design.
- After refactoring:
  - Run full test suite.
  - If tests fail, fix issues or roll back as needed.
- Do **not** alter public behavior (UX, data formats, visible strings) unless:
  - The change is spec-driven, or
  - The user explicitly asks for those changes.

---

### 1.4 UI/UX Agent

**Role:** Make PureSudoku feel polished while staying minimal and bedtime-friendly.

**Responsibilities:**

- Implement visual requirements:
  - Light / Dark / Sleep themes.
  - Sleep theme with warm, low-blue-light colors.
- Ensure layout is **one-handed friendly**:
  - Number pad and key actions reachable at bottom.
  - Tap targets at least 44x44 pt.
- Maintain calm visuals:
  - Subtle animations, no flashes.
  - Gentle error indicators.

**Rules:**

- Do not add:
  - Animations that flash or blink.
  - Bright full-screen overlays, especially in Sleep theme.
- For any major visual change:
  - Confirm it behaves well in:
    - Light theme
    - Dark theme
    - Sleep theme (with bedtime constraints)

---

## 2. Workflow Expectations

### 2.1 Before Starting a Task

1. Read the user request.
2. Open and scan `CODESPEC.md`:
   - Find relevant sections (e.g., 5. Input Modes, 12. Bedtime Mode).
3. Check existing implementation:
   - Models, ViewModels, Views, Tests.

If the spec does NOT cover a requested behavior:
- Prefer **aligning with the spirit of the spec** (minimalist, NYT-style, bedtime-safe).
- If the change is significant, suggest updating `CODESPEC.md` first.

### 2.2 Implementing a Change

For each change:

1. Update **engine / view models** first.
2. Wire changes into SwiftUI views.
3. Add or update **unit tests**.
4. Add or update **UI tests** if the user-visible flow has changed.
5. Run test suite and ensure it passes.

### 2.3 Handling Ambiguity

- Use `CODESPEC.md` as the arbiter.
- If there is conflicting information:
  - Follow the **most recent / most specific** requirement.
- If a behavior is under-specified:
  - Choose the option that:
    - Keeps app offline.
    - Keeps visuals calm and bedtime-safe.
    - Maintains a no-frills, NYT-like feel.

---

## 3. Special Considerations for PureSudoku

### 3.1 Bedtime / Partner-Friendly (“No Elbow Mode”)

- Sleep theme must always be:
  - Dark
  - Warm-colored
  - Non-flashy
- Bedtime Mode must:
  - Force Sleep theme
  - Disable sound and haptics
  - Apply maximum dimming overlay (where specified)
- Any new feature must be evaluated for bedtime friendliness:
  - Does it create bright flashes?
  - Does it introduce noise/haptics?
  - Does it require two-handed or awkward gestures?

If yes, adjust or gate via settings so bedtime safe usage remains intact.

### 3.2 Future-Proofing

Even though the app is currently offline-only:

- Design models so they’re not tightly coupled to storage layer:
  - Treat persistence as an adapter around pure `Codable` models.
- Avoid assumptions that would break with:
  - Additional puzzle types
  - Extra stats
  - More themes

But do NOT implement future features until they are in `CODESPEC.md`.

---

## 4. What to Do If You’re Unsure

If you (the agent) are unsure what to do:

1. Check `CODESPEC.md` again.
2. Look for similar patterns in existing code.
3. Choose the safest option that:
   - Respects offline-only constraint.
   - Maintains minimal, clean UX.
   - Doesn’t break bedtime friendliness.
4. Optionally leave a TODO comment:
   - `// TODO: Confirm this behavior with product owner (see CODESPEC.md section X.Y)`.

---

## 5. Summary

- **PureSudoku** is a **minimal, offline, bedtime-friendly Sudoku app**.
- `CODESPEC.md` is the single source of truth.
- All agents must:
  - Follow MVVM + SwiftUI.
  - Keep behavior aligned with spec.
  - Maintain and extend tests.
  - Respect Bedtime / Partner-Friendly constraints in all changes.

If a task conflicts with these principles, escalate by proposing an update to `CODESPEC.md` instead of silently diverging.
