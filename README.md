# Sudoku Masters

Sudoku Masters is an offline Sudoku app for iPhone. It teaches solving techniques, and it is comfortable to use in bed, in the dark, without waking someone nearby. The code name is PureSudoku.

## Features

- Five levels, from Easy to Master. Each level is graded by the techniques a puzzle needs.
- Night appearance: black screen, dim warm digits, separate Glow and Warmth controls. Night turns sound and vibration off.
- Graduated hints. A hint card first says where to look, then names the technique, then shows why it works on your own board.
- A Learn tab with a lesson for each technique, and practice puzzles for each one.
- Photo import. Take a photo of a printed puzzle, pick one from Photos, type it in, or paste it. The app reads the photo on the iPhone and never uploads it.
- Notes, undo, mistake checking, and a Journal with streaks, best times and settings.
- No account, no network, no analytics. Everything stays on the iPhone.

## Requirements

- iOS 16 or later.
- Full Xcode. The Command Line Tools alone cannot build the app.

## Build and test

1. Open `PureSudoku.xcodeproj` in Xcode.
2. Pick a simulator: run `xcrun simctl list devices available` and use any name from the list.
3. Build and test from the command line, or press ⌘R and ⌘U in Xcode.

```sh
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination 'platform=iOS Simulator,name=<simulator name>' build
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination 'platform=iOS Simulator,name=<simulator name>' test -only-testing:PureSudokuTests
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination 'platform=iOS Simulator,name=<simulator name>' test -only-testing:PureSudokuTests/StatsTests/testName
```

Lint the files you change with `swiftlint lint --quiet`.

## Project layout

- `PureSudoku/Models`: core types such as puzzles, game state, settings and stats.
- `PureSudoku/Engine`: puzzle generation and validation, the technique solver, and the photo reader.
- `PureSudoku/ViewModels`: the state behind each screen.
- `PureSudoku/Views` and `PureSudoku/Theme`: SwiftUI screens, palettes and fonts.
- `PureSudoku/Persistence`: local JSON storage and the imported photo store.
- `Tests/PureSudokuTests` and `Tests/PureSudokuUITests`: unit and UI tests.

The Xcode project lists source files by hand. Add each new `.swift` file to `project.pbxproj`, or it is not compiled.

## Documents

- `CODESPEC.md`: how the app behaves. It is the source of truth.
- `BYOS.md`: how photo import works.
- `HINT_STRATEGIES.md`: the solving techniques, in teaching order.
- `AGENTS.md`: rules for coding agents.
- `design_handoff_v3/`: design assets and tokens.

## Release

- The version comes from the `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` build settings.
- A build phase, "Stamp build number", sets the build number to the commit count on HEAD. It stores the short commit SHA as `PSGitCommit`, with `+dirty` when tracked files have changes. It writes both into the built `Info.plist` only.
- Commit before each App Store Connect upload. It rejects a reused build number.
- Without git, the build keeps `CURRENT_PROJECT_VERSION` and the SHA reads `unknown`.
- `ITSAppUsesNonExemptEncryption` is `NO`, because the app makes no network calls and links no crypto libraries. Check it again if that changes.

## Licences

The code uses the Apache License 2.0 (see `LICENSE`). The app bundles two fonts, Bricolage Grotesque and DM Sans. Both use the SIL Open Font License 1.1. The licence texts are in `PureSudoku/Resources/Fonts`.
