import Foundation
import UIKit

@MainActor
final class ImportPuzzleViewModel: ObservableObject {
    enum SolvableState: Equatable {
        case unknown
        case solvable
        case unsolvable
    }

    /// The three import screens (CODESPEC 3.4): pick a source, read the photo, check the grid.
    enum Step: Equatable {
        case source, reading, review
    }

    @Published private(set) var gridValues: [Int?]
    @Published private(set) var conflictIndices: Set<Int> = []
    @Published private(set) var solvableState: SolvableState = .unknown
    @Published var selectedIndex: Int?
    @Published private(set) var image: UIImage?
    @Published private(set) var imageID: String?
    @Published private(set) var detectionMessage: String?
    @Published private(set) var isDetecting: Bool = false
    /// Read digits the detector was unsure of; confirmed by tapping or fixing the cell.
    @Published private(set) var unsureIndices: Set<Int> = []
    @Published private(set) var readProgress: SudokuImageDetector.ReadProgress?
    @Published private(set) var isEnteringByHand = false

    private let generatorService: SudokuGeneratorService
    private let imageDetector: SudokuImageDetector
    private let createGame: (String, String?) -> ImportedGame?
    private let saveImage: (UIImage) -> String?
    private let deleteImage: (String) -> Void
    private var solveWorkItem: DispatchWorkItem?
    /// Bumped by every new photo request and every manual edit; results for older tokens are dropped.
    private var requestToken = 0
    private var detectionTask: Task<Void, Never>?
    private var didStartGame = false

    let cellIDs: [UUID]
    private let idToIndex: [UUID: Int]

    init(
        generatorService: SudokuGeneratorService = SudokuGeneratorService(),
        imageDetector: SudokuImageDetector = SudokuImageDetector(),
        createGame: @escaping (String, String?) -> ImportedGame?,
        saveImage: @escaping (UIImage) -> String?,
        deleteImage: @escaping (String) -> Void
    ) {
        self.generatorService = generatorService
        self.imageDetector = imageDetector
        self.createGame = createGame
        self.saveImage = saveImage
        self.deleteImage = deleteImage
        self.gridValues = Array(repeating: nil, count: 81)
        self.cellIDs = (0..<81).map { _ in UUID() }
        var lookup: [UUID: Int] = [:]
        for (index, id) in cellIDs.enumerated() {
            lookup[id] = index
        }
        self.idToIndex = lookup
        validate()
    }

    convenience init(controller: AppController) {
        self.init(
            createGame: { grid, imageID in
                controller.createImportedGame(initialGrid: grid, imageID: imageID)
            },
            saveImage: { image in
                controller.saveImportedImage(image)
            },
            deleteImage: { id in
                controller.removeImportedImage(id: id)
            }
        )
    }

    var canStart: Bool {
        conflictIndices.isEmpty && solvableState == .solvable && filledCount >= minimumClues
    }

    var validationMessage: String {
        if filledCount < minimumClues {
            return "Add at least \(minimumClues) clues to start."
        }
        if !conflictIndices.isEmpty {
            return "Resolve duplicates to continue."
        }
        switch solvableState {
        case .unknown:
            return "Checking if the puzzle is solvable."
        case .solvable:
            return "Puzzle is solvable."
        case .unsolvable:
            return "This puzzle has no solution."
        }
    }

    var step: Step {
        if isDetecting { return .reading }
        return image != nil || isEnteringByHand || filledCount > 0 ? .review : .source
    }

    /// "Two 4s in row 4." for the first house with a repeated digit, or nil.
    func conflictSummary(names: CellNotation) -> String? {
        let words = ["Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        for house in House.all {
            let digits = house.cells.compactMap { gridValues[$0] }
            for digit in 1...9 {
                let count = digits.filter { $0 == digit }.count
                if count >= 2 { return "\(words[count - 2]) \(digit)s in \(names.house(house))." }
            }
        }
        return nil
    }

    /// "Type it in": straight to Check the grid with an empty board.
    func enterByHand() {
        isEnteringByHand = true
    }

    var filledCount: Int {
        gridValues.compactMap { $0 }.count
    }

    private let minimumClues = 10

