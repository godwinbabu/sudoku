# CLAUDE.md

This file guides Claude Code (claude.ai/code) in this repository.

@AGENTS.md

`CODESPEC.md` is the source of truth for behavior. `BYOS.md` is the design of the photo-import pipeline. `HINT_STRATEGIES.md` lists the hint techniques.

## Where to work

- Never commit to `main`. Use a feature branch and open a PR with `gh`.

## Build and test

You need full Xcode, not only Command Line Tools. If `xcodebuild` fails with "requires Xcode", stop and tell the user. Do not guess results. Pick a simulator from `xcrun simctl list devices available`. The README's "iPhone 15" may not exist.

```sh
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination 'platform=iOS Simulator,name=<iPhone>' build
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination '...' test -only-testing:PureSudokuTests
xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku -destination '...' test -only-testing:PureSudokuTests/StatsTests/testName
```

Use `/run-tests` to do this end to end.

Lint with `swiftlint lint --quiet` (config: `.swiftlint.yml`). It also needs full Xcode for SourceKit. Lint only the files you changed. Do not mass-fix existing warnings unless asked.

## Xcode project gotchas

- `project.pbxproj` uses classic groups, not folder sync. Xcode does not compile a new `.swift` file until you add it to the pbxproj.
- Each new file needs four entries: a `PBXFileReference`, a `PBXBuildFile`, a line in its group's `children`, and a line in the target's `PBXSourcesBuildPhase`.
- IDs are hand-assigned 24-digit hex (`0000000000000000000000A3`). Pick an unused one.
- Unit tests live in `Tests/PureSudokuTests/`. UI tests live in `Tests/PureSudokuUITests/`.
- `build/` is local derived data (gitignored).

## UI test rules

- Puzzles are random. Never hardcode a cell. Find one by label: `"... empty"`, `"... value N"` or `"... candidates N"`.
- A container with `.accessibilityIdentifier` must also have `.accessibilityElement(children: .contain)`. Otherwise its id overwrites its children's ids.
- Query containers with `descendants(matching: .any)`, not `otherElements`.
