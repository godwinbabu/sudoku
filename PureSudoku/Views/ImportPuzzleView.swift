import SwiftUI
import PhotosUI
import UIKit

/// Import (BYOS, CODESPEC 3.4): Source, Reading, then Check the grid. Pushed from Home, never a sheet.
struct ImportPuzzleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: ImportPuzzleViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotos = false
    let onStart: (ImportedGame) -> Void

    init(viewModel: ImportPuzzleViewModel, onStart: @escaping (ImportedGame) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onStart = onStart
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch viewModel.step {
            case .source: source.transition(.opacity)
            case .reading: reading.transition(.opacity)
            case .review: review.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.step)
        .background(theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(controller.isNight)
        .onChangeOf(selectedPhoto) { newItem in
            guard let newItem else { return }
            let token = viewModel.beginPhotoRequest()
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.applyPhoto(image, token: token)
                    }
                }
                await MainActor.run { selectedPhoto = nil }
            }
        }
        // Both pickers are system screens: shown only after an explicit tap.
        .photosPicker(isPresented: $showPhotos, selection: $selectedPhoto, matching: .images)
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                viewModel.updateImage(image)
            }
        }
        .onDisappear {
            viewModel.discardIfUnused()
        }
        // The first-night screen is drawn from the app root; a system screen would sit above it.
        .onChangeOf(controller.showsFirstNight) { shows in
            if shows {
                showCamera = false
                showPhotos = false
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importPuzzleView")
    }

    private var header: some View {
        HStack(spacing: 0) {
            HeaderIconButton(theme: theme, symbol: "xmark", label: "Discard") { dismiss() }
                .accessibilityIdentifier("importDiscard")
            Text(viewModel.step == .review ? "CHECK THE GRID" : "")
                .psFont(12, weight: .semibold).tracking(0.96).foregroundStyle(theme.ink2)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHidden(viewModel.step != .review) // empty on the other steps
            NightButton()
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
    }

    // MARK: Source

    private var source: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import a puzzle")
                        .psFont(32, weight: .medium, design: .serif)
                        .foregroundStyle(theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("From a newspaper, a book or a screenshot. The photo is read on this iPhone and never uploaded.")
                        .psFont(15).lineSpacing(3).foregroundStyle(theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 22)
                VStack(spacing: 10) {
                    let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
                    optionCard("camera", "Take a photo", hasCamera ? "Camera" : "No camera on this device", id: "importTakePhoto") {
                        showCamera = true
                    }
                    .disabled(!hasCamera)
                    optionCard("photo.on.rectangle", "Choose from Photos", "Screenshots work best", id: "importChoosePhoto") {
                        showPhotos = true
                    }
                    optionCard("pencil", "Type it in", "Enter the givens by hand", id: "importTypeItIn") {
                        viewModel.enterByHand()
                    }
                }
                SectionLabel(theme: theme, title: "For a clean read") // pads itself to 22
                    .padding(.top, 26)
                Text("Fill the frame with the grid · Good light, no glare · Pencil marks are ignored")
                    .psFont(13).lineSpacing(4).foregroundStyle(theme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
            }
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importSource")
    }

    private func optionCard(_ symbol: String, _ title: String, _ subtitle: String, id: String,
                            action: @escaping () -> Void) -> some View {
        OptionCard(theme: theme, symbol: symbol, title: title, subtitle: subtitle, action: action)
            .accessibilityIdentifier(id)
    }

    // MARK: Reading

    private var reading: some View {
        let progress = viewModel.readProgress
        let checked = progress?.cellsChecked ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            if let image = viewModel.image {
                GridPhoto(theme: theme, image: image, corners: progress?.corners)
                    .frame(maxWidth: .infinity, maxHeight: 420)
                    .padding(.horizontal, 24)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Reading digits…")
                    .psFont(26, weight: .medium, design: .serif)
                    .foregroundStyle(theme.ink)
                Text(progress == nil ? "Looking for the grid…" : "Grid found · \(checked) of 81 cells checked")
                    .psFont(15, monospacedDigit: true)
                    .foregroundStyle(theme.ink2)
                    .padding(.top, 6)
                    .accessibilityIdentifier("importReadProgress")
                GeometryReader { geometry in
                    Capsule().fill(theme.hair)
                        .overlay(alignment: .leading) {
                            Capsule().fill(theme.accentDim).frame(width: geometry.size.width * CGFloat(checked) / 81)
                        }
                }
                .frame(height: 3)
                .padding(.top, 16)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importReading")
    }

    // MARK: Check the grid

    private var review: some View {
        VStack(spacing: 0) {
            // Scrolls only when the board and legend don't fit (iPhone SE); the keypad stays put.
            ScrollView(showsIndicators: false) {
                reviewBoardAndLegend
            }
            NumberPadView(theme: theme, keyHeight: 52) { viewModel.setDigit($0) }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("importNumberPad")
            reviewButtons
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importReview")
    }

    private var reviewBoardAndLegend: some View {
        VStack(spacing: 0) {
            SudokuGridView(
                cells: viewModel.displayCells(),
                selectedCellID: viewModel.selectedIndex.map { viewModel.cellIDs[$0] },
                theme: theme,
                // Every cell in the area, so the rings don't spotlight-dim the rest of the board.
                highlight: viewModel.unsureIndices.isEmpty ? HintHighlight()
                    : HintHighlight(areaCells: Set(0..<81), evidenceCells: viewModel.unsureIndices),
                ringedCellValue: "Unsure",
                onSelect: { cell in
                    viewModel.selectCell(id: cell.id)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("importGrid")
            legend
                .padding(.horizontal, 16)
                .padding(.top, 14)
            // A bad or wrong read: back to Source with nothing kept (BYOS.md, retry and reset).
            Button("Start over") { viewModel.startOver() }
                .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 36))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .accessibilityIdentifier("importStartOver")
        }
    }

    private var reviewButtons: some View {
        HStack(spacing: 10) {
            Button { viewModel.clearSelected() } label: {
                Text("Clear cell").frame(maxWidth: .infinity)
            }
            .buttonStyle(PSButtonStyle(theme: theme, kind: .ghost, height: 46))
            .frame(width: 120)
            .accessibilityIdentifier("importClearCell")
            Button {
                Task { if let game = await viewModel.createImportedGame() { onStart(game) } }
            } label: {
                Text("Start puzzle").frame(maxWidth: .infinity)
            }
            .buttonStyle(PSButtonStyle(theme: theme, height: 46))
            .disabled(!viewModel.canStart)
            .accessibilityIdentifier("importStartPuzzle")
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge) // the grid, keypad and these share one screen
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    /// Rings and underlines are shapes, so the legend never relies on hue alone.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.unsureIndices.isEmpty {
                legendLine(bold: "\(viewModel.unsureIndices.count) unsure.",
                           rest: "Ringed cells were hard to read — tap to confirm or fix.") {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(theme.accent, lineWidth: 1.5)
                        .frame(width: 14, height: 14).padding(.top, 2)
                }
                .accessibilityIdentifier("importUnsureLegend")
            }
            if let conflict = viewModel.conflictSummary(names: controller.settings.notation) {
                legendLine(bold: conflict, rest: "Fix one before starting.") {
                    Rectangle().fill(theme.err).frame(width: 14, height: 2).padding(.top, 9)
                }
                .accessibilityIdentifier("importConflictLegend")
            } else {
                if let hint = viewModel.emptyGridHint {
                    Text(hint).psFont(14).foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("importEmptyHint")
                }
                if let message = viewModel.detectionMessage {
                    Text(message).psFont(14).foregroundStyle(theme.ink2)
                }
                Text(viewModel.validationMessage)
                    .psFont(14).foregroundStyle(theme.ink2)
                    .accessibilityIdentifier("importStatus")
                if let note = viewModel.ambiguityNote {
                    Text(note).psFont(14).foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("importAmbiguityNote")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendLine<Swatch: View>(bold: String, rest: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(alignment: .top, spacing: 10) {
            swatch().accessibilityHidden(true)
            // foregroundColor: Text's own foregroundStyle, which keeps `+` working, needs iOS 17.
            (Text(bold).fontWeight(.semibold).foregroundColor(theme.ink) + Text(" " + rest))
                .psFont(14).lineSpacing(2).foregroundStyle(theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A Source option: symbol, title and subtitle, chevron. A plain outline at night.
private struct OptionCard: View {
    let theme: PSPalette
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            PSCard(theme: theme) {
                HStack(spacing: 16) {
                    Image(systemName: symbol)
                        .psFont(24, weight: .regular)
                        .foregroundStyle(theme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).psFont(17).foregroundStyle(theme.ink)
                        Text(subtitle).psFont(13).foregroundStyle(theme.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .psFont(14, weight: .regular)
                        .foregroundStyle(theme.ink3)
                }
                .padding(18)
                .contentShape(Rectangle())
            }
            .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
    }
}

/// The photo with the found grid outlined in `accent` and the area outside dimmed.
private struct GridPhoto: View {
    let theme: PSPalette
    let image: UIImage
    /// Vision's corners (normalised, origin bottom left): top left, top right, bottom right, bottom left.
    let corners: [CGPoint]?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            // At night a lit photo would be the brightest thing on screen: cap it at `ink3`, under the outline.
            .colorMultiply(theme.isNight ? theme.ink3 : .white)
            .overlay {
                GeometryReader { geometry in
                    if let corners, corners.count == 4 {
                        let size = geometry.size
                        let points = corners.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }
                        let outline = Path { $0.addLines(points); $0.closeSubpath() }
                        Path { path in
                            path.addRect(CGRect(origin: .zero, size: size))
                            path.addPath(outline)
                        }
                        .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))
                        boxLines(points).stroke(theme.accentDim, lineWidth: 1.5)
                        outline.stroke(theme.accent, lineWidth: 2)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(theme.hair, lineWidth: 1))
            .accessibilityLabel("Your photo")
    }

    /// The two inner box lines each way, between matching points on opposite edges.
    private func boxLines(_ quad: [CGPoint]) -> Path {
        func lerp(_ from: CGPoint, _ to: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
        let (topLeft, topRight, bottomRight, bottomLeft) = (quad[0], quad[1], quad[2], quad[3])
        return Path { path in
            for t in [CGFloat(1) / 3, CGFloat(2) / 3] {
                path.move(to: lerp(topLeft, topRight, t))
                path.addLine(to: lerp(bottomLeft, bottomRight, t))
                path.move(to: lerp(topLeft, bottomLeft, t))
                path.addLine(to: lerp(topRight, bottomRight, t))
            }
        }
    }
}
