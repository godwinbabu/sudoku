import Foundation
import UIKit

@MainActor
final class ImportPuzzleViewModel: ObservableObject {
    enum SolvableState: Equatable {
        case unknown
        case solvable
        case unsolvable
    }

    @Published private(set) var gridValues: [Int?]
    @Published private(set) var conflictIndices: Set<Int> = []
    @Published private(set) var solvableState: SolvableState = .unknown
    @Published var selectedIndex: Int?
    @Published private(set) var image: UIImage?
    @Published private(set) var imageID: String?
    @Published private(set) var detectionMessage: String?
    @Published private(set) var isDetecting: Bool = false

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

    var filledCount: Int {
        gridValues.compactMap { $0 }.count
    }

    private let minimumClues = 10

    func selectCell(id: UUID) {
        selectedIndex = idToIndex[id]
    }

    func setDigit(_ digit: Int) {
        guard (1...9).contains(digit), let index = selectedIndex else { return }
        stopPendingDetection()
        gridValues[index] = digit
        validate()
    }

    func clearSelected() {
        guard let index = selectedIndex else { return }
        stopPendingDetection()
        gridValues[index] = nil
        validate()
    }

    func clearAll() {
        stopPendingDetection()
        gridValues = Array(repeating: nil, count: 81)
        validate()
    }

    func loadGrid(_ values: [Int?]) {
        guard values.count == 81 else { return }
        gridValues = values
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
        isDetecting = false
    }

    func displayCells() -> [SudokuCell] {
        gridValues.enumerated().map { index, value in
            SudokuCell(
                id: cellIDs[index],
                row: index / 9,
                col: index % 9,
                given: false,
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
        detectionMessage = "Detecting grid…"
        let result: Result<[Int?], Error>
        do {
            result = .success(try await imageDetector.detectGrid(from: image))
        } catch {
            result = .failure(error)
        }
        guard token == requestToken, !Task.isCancelled else { return }
        switch result {
        case let .success(values):
            gridValues = values
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
        var conflicts: Set<Int> = []
        for row in 0..<9 {
            conflicts.formUnion(conflictsIn(indices: (0..<9).map { row * 9 + $0 }, values: values))
        }
        for col in 0..<9 {
            conflicts.formUnion(conflictsIn(indices: (0..<9).map { $0 * 9 + col }, values: values))
        }
        for boxRow in 0..<3 {
            for boxCol in 0..<3 {
                let startRow = boxRow * 3
                let startCol = boxCol * 3
                let indices = (0..<9).map { offset -> Int in
                    let r = startRow + offset / 3
                    let c = startCol + offset % 3
                    return r * 9 + c
                }
                conflicts.formUnion(conflictsIn(indices: indices, values: values))
            }
        }
        return conflicts
    }

    private func conflictsIn(indices: [Int], values: [Int?]) -> Set<Int> {
        var seen: [Int: Int] = [:]
        var conflicts: Set<Int> = []
        for index in indices {
            guard let value = values[index] else { continue }
            if let first = seen[value] {
                conflicts.insert(first)
                conflicts.insert(index)
            } else {
                seen[value] = index
            }
        }
        return conflicts
    }
}
