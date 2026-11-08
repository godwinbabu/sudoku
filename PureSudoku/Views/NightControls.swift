import SwiftUI

// Controls shared by the Night sheet, Display & Night and the first-night flow (Design/v2/README.md).
// All are drawn from the palette, so nothing renders system white at night (CODESPEC 12.4).

/// Segmented control: 34 pt segments in a 1 pt hair ring. Day marks the choice with a surface2
/// fill; Night with an accentDim ring, because nothing lit may sit behind text. At accessibility
/// text sizes the options stack, full width, and each shape grows with its text (CODESPEC 9).
struct PSSegmented<Value: Hashable>: View {
    let theme: PSPalette
    let options: [(Value, String)]
    let selection: Value?
    var idPrefix = ""
    let onSelect: (Value) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ForEach(options, id: \.0) { value, title in
                let on = value == selection
                Button { onSelect(value) } label: {
                    Text(title)
                        .psFont(14, weight: on ? .semibold : .regular)
                        .foregroundColor(on ? theme.ink : theme.ink2)
                        .lineLimit(stacked ? nil : 1)
                        .minimumScaleFactor(stacked ? 1 : 0.8)
                        .fixedSize(horizontal: false, vertical: stacked)
                        .padding(.vertical, stacked ? 8 : 0)
                        .frame(maxWidth: .infinity, minHeight: stacked ? 44 : 34)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(on && !theme.isNight ? theme.surface2 : .clear)
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(on && theme.isNight ? theme.accentDim : .clear, lineWidth: 1))
                        )
                        .padding(.vertical, stacked ? 3 : 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityShowsLargeContentViewer()
                .accessibilityIdentifier("\(idPrefix)\(value)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, stacked ? 3 : 0)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.hair, lineWidth: 1).frame(height: stacked ? nil : 40))
    }
}

/// A 48 × 28 switch with a 44 pt target. Night: an outline track with an accent knob.
struct PSToggle: View {
    let theme: PSPalette
    let isOn: Bool
    let label: String
    let onChange: (Bool) -> Void

    var body: some View {
        let ring = isOn ? (theme.isNight ? theme.accentDim : .clear) : theme.hair
        let knob = isOn ? (theme.isNight ? theme.accent : theme.bg) : theme.ink3
        Button { onChange(!isOn) } label: {
            Capsule()
                .fill(isOn && !theme.isNight ? theme.accent : .clear)
                .overlay(Capsule().strokeBorder(ring, lineWidth: 1.5))
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(knob).frame(width: 20, height: 20).padding(4)
                }
                .frame(width: 48, height: 28)
                .frame(minWidth: 48, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .modifier(ToggleTrait())
    }
}

/// VoiceOver reads a switch, not a plain button (the trait is iOS 17+; the app targets iOS 16).
private struct ToggleTrait: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) { content.accessibilityAddTraits(.isToggle) } else { content }
    }
}

