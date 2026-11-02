// Reference: the v2 Settings model. Replaces theme/bedtimeMode/sleepBrightness in Models/Settings.swift.
// Keep Codable migration: decode old keys and map them (see migrate()).
import Foundation

enum MistakeMode: String, Codable, CaseIterable { case immediate, onCheck, never }
enum CellNotation: String, Codable, CaseIterable { case plain, grid } // "row 5, column 2" vs "R5C2"

struct SettingsV2: Codable, Equatable {
    // Display & Night
    var appearance: Appearance = .afterDark
    var glow: Double = 18            // 0…100
    var warmth: Double = 75          // 0…100
    var clarity: Clarity = .standard
    var glowFloor: Double = 0        // set by "Find my lowest glow"; glow and Drift never go below it
    var calibrated: Bool = false     // false → First-night flow on the first Night launch
    var drift: Bool = true           // during a night game: −1 glow / +1 warmth every 90 s, max 20 each
    var hideStatusBarInGames: Bool = true
    var useLocationForAfterDark: Bool = true
    var afterDarkStart = DateComponents(hour: 21, minute: 0)   // fallback when no location
    var afterDarkEnd = DateComponents(hour: 6, minute: 30)
    // Quiet (Night always forces both off)
    var soundsEnabled: Bool = false
    var hapticsEnabled: Bool = false
    // Assists
    var mistakes: MistakeMode = .immediate
    var tidyNotes: Bool = true       // was autoRemoveCandidates
    var showTimer: Bool = true
    var notation: CellNotation = .plain
    // Imports (unchanged)
    var keepImportImages: Bool = true

    /// Night is active when appearance is .night, or .afterDark inside the window,
    /// or .matchSystem with a dark colour scheme (matchSystem uses the Day palette for light and Night for dark).
    func isNight(now: Date, sunset: Date?, sunrise: Date?, systemIsDark: Bool) -> Bool {
        switch appearance {
        case .day: return false
        case .night: return true
        case .matchSystem: return systemIsDark
        case .afterDark:
            if useLocationForAfterDark, let ss = sunset, let sr = sunrise { return now >= ss || now < sr }
            let cal = Calendar.current, h = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
            let start = (afterDarkStart.hour ?? 21) * 60 + (afterDarkStart.minute ?? 0)
            let end = (afterDarkEnd.hour ?? 6) * 60 + (afterDarkEnd.minute ?? 30)
            return h >= start || h < end
        }
    }

    /// Old → new mapping.
    /// theme .light → .day; .dark → .night; .system → .matchSystem; bedtimeMode true or theme .sleep → .night with Lights out.
    /// sleepBrightness .normal/.dim/.extraDim → glow 55/30/18. autoRemoveCandidates → tidyNotes.
    /// autoCheckMistakes true → .immediate, false → .onCheck.
}
