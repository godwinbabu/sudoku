import SwiftUI
import PhotosUI
import UIKit

struct ImportPuzzleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var controller: AppController
    @StateObject private var viewModel: ImportPuzzleViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    let onStart: (ImportedGame) -> Void

    init(viewModel: ImportPuzzleViewModel, onStart: @escaping (ImportedGame) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onStart = onStart
    }

    var body: some View {
        let theme = controller.settings.themeColors
        ScrollView {
            VStack(spacing: 18) {
                imageSection(theme: theme)
                gridSection(theme: theme)
                numberPadSection(theme: theme)
                validationSection(theme: theme)
                actionSection(theme: theme)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Import Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Discard") {
                    dismiss()
                }
                .accessibilityIdentifier("importDiscard")
            }
        }
        .onChange(of: selectedPhoto) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.updateImage(image)
                        selectedPhoto = nil
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                viewModel.updateImage(image)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importPuzzleView")
    }

    @ViewBuilder
    private func imageSection(theme: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Puzzle Photo")
                .font(.headline)
                .foregroundColor(theme.primaryText)
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.gridLine.opacity(0.4), lineWidth: 1)
                    )
                if viewModel.isDetecting {
                    Text("Detecting grid…")
                        .font(.footnote)
                        .foregroundColor(theme.secondaryText)
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
                    .frame(height: 160)
                    .overlay(
                        Text("Add a photo or screenshot")
                            .foregroundColor(theme.secondaryText)
                    )
            }
            HStack(spacing: 12) {
                Button("Take Photo") {
                    showCamera = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("Choose Photo")
                }
                .buttonStyle(.bordered)
                if viewModel.image != nil {
                    Button("Remove", role: .destructive) {
                        viewModel.updateImage(nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gridSection(theme: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review & Edit")
                .font(.headline)
                .foregroundColor(theme.primaryText)
            SudokuGridView(
                cells: viewModel.displayCells(),
                selectedCellID: viewModel.selectedIndex.map { viewModel.cellIDs[$0] },
                theme: theme,
                candidateOverlay: [:],
                onSelect: { cell in
                    viewModel.selectCell(id: cell.id)
                }
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .accessibilityIdentifier("importGrid")
        }
    }

    @ViewBuilder
    private func numberPadSection(theme: ThemeColors) -> some View {
        NumberPadView(
            theme: theme,
            disabledDigits: [],
            isCandidateMode: false,
            onDigit: { viewModel.setDigit($0) },
            onClear: { viewModel.clearSelected() }
        )
        .accessibilityIdentifier("importNumberPad")
    }

    @ViewBuilder
    private func validationSection(theme: ThemeColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = viewModel.detectionMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(theme.secondaryText)
            }
            Text(viewModel.validationMessage)
                .font(.footnote)
                .foregroundColor(viewModel.canStart ? theme.secondaryText : theme.error)
            if !viewModel.conflictIndices.isEmpty {
                Text("Tap a cell to correct duplicates.")
                    .font(.footnote)
                    .foregroundColor(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionSection(theme: ThemeColors) -> some View {
        HStack(spacing: 12) {
            Button("Clear All") {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)
            .tint(theme.secondaryText)

            Button("Start Puzzle") {
                if let game = viewModel.createImportedGame() {
                    onStart(game)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(!viewModel.canStart)
            .accessibilityIdentifier("importStartPuzzle")
        }
    }
}
