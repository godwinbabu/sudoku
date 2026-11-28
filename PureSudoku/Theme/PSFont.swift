import SwiftUI
import UIKit

/// Chrome text that scales with Dynamic Type (CODESPEC 9). The design's point size is kept at the
/// default text size (Large) and scales like the nearest system text style.
enum PSFont {
    /// The text style whose scaling curve fits a design size best.
    static func textStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<12: return .caption2
        case ..<13: return .caption1
        case ..<15: return .footnote
        case ..<16: return .subheadline
        case ..<17: return .callout
        case ..<18: return .body
        case ..<20: return .title3
        case ..<22: return .title2
        case ..<28: return .title1
        default: return .largeTitle
        }
    }

    /// The bundled face for a weight (Resources/Fonts, OFL). Display text uses Bricolage Grotesque, which
    /// ships in 500 and 800 only; everything else uses DM Sans.
    static func faceName(weight: Font.Weight, display: Bool) -> String {
        if display {
            return [.semibold, .bold, .heavy, .black].contains(weight)
                ? "BricolageGrotesque96ptExtraBold-ExtraBold" : "BricolageGrotesque96ptExtraBold-Medium"
        }
        switch weight {
        case .medium: return "DMSans9pt-Medium"
        case .semibold: return "DMSans9pt-SemiBold"
        case .bold, .heavy, .black: return "DMSans9pt-Bold"
        default: return "DMSans9pt-Regular"
        }
    }

    /// A bundled face at a fixed size. Board digits and keys use this: they follow Clarity, not Dynamic Type.
    static func fixed(_ size: CGFloat, weight: Font.Weight, display: Bool = true) -> Font {
        .custom(faceName(weight: weight, display: display), fixedSize: size)
    }

    /// `size` scaled for `dynamicTypeSize`; equal to `size` at `.large`.
    static func scaledSize(_ size: CGFloat, at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: textStyle(for: size)).scaledValue(for: size, compatibleWith: traits)
    }
}

private struct PSFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let monospacedDigit: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        // `.serif` was the v2 display face; v3 draws display text in Bricolage Grotesque (CODESPEC 7.2).
        let display = design == .serif
        let font = Font.custom(PSFont.faceName(weight: weight, display: display),
                               fixedSize: PSFont.scaledSize(size, at: dynamicTypeSize))
        content
            .font(monospacedDigit ? font.monospacedDigit() : font)
            // −0.02 em on Bricolage at 21 pt and above.
            .tracking(display && size >= 21 ? -0.02 * size : 0)
    }
}

extension View {
    /// `.font(.system(size:weight:design:))` that scales with Dynamic Type. A `.dynamicTypeSize`
    /// clamp above it also clamps this text.
    func psFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default,
                monospacedDigit: Bool = false) -> some View {
        modifier(PSFontModifier(size: size, weight: weight, design: design, monospacedDigit: monospacedDigit))
    }
}

/// A label and its control side by side, stacked at accessibility text sizes so neither is
/// squeezed (CODESPEC 9).
struct PSAdaptiveStack<Content: View>: View {
    var alignment = VerticalAlignment.center
    var spacing: CGFloat?
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        layout { content }
            // Stacked, a Spacer meant to push the control aside must not open a vertical gap.
            .fixedSize(horizontal: false, vertical: stacked)
            .frame(maxWidth: stacked ? .infinity : nil, alignment: .leading)
    }
}

/// Buttons in a row, or one above the other at accessibility text sizes (CODESPEC 9).
struct PSButtonRow<Content: View>: View {
    /// Pushes the row to the trailing edge; false centres it.
    var trailing = true
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: trailing ? .trailing : .center, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            if trailing && !stacked { Spacer(minLength: 0) }
            content
        }
        .frame(maxWidth: stacked ? .infinity : nil, alignment: trailing ? .trailing : .center)
    }
}
