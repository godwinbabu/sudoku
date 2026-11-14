# PureSudoku

PureSudoku is a no-frills, offline iPhone Sudoku app modeled after the NYT experience and tuned for bedtime use.

## Highlights
- 9×9 puzzles with Easy/Medium/Hard difficulties; tap a difficulty to resume or start instantly.
- Normal and Notes input modes with optional auto-remove-candidates and auto-check-mistakes settings.
- Checks and reveals: Check Cell/Puzzle, Hint (Reveal Cell), Reveal Puzzle, Reset, and New Puzzle.
- Sleep theme + Bedtime Mode: warm, extra-dim, silent (sounds/haptics off by default), one-handed layout.
- Offline-only with local autosave per difficulty and persistent settings/stats.
- Stats tracking: streaks, best time per difficulty, puzzles solved, and total time played.

## Architecture
- SwiftUI + MVVM targeting iOS 16+.
- Engine: Sudoku validator, puzzle repository/loader, game state logic.
- View models: main menu, game, settings, stats, and timer management.
- Views: MainMenu, Game, Settings/Stats with a thumb-friendly grid and number pad.
- Persistence: Codable models stored locally (UserDefaults/FileManager); no backend or analytics.

## Project Structure
- `Models/` core types (Difficulty, SudokuCell, SudokuPuzzle, GameState, Stats, AppTheme).
- `Engine/` validator, puzzle repository (and optional generator stub).
- `ViewModels/` state managers for menu, game, settings, stats, and timer handling.
- `Views/` SwiftUI screens and shared components.
- `PureSudokuTests/`, `PureSudokuUITests/` for unit and UI coverage.

## Run the App
1. Open `PureSudoku.xcodeproj` in Xcode 15+.
2. Select the `PureSudoku` scheme and an iOS 16+ simulator or device.
3. Build & run (`⌘R`).

## Testing
- Unit tests: `PureSudokuTests` cover engine, game state, stats, persistence, and settings.
- UI tests: `PureSudokuUITests` cover launching, starting a game, input modes, resets, and bedtime/sleep visuals.
- CLI: `xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination 'platform=iOS Simulator,name=<iPhone>' test` (pick a name from `xcrun simctl list devices available`)

## Release
- `Info.plist` reads the version from the `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` build settings.
- Before each App Store Connect upload, raise the build number: run `agvtool next-version` in the repo root, or change Build under the target's General tab in Xcode. App Store Connect rejects a reused build number.
- `ITSAppUsesNonExemptEncryption` is `NO` because the app makes no network calls and links no crypto libraries. Check it again if that changes.

## Development Notes
- `CODESPEC.md` is the source of truth; keep behavior in sync with it.
- Preserve offline/local-only behavior; do not add network calls, backend, analytics, or cloud sync.
- Respect bedtime/partner-friendly constraints: Sleep theme defaults when Bedtime Mode is on; sounds/haptics are off by default; avoid bright flashes.
