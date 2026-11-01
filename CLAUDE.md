# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

`CODESPEC.md` is the source of truth for behavior. `BYOS.md` is the design for the in-progress "Bring Your Own Sudoku" import feature. `UISPEC.md` and `HINT_STRATEGIES.md` cover UI and hint details.

## Where to work

- Never commit to `main`. Use a feature branch and open a PR with `gh`.

## Build and test

Requires full Xcode (not just Command Line Tools). If `xcodebuild` fails with "requires Xcode", stop and tell the user instead of guessing results. Pick a simulator from `xcrun simctl list devices available` — the README's "iPhone 15" may not exist.

```sh
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination 'platform=iOS Simulator,name=<iPhone>' build
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination '...' test -only-testing:PureSudokuTests
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination '...' test -only-testing:PureSudokuTests/StatsTests/testName
```

Use `/run-tests` to do this end to end.

Lint with `swiftlint lint --quiet` (config: `.swiftlint.yml`; also needs full Xcode for SourceKit). Lint only files you changed; don't mass-fix existing warnings unasked.

## Xcode project gotchas

- `project.pbxproj` uses classic groups, not folder sync: a new `.swift` file is NOT compiled until it is added to the pbxproj. Each file needs a `PBXFileReference`, a `PBXBuildFile`, an entry in its group's `children`, and an entry in the target's `PBXSourcesBuildPhase`. IDs are hand-assigned 24-digit hex (`0000000000000000000000A3`); pick an unused one.
- Unit tests live in `Tests/PureSudokuTests/`, UI tests in `Tests/PureSudokuUITests/`.
- UI tests: puzzles are random, so never hardcode a cell — find one by label (`"... empty"`, `"... value N"`, `"... candidates N"`). A container with `.accessibilityIdentifier` must also have `.accessibilityElement(children: .contain)`, or its id overwrites its children's ids. Query containers with `descendants(matching: .any)`, not `otherElements`.
- `build/` is local derived data (gitignored).
