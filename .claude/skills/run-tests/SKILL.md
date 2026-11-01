---
name: run-tests
description: Build PureSudoku and run its XCTest suites on an iOS simulator, then report failures. Use after any code change, before claiming a fix works, or when the user asks to run tests. Accepts an optional test filter (e.g. "ui", "all", or "PureSudokuTests/StatsTests").
---

Run PureSudoku tests from the repo root (the directory with `PureSudoku.xcodeproj`).

1. Check for Xcode: run `xcodebuild -version`. If it fails or says it requires Xcode, stop. Tell the user full Xcode is not installed or selected (`sudo xcode-select -s /Applications/Xcode.app`). Do not report any test result.

2. Pick a simulator: run `xcrun simctl list devices available` and choose the newest available iPhone. Use its name in `-destination 'platform=iOS Simulator,name=<name>'`.

3. Choose the scope from `$ARGUMENTS`:
   - empty → `-only-testing:PureSudokuTests` (unit tests only, fast)
   - `ui` → `-only-testing:PureSudokuUITests`
   - `all` → no `-only-testing` flag
   - anything else → `-only-testing:$ARGUMENTS`

4. Run:
   ```sh
   xcodebuild -project PureSudoku.xcodeproj -scheme PureSudoku \
     -destination 'platform=iOS Simulator,name=<name>' \
     -derivedDataPath build test <scope> 2>&1 | tail -n 200
   ```
   For long output, grep for `error:`, `failed`, `** TEST` and `Test Case .* failed`.

5. If the build fails with "cannot find X in scope" for a type that exists on disk, check that the file is listed in `PureSudoku.xcodeproj/project.pbxproj` (see CLAUDE.md).

6. Report: pass/fail counts, each failing test with its file:line and assertion message, and the exact command used. Never say tests pass unless `** TEST SUCCEEDED **` appeared.
