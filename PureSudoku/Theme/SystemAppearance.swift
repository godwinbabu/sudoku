import UIKit

/// Colors the UIKit parts SwiftUI themes can't reach (slider and switch knobs, navigation titles),
/// so nothing stays pure white in the Sleep theme (CODESPEC 12.4). Applies to views created after
/// the call. The status bar can only be light or dark, so it stays white in Sleep.
enum SystemAppearance {
    @MainActor
    static func apply(_ palette: SleepPalette?) {
        let knob = palette?.rendered.knob.uiColor
        let tint = palette?.rendered.digit.uiColor
        UISlider.appearance().thumbTintColor = knob
        UISwitch.appearance().thumbTintColor = knob
        let bar = UINavigationBar.appearance()
        bar.titleTextAttributes = tint.map { [.foregroundColor: $0] }
        bar.largeTitleTextAttributes = tint.map { [.foregroundColor: $0] }
    }
}
