You are working in an existing SwiftUI iOS project called PureSudoku.

The repo already has:

PureSudoku/Views/GameView.swift
PureSudoku/Views/NumberPadView.swift
PureSudoku/ViewModels/GameViewModel.swift
A working game with Easy/Medium/Hard puzzles and a Sleep theme concept in the spec.
Your task is to implement the UI branding + icon concept described below, with minimal disruption to existing logic and layout.

1. Color System & Theme Implementation
Implement a simple, centralized color system that matches this visual direction:

Colors (hex):

appBackgroundDark = #050609
appCardBackground = #11141B
appAccentAmber = #F5B754
appAccentOrange = #F0A34B
appTextPrimary = #F5F1E8
appTextSecondary = #72757F
appErrorRed = #D75A5A
Requirements:

Create a new Swift file, e.g. PureSudoku/Theme/AppColors.swift, containing:

extension Color { static let appBackgroundDark = Color(...) ... }
Use direct RGB/hex values; you do not need to modify Assets.xcassets unless you want to.
Include all 7 colors listed above.
Create a small theme abstraction (if not already present):

enum AppTheme: String, Codable {
    case system
    case light
    case dark
    case sleep
}
If this already exists, extend it rather than redefining.
	3.	Add a simple ThemeManager (or extend an existing Settings/ViewModel) that:
	•	Exposes the current theme (system/light/dark/sleep).
	•	Exposes computed colors for:
	•	background
	•	gridBackground
	•	accent
	•	primaryText
	•	secondaryText
	•	error
Mapping:
	•	Light:
	•	background: .white
	•	gridBackground: Color(white: 0.95)
	•	accent: .appAccentAmber
	•	primaryText: .black
	•	secondaryText: .gray
	•	Dark:
	•	background: .appBackgroundDark
	•	gridBackground: .appCardBackground
	•	accent: .appAccentAmber
	•	primaryText: .appTextPrimary
	•	secondaryText: .appTextSecondary
	•	Sleep:
	•	background: .appBackgroundDark
	•	gridBackground: .appCardBackground
	•	accent: .appAccentAmber or .appAccentOrange
	•	primaryText: .appTextPrimary
	•	secondaryText: .appTextSecondary
	•	error: .appErrorRed but used subtly (no flashing).
	4.	Update major views to use these colors via the theme, not hardcoded system colors:
	•	GameView:
	•	Background should use theme.background.
	•	Grid container / board background should use theme.gridBackground.
	•	Timer, labels, and digits should use theme.primaryText.
	•	NumberPadView:
	•	Default button background: accent color with low opacity.
	•	Disabled digits: use a more muted grayish background and reduced opacity, but keep legible.

Make changes minimally: keep the layout as-is, just adjust the colors.

⸻

2. Bedtime / Sleep Mode Visual Behavior

The project spec defines a Sleep / Bedtime mode that is low-blue-light and non-distracting.

Implement:
	1.	A “Sleep” theme variant:
	•	Make sure when AppTheme.sleep is active:
	•	Background is very dark.
	•	Accent is amber/orange (no blue).
	•	There are no pure-white large surfaces.
	2.	Optional dimming overlay:
	•	In GameView (and possibly at a higher level if you prefer), when the current theme is .sleep:
	•	Add a semi-transparent black overlay with ~0.3–0.4 opacity on top of the background (but behind the grid and numbers), to visually “double-dim” the screen.
	•	This should be driven by the theme manager so it’s easy to tweak.
Example pattern:
ZStack {
    theme.background
    // content
    if theme.isSleep {
        Color.black.opacity(0.35).ignoresSafeArea()
    }
}
3.	Ensure there are no new animations or flashes:
	•	Do not introduce flashing animations.
	•	Keep any transitions subtle (if any).

⸻

3. App Icon Assets (SVG files in repo)

You cannot wire these into Xcode automatically, but you can create design files in the repo so the human can export them.

Create:
	•	Design/icon_primary.svg
	•	Design/icon_sleep.svg

With the following exact contents:

