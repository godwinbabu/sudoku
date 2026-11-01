import SwiftUI

/// About a minute in a dark room: text size, dimness, contrast, warmth (CODESPEC 12.3).
/// The preview grid uses the palette being edited, so the player sees the real result.
struct DisplayCalibrationView: View {
    @State private var profile: DisplayProfile
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    let onSave: (DisplayProfile) -> Void
    let onCancel: () -> Void

    init(profile: DisplayProfile, onSave: @escaping (DisplayProfile) -> Void, onCancel: @escaping () -> Void) {
        _profile = State(initialValue: profile)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        let palette = SleepPalette(profile: profile, increaseContrast: UIAccessibility.isDarkerSystemColorsEnabled)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Do this in the dark, where you play.")
                    .font(.subheadline)
                    .foregroundColor(palette.color(luminance: palette.levels.candidate).color)
                CalibrationPreview(palette: palette, typeSize: max(systemTypeSize, SleepPalette.typeSize(profile.textSize)))
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                step(1, "Text size", "Pick a size you can read without effort.", value: $profile.textSize, id: "calibration_textSize")
                step(2, "Dimness", "Slide right until the digits are just comfortable, then go one step back.", value: $profile.dimness, id: "calibration_dimness")
                step(3, "Contrast", "Raise it until the small notes are as easy to read as you need.", value: $profile.contrast, id: "calibration_contrast")
                step(4, "Warmth", "Neutral to amber to orange-red. Pick what feels easiest.", value: $profile.warmth, id: "calibration_warmth")
                Toggle("Lower the screen to its minimum while playing", isOn: $profile.lowersScreenBrightness)
                    .accessibilityIdentifier("calibration_lowerScreen")
                TextField("Profile name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("calibration_name")
                Text(Self.reduceWhitePointTip)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(palette.color(luminance: palette.levels.digit).color)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled() // Cancel always runs, so the first-time offer is recorded
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Calibrate display").font(.headline)
                    .foregroundColor(palette.color(luminance: max(palette.levels.digit, 0.08)).color)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(profile) }
                    .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("calibration_save")
            }
        }
        // Cancel and Save stay readable even at the dimmest setting, so the player can always get out.
        .tint(palette.color(luminance: max(palette.levels.digit, 0.08)).color)
        .preferredColorScheme(.dark)
    }

    private static let reduceWhitePointTip = "Want it even dimmer? iOS can go far below any app: "
        + "Settings › Accessibility › Display & Text Size › Reduce White Point. "
        + "Add it to Accessibility Shortcut to turn it on with a triple-click."

    private func step(_ number: Int, _ title: String, _ help: String, value: Binding<Double>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(number). \(title)").font(.headline)
            Text(help).font(.footnote).fixedSize(horizontal: false, vertical: true)
            Slider(value: value, in: 0...1, step: 0.05)
                .accessibilityIdentifier(id)
        }
    }
}

/// A 3×3 corner of a grid with digits, notes and lines, drawn in the palette being edited.
private struct CalibrationPreview: View {
    let palette: SleepPalette
    let typeSize: DynamicTypeSize

    private let values: [Int?] = [5, nil, 3, nil, 7, nil, 8, nil, 1]
    private let notes: [Set<Int>] = [[], [2, 4, 6], [], [1, 2, 9], [], [4, 6], [], [2, 9], []]

    var body: some View {
        let digit = palette.color(luminance: palette.levels.digit).color
        let note = palette.color(luminance: palette.levels.candidate).color
        let line = palette.color(luminance: palette.levels.gridLine).color
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 0) {
            ForEach(0..<9, id: \.self) { index in
                ZStack {
                    Rectangle().stroke(line, lineWidth: 1)
                    if let value = values[index] {
                        Text("\(value)").font(.title).foregroundColor(digit)
                    } else {
                        Text(notes[index].sorted().map(String.init).joined(separator: " "))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(note)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .overlay(Rectangle().stroke(line, lineWidth: 2.5))
        .dynamicTypeSize(typeSize)
    }
}
