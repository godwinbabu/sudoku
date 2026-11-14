import SwiftUI
import UIKit

/// Colours the UIKit parts SwiftUI themes can't reach (slider and switch knobs, navigation titles),
/// so nothing stays system white at night (CODESPEC 12.4). Applies to views created after the call.
enum SystemAppearance {
    @MainActor
    static func apply(_ palette: PSPalette) {
        let knob = palette.isNight ? UIColor(palette.ink) : nil
        UISlider.appearance().thumbTintColor = knob
        UISwitch.appearance().thumbTintColor = palette.isNight ? UIColor(palette.accent) : nil
        let tint = UIColor(palette.ink)
        let bar = UINavigationBar.appearance()
        bar.titleTextAttributes = [.foregroundColor: tint]
        bar.largeTitleTextAttributes = [.foregroundColor: tint]
    }

    /// The app's screen, from its window scene (`UIScreen.main` is deprecated). Its traits ignore the
    /// app's own light or dark override, so they give the system setting. Nil only before a scene exists.
    @MainActor
    static var screen: UIScreen? {
        UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first?.screen
    }
}