Design/icon_primary.svg
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <defs>
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#050609"/>
      <stop offset="100%" stop-color="#11141B"/>
    </linearGradient>
  </defs>

  <rect x="64" y="64" width="896" height="896" rx="200" fill="url(#bgGrad)" />

  <!-- Subtle outer grid (3x3) -->
  <g stroke="#2A2E3A" stroke-width="8">
    <!-- Vertical lines -->
    <line x1="341.33" y1="192" x2="341.33" y2="832"/>
    <line x1="682.66" y1="192" x2="682.66" y2="832"/>
    <!-- Horizontal lines -->
    <line x1="192" y1="341.33" x2="832" y2="341.33"/>
    <line x1="192" y1="682.66" x2="832" y2="682.66"/>
  </g>

  <!-- Highlighted inner 3x3 block -->
  <rect x="320" y="320" width="384" height="384" rx="48" fill="none" stroke="#F5B754" stroke-width="10"/>

  <!-- Fine inner grid lines (within highlighted block) -->
  <g stroke="#3A3F4C" stroke-width="4">
    <!-- Vertical -->
    <line x1="448" y1="320" x2="448" y2="704"/>
    <line x1="576" y1="320" x2="576" y2="704"/>
    <!-- Horizontal -->
    <line x1="320" y1="448" x2="704" y2="448"/>
    <line x1="320" y1="576" x2="704" y2="576"/>
  </g>

  <!-- Digits inside the block -->
  <!-- 1 top-left -->
  <text x="378" y="422" font-family="SF Pro Display, system-ui, -apple-system" font-weight="600"
        font-size="88" fill="#F5F1E8" text-anchor="middle" dominant-baseline="middle">
    1
  </text>

  <!-- 5 center -->
  <text x="512" y="544" font-family="SF Pro Display, system-ui, -apple-system" font-weight="700"
        font-size="112" fill="#F5B754" text-anchor="middle" dominant-baseline="middle">
    5
  </text>

  <!-- 9 bottom-right -->
  <text x="646" y="666" font-family="SF Pro Display, system-ui, -apple-system" font-weight="600"
        font-size="88" fill="#F5F1E8" text-anchor="middle" dominant-baseline="middle">
    9
  </text>

  <!-- Subtle moon / bedtime hint in top-right corner -->
  <g transform="translate(704, 224)">
    <circle cx="0" cy="0" r="52" fill="none" stroke="#F0A34B" stroke-width="6" opacity="0.85"/>
    <path d="M 18 -40
             A 40 40 0 1 0 18 40
             A 32 32 0 1 1 18 -40 Z"
          fill="#050609"/>
  </g>
</svg>

Design/icon_sleep.svg
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="sleepGrad" cx="0.3" cy="0.2" r="1">
      <stop offset="0%" stop-color="#151821"/>
      <stop offset="100%" stop-color="#050609"/>
    </radialGradient>
  </defs>

  <!-- Background -->
  <rect x="64" y="64" width="896" height="896" rx="200" fill="url(#sleepGrad)" />

  <!-- Very subtle 3x3 grid -->
  <g stroke="#262A35" stroke-width="6" opacity="0.7">
    <line x1="341.33" y1="224" x2="341.33" y2="800"/>
    <line x1="682.66" y1="224" x2="682.66" y2="800"/>
    <line x1="224" y1="341.33" x2="800" y2="341.33"/>
    <line x1="224" y1="682.66" x2="800" y2="682.66"/>
  </g>

  <!-- Dim grid highlight -->
  <rect x="320" y="320" width="384" height="384" rx="48"
        fill="none" stroke="#F5B754" stroke-width="8" opacity="0.9"/>

  <!-- Main moon symbol -->
  <g transform="translate(670, 320)">
    <circle cx="0" cy="0" r="74" fill="#F5B754" opacity="0.12"/>
    <path d="M 26 -60
             A 60 60 0 1 0 26 60
             A 46 46 0 1 1 26 -60 Z"
          fill="#F5B754" opacity="0.9"/>
  </g>

  <!-- Few small “candidate” dots like stars -->
  <circle cx="310" cy="260" r="4" fill="#F5B754" opacity="0.8"/>
  <circle cx="250" cy="360" r="3" fill="#F5B754" opacity="0.6"/>
  <circle cx="380" cy="210" r="3" fill="#F5B754" opacity="0.6"/>
  <circle cx="430" cy="280" r="2" fill="#F5B754" opacity="0.5"/>

  <!-- Subtle center digit hint -->
  <text x="512" y="544" font-family="SF Pro Display, system-ui, -apple-system" font-weight="600"
        font-size="108" fill="#F5F1E8" opacity="0.85"
        text-anchor="middle" dominant-baseline="middle">
    9
  </text>
</svg>

You do not need to hook these into the Xcode asset catalog automatically. Just ensure the SVG files exist in the Design/ folder for later export by a human.

⸻

4. Small Bedtime Icon for In-App Use

Create an in-app icon for Bedtime Mode, implemented as a SwiftUI shape so it tints with current accent color.
	•	Add a new Swift file PureSudoku/Views/Icons/BedtimeIcon.swift with something like:
	•	A small crescent moon drawn with paths or circles.
	•	Designed to be used as:
BedtimeIcon()
    .frame(width: 20, height: 20)
    .foregroundColor(theme.accent)

Make it stylistically consistent with the moon from icon_primary.svg (crescent cut-out).

⸻

5. Cleanup & Tests
	•	Ensure the project still builds.
	•	No behavior changes to Sudoku logic.
	•	UI tests should still pass; if any snapshot-style tests rely on hard-coded colors, update them to use the new theme-based colors.

At the end, summarize:
	•	Files created or edited.
	•	New APIs (Color extension, Theme manager).
	•	How to switch themes (light/dark/sleep) from SettingsView or environment.