/// A 6 pt track with a 28 pt ink thumb in a 5 pt bg halo (at night an ink ring, so the knob is never
/// the brightest shape). Steps by whole numbers.
struct PSSlider: View {
    let theme: PSPalette
    let value: Double
    var range: ClosedRange<Double> = 0...100
    var track: LinearGradient?
    let label: String
    let valueText: String
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let span = range.upperBound - range.lowerBound
            let usable = max(1, geometry.size.width - 28)
            let x = (min(range.upperBound, max(range.lowerBound, value)) - range.lowerBound) / span * usable
            ZStack(alignment: .leading) {
                Group {
                    if let track { Capsule().fill(track) } else { Capsule().fill(theme.hair) }
                }
                .frame(height: 6)
                Circle()
                    .fill(theme.isNight ? theme.bg : theme.ink)
                    .overlay(Circle().strokeBorder(theme.isNight ? theme.ink2 : .clear, lineWidth: 2))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.bg).frame(width: 38, height: 38))
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { tap in set(tap.location.x, usable: usable, span: span) })
            // Simultaneous, so a vertical drag still scrolls the parent; only mostly sideways movement sets the value.
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { drag in
                guard abs(drag.translation.width) >= abs(drag.translation.height) else { return }
                set(drag.location.x, usable: usable, span: span)
            })
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            let step: Double = direction == .increment ? 5 : -5
            onChange(min(range.upperBound, max(range.lowerBound, value + step)))
        }
    }

    private func set(_ x: Double, usable: Double, span: Double) {
        let raw = range.lowerBound + (x - 14) / usable * span
        let next = min(range.upperBound, max(range.lowerBound, raw.rounded()))
        if next != value { onChange(next) }
    }

    /// The Warmth track: real Kelvin colours at 75% of the current luminance. At night each stop is
    /// also capped at 75% of the ink's light, so the cool end never outshines the digits.
    static func kelvinTrack(luminance: Double, inkWarmth: Double? = nil) -> LinearGradient {
        func lightness(_ c: RGB255) -> Double { 0.2126 * pow(c.r / 255, 2.2) + 0.7152 * pow(c.g / 255, 2.2) + 0.0722 * pow(c.b / 255, 2.2) }
        let ink = inkWarmth.map { lightness(Blackbody.rgb(kelvin: Blackbody.kelvin(forWarmth: $0))) }
        let colors = stride(from: 0.0, through: 100, by: 25).map { warmth -> Color in
            let c = Blackbody.rgb(kelvin: Blackbody.kelvin(forWarmth: warmth))
            let cap = ink.map { pow(min(1, $0 / lightness(c)), 1 / 2.2) } ?? 1
            let s = luminance * 0.75 * cap
            return Color(.sRGB, red: c.r * s / 255, green: c.g * s / 255, blue: c.b * s / 255, opacity: 1)
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

/// A label, its value and a footnote above a slider.
struct SliderRow<Control: View>: View {
    let theme: PSPalette
    let label: String
    let value: String
    let sub: String
    @ViewBuilder let control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PSAdaptiveStack(alignment: .firstTextBaseline) {
                Text(label).psFont(16).foregroundColor(theme.ink)
                Spacer(minLength: 0)
                Text(value).psFont(15, monospacedDigit: true).foregroundColor(theme.ink2)
            }
            control
            Text(sub).psFont(13).foregroundColor(theme.ink3)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }
}

/// The Glow and Warmth sliders, shared by the Night sheet and Display & Night.
struct NightSliders: View {
    let theme: PSPalette
    let settings: Settings
    let glowNote: String
    let warmthNote: String
    var idPrefix = ""
    let onGlow: (Double) -> Void
    let onWarmth: (Double) -> Void

    var body: some View {
        let glow = "\(Int(settings.glow))%"
        let kelvin = NightSheetView.kelvinText(settings.warmth)
        // At night the track is capped by the ink's light; in Day it is the plain Kelvin ramp.
        let track = PSSlider.kelvinTrack(luminance: theme.luminance, inkWarmth: theme.isNight ? settings.warmth : nil)
        VStack(spacing: 0) {
            SliderRow(theme: theme, label: "Glow", value: glow, sub: glowNote) {
                PSSlider(theme: theme, value: settings.glow, label: "Glow", valueText: glow, onChange: onGlow)
                    .accessibilityIdentifier("\(idPrefix)glow")
            }
            SliderRow(theme: theme, label: "Warmth", value: kelvin, sub: warmthNote) {
                PSSlider(theme: theme, value: settings.warmth, track: track, label: "Warmth", valueText: kelvin, onChange: onWarmth)
                    .accessibilityIdentifier("\(idPrefix)warmth")
            }
        }
    }
}

/// Three preset chips: 36 pt tall (44 pt target), a 1.5 pt ring that is accentDim when active.
/// At accessibility text sizes they stack, full width, and each ring grows with its text (CODESPEC 9).
struct PresetChips: View {
    let theme: PSPalette
    let current: NightPreset?
    var idPrefix = "preset_"
    let onSelect: (NightPreset) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(NightPreset.allCases) { preset in
                let on = preset == current
                Button { onSelect(preset) } label: {
                    Text(preset.title)
                        .psFont(13, weight: .medium)
                        .foregroundColor(on ? theme.accent : theme.ink2)
                        .lineLimit(stacked ? nil : 1)
                        .minimumScaleFactor(stacked ? 1 : 0.8)
                        .fixedSize(horizontal: false, vertical: stacked)
                        .padding(.vertical, stacked ? 8 : 0)
                        .frame(maxWidth: .infinity, minHeight: stacked ? 44 : 36)
                        .background(Capsule().strokeBorder(on ? theme.accentDim : theme.hair, lineWidth: 1.5))
                        .padding(.vertical, stacked ? 0 : 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityShowsLargeContentViewer()
                .accessibilityIdentifier("\(idPrefix)\(preset.rawValue)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }
}

/// A list row: title, optional footnote, trailing control; a hair line under it unless last.
struct SettingRow<Trailing: View>: View {
    let theme: PSPalette
    let label: String
    var sub: String?
    var last = false
    @ViewBuilder let trailing: Trailing

    var body: some View {
        PSAdaptiveStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).psFont(16).foregroundColor(theme.ink)
                if let sub {
                    Text(sub).psFont(13).foregroundColor(theme.ink3).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { if !last { theme.hair.frame(height: 1) } }
    }
}

/// An accent text button with a 44 pt target ("Start", "Check again").
struct LinkButton: View {
    let theme: PSPalette
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).psFont(15, weight: .medium).foregroundColor(theme.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A card: surface fill in Day; at night transparent, with the same 1 pt hair border.
struct PSCard<Content: View>: View {
    let theme: PSPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 18).fill(theme.isNight ? .clear : theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.hair, lineWidth: 1))
            .padding(.horizontal, 16)
    }
}

struct SectionLabel: View {
    let theme: PSPalette
    let title: String

    var body: some View {
        Text(title.uppercased())
            .psFont(12, weight: .semibold)
            .tracking(0.96)
            .foregroundColor(theme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Five 52 pt sample cells: given 5, entered 3, selected 7, mistake 4, notes.
struct SamplePreview: View {
    let theme: PSPalette
    let type: PSType

    var body: some View {
        HStack(spacing: 10) {
            cell { digit("5", color: theme.ink, weight: type.givenWeight(night: theme.isNight)) }
            cell { digit("3", color: theme.accent, weight: type.userWeight) }
            cell(selected: true) { digit("7", color: theme.accent, weight: type.userWeight) }
            cell {
                digit("4", color: theme.err, weight: type.userWeight)
                    .overlay(alignment: .bottom) { theme.err.frame(height: 2).padding(.horizontal, -3).offset(y: 3) }
            }
            cell { notes }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample cells")
    }

    private func digit(_ text: String, color: Color, weight: Font.Weight) -> some View {
        Text(text).font(.system(size: 30 * type.digitScale, weight: weight)).foregroundColor(color)
    }

    private var notes: some View {
        let marks = ["1", "", "3", "", "", "", "7", "", "9"]
        return VStack(spacing: 0) {
            ForEach(0..<3) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3) { col in
                        let mark = marks[row * 3 + col]
                        Text(mark)
                            .font(.system(size: 11 * type.candidateScale, weight: mark == "7" ? .bold : .regular))
                            .foregroundColor(mark == "7" ? theme.accent : theme.ink2)
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
    }

    private func cell<Content: View>(selected: Bool = false, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 4).fill(selected ? theme.sel : .clear))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? theme.accent : theme.line, lineWidth: selected ? 2 : 1))
    }
}

/// Find my lowest glow: six tiles drawn in the night ink at glow 0 / 4 / 8 / 14 / 22 / 32.
struct CalibrateView: View {
    static let levels: [Double] = [0, 4, 8, 14, 22, 32]
    private static let digits = ["8", "3", "6", "5", "9", "2"]

    let theme: PSPalette
    let settings: Settings
    /// The first-night flow has no Cancel.
    var onCancel: (() -> Void)?
    let onUse: (Double) -> Void
    @State private var pick: Double?
    @EnvironmentObject private var controller: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // At night the words stay dimmer than the tiles, so they don't undo the eyes' adjusting.
            Text("Which is the faintest you can read?")
                .psFont(24, weight: .medium, design: .serif)
                .foregroundColor(theme.isNight ? theme.ink3 : theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Give your eyes a moment in the dark first. Tap the dimmest digit you can read without effort.")
                .psFont(14)
                .foregroundColor(theme.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 22)
            HStack(spacing: 8) {
                ForEach(Array(Self.levels.enumerated()), id: \.offset) { index, glow in
                    // Drawn as the board would be (same warmth, Clarity, contrast floor), so the pick is honest.
                    let ink = { var tile = settings; tile.glow = glow; return tile.palette(isNight: true).ink }()
                    let on = pick == glow
                    Button { pick = glow } label: {
                        Text(Self.digits[index])
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 76)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? theme.accent : theme.hair, lineWidth: on ? 2 : 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Glow \(Int(glow))%")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("calibrate_\(Int(glow))")
                }
            }
            PSButtonRow {
                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost))
                        .accessibilityIdentifier("calibrate_cancel")
                }
                Button("Use this") { if let pick { onUse(pick) } }
                    .buttonStyle(PSButtonStyle(theme: theme))
                    .disabled(pick == nil)
                    .accessibilityIdentifier("calibrate_use")
            }
            .padding(.top, 22)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calibrateView")
        // The tiles show the palette layer only, so judge them at the minimum backlight (CODESPEC 12.3).
        .onAppear { controller.isCalibrating = true }
        .onDisappear { controller.isCalibrating = false }
    }
}

extension NightPreset {
    /// The preset the settings match once the floor is applied, if any.
    static func matching(_ settings: Settings) -> NightPreset? {
        allCases.first { max($0.glow, settings.glowFloor) == settings.glow && $0.warmth == settings.warmth }
    }
}