    /// Tapping a ringed cell confirms it.
    func selectCell(id: UUID) {
        selectedIndex = idToIndex[id]
        if let index = selectedIndex { unsureIndices.remove(index) }
    }

    func setDigit(_ digit: Int) {
        guard (1...9).contains(digit), let index = selectedIndex else { return }
        stopPendingDetection()
        gridValues[index] = digit
        unsureIndices.remove(index)
        validate()
    }

    func clearSelected() {
        guard let index = selectedIndex else { return }
        stopPendingDetection()
        gridValues[index] = nil
        unsureIndices.remove(index)
        validate()
    }

    func loadGrid(_ values: [Int?], unsure: Set<Int> = []) {
        guard values.count == 81 else { return }
        gridValues = values
        unsureIndices = unsure
        validate()
    }

    /// Call before loading a picked photo; pass the token back to `applyPhoto`.
    func beginPhotoRequest() -> Int {
        stopPendingDetection()
        return requestToken
    }

    /// Applies a loaded photo only if no newer photo or manual edit happened meanwhile.
    func applyPhoto(_ image: UIImage, token: Int) {
        guard token == requestToken else { return }
        updateImage(image)
    }

    func updateImage(_ image: UIImage?) {
        stopPendingDetection()
        if let existing = imageID {
            deleteImage(existing)
            imageID = nil
        }
        self.image = image
        detectionMessage = nil
        unsureIndices = []
        guard let image else { return }
        imageID = saveImage(image)
        let token = requestToken
        detectionTask = Task { [weak self] in
            await self?.detectGrid(from: image, token: token)
        }
    }

    func createImportedGame() -> ImportedGame? {
        guard canStart, let game = createGame(gridString(), imageID) else { return nil }
        didStartGame = true
        return game
    }

    /// Called when the import screen closes. Deletes the photo if no game was started from it.
    func discardIfUnused() {
        stopPendingDetection()
        guard !didStartGame, let existing = imageID else { return }
        deleteImage(existing)
        imageID = nil
    }

    private func stopPendingDetection() {
        requestToken += 1
        detectionTask?.cancel()
        detectionTask = nil
        if isDetecting { detectionMessage = nil }
        isDetecting = false
        readProgress = nil
    }

    func displayCells() -> [SudokuCell] {
        gridValues.enumerated().map { index, value in
            SudokuCell(
                id: cellIDs[index],
                row: index / 9,
                col: index % 9,
                given: value != nil, // drawn as givens: that is what they become
                value: value,
                candidates: [],
                isError: conflictIndices.contains(index),
                isRevealed: false
            )
        }
    }

    private func validate() {
        conflictIndices = findConflicts(in: gridValues)
        solvableState = .unknown
        scheduleSolveCheck()
    }

    private func detectGrid(from image: UIImage, token: Int) async {
        isDetecting = true
        readProgress = nil
        detectionMessage = "Detecting grid…"
        let result: Result<SudokuImageDetector.DetectedGrid, Error>
        do {
            result = .success(try await imageDetector.detectGrid(from: image) { [weak self] progress in
                Task { @MainActor in
                    guard let self, token == self.requestToken, self.isDetecting else { return }
                    self.readProgress = progress
                }
            })
        } catch {
            result = .failure(error)
        }
        guard token == requestToken, !Task.isCancelled else { return }
        readProgress = nil
        switch result {
        case let .success(grid):
            loadGrid(grid.values, unsure: grid.unsure)
            detectionMessage = nil
        case .failure:
            detectionMessage = "Could not detect a clear grid. You can fill it manually."
        }
        isDetecting = false
        validate()
    }

    private func scheduleSolveCheck() {
        solveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.conflictIndices.isEmpty {
                self.solvableState = .unsolvable
                return
            }
            let solution = self.generatorService.solve(initialGrid: self.gridString())
            self.solvableState = solution == nil ? .unsolvable : .solvable
        }
        solveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func gridString() -> String {
        gridValues.map { value in
            guard let value else { return "0" }
            return String(value)
        }.joined()
    }

    private func findConflicts(in values: [Int?]) -> Set<Int> {
        Board.conflictingPositions(in: Board.from(digits: values))
    }
}
