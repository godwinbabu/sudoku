import SwiftUI
import PhotosUI
import UIKit

struct ImportPuzzleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var controller: AppController
    @Environment(\.psPalette) private var palette
    @StateObject private var viewModel: ImportPuzzleViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    let onStart: (ImportedGame) -> Void

    init(viewModel: ImportPuzzleViewModel, onStart: @escaping (ImportedGame) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onStart = onStart
    }

    var body: some View {
        let theme = palette
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
        .background(theme.bg.ignoresSafeArea())
        .themedTitle("Import Puzzle")
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
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                viewModel.updateImage(image)
            }
        }
        .onDisappear {
            viewModel.discardIfUnused()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("importPuzzleView")
    }

    @ViewBuilder
    private func imageSection(theme: PSPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Puzzle Photo")
                .font(.headline)
                .foregroundColor(theme.ink)
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.lineMajor.opacity(0.4), lineWidth: 1)
                    )
                if viewModel.isDetecting {
                    Text("Detecting grid…")
                        .font(.footnote)
                        .foregroundColor(theme.ink2)
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surface)
                    .frame(height: 160)
                    .overlay(
                        Text("Add a photo or screenshot")
                            .foregroundColor(theme.ink2)
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
    private func gridSection(theme: PSPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review & Edit")
                .font(.headline)
                .foregroundColor(theme.ink)
            SudokuGridView(
                cells: viewModel.displayCells(),
                selectedCellID: viewModel.selectedIndex.map { viewModel.cellIDs[$0] },
                theme: theme,
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
    private func numberPadSection(theme: PSPalette) -> some View {
        NumberPadView(theme: theme, keyHeight: 52) { viewModel.setDigit($0) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("importNumberPad")
    }

    @ViewBuilder
    private func validationSection(theme: PSPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = viewModel.detectionMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(theme.ink2)
            }
            Text(viewModel.validationMessage)
                .font(.footnote)
                .foregroundColor(viewModel.canStart ? theme.ink2 : theme.err)
            if !viewModel.conflictIndices.isEmpty {
                Text("Tap a cell to correct duplicates.")
                    .font(.footnote)
                    .foregroundColor(theme.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionSection(theme: PSPalette) -> some View {
        HStack(spacing: 12) {
            Button("Clear cell") {
                viewModel.clearSelected()
            }
            .buttonStyle(.bordered)
            .tint(theme.ink2)
            .accessibilityIdentifier("importClearCell")

            Button("Clear All") {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)
            .tint(theme.ink2)

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
