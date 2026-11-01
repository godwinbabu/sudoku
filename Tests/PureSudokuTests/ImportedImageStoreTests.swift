import XCTest
import UIKit
@testable import PureSudoku

final class ImportedImageStoreTests: XCTestCase {
    func testCleanupKeepsMostRecentImages() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ImportedImageStore(directory: directory, maxImages: 2, maxDimension: 32, compressionQuality: 0.8)

        let image = makeImage(color: .red)
        _ = store.save(image: image)
        _ = store.save(image: image)
        _ = store.save(image: image)

        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        XCTAssertEqual(files.count, 2)
    }

    private func makeImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }
}

@MainActor
final class ImportImageLifecycleTests: XCTestCase {
    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    private func imageExists(_ id: String, in dir: URL) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent("ImportedImages/\(id).jpg").path)
    }

    func testEveryImportKeepsItsImage() throws {
        let (controller, dir) = makeTestController()
        let first = try XCTUnwrap(controller.saveImportedImage(image()))
        XCTAssertNotNil(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid, imageID: first))
        let second = try XCTUnwrap(controller.saveImportedImage(image()))
        XCTAssertTrue(imageExists(second, in: dir), "pending image must survive cleanup")
        XCTAssertNotNil(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid, imageID: second))
        XCTAssertTrue(imageExists(first, in: dir))
        XCTAssertTrue(imageExists(second, in: dir))
    }

    func testDeletingImportedGameRemovesItsImage() throws {
        let (controller, dir) = makeTestController()
        let id = try XCTUnwrap(controller.saveImportedImage(image()))
        let game = try XCTUnwrap(controller.createImportedGame(initialGrid: TestData.puzzle.initialGrid, imageID: id))
        XCTAssertEqual(controller.savedImports.map(\.id), [game.id])
        controller.deleteImportedGame(id: game.id)
        XCTAssertTrue(controller.savedImports.isEmpty)
        XCTAssertFalse(imageExists(id, in: dir))
    }

    func testDiscardedImportScreenDeletesItsImage() throws {
        let (controller, dir) = makeTestController()
        let viewModel = ImportPuzzleViewModel(controller: controller)
        viewModel.updateImage(image())
        let id = try XCTUnwrap(viewModel.imageID)
        XCTAssertTrue(imageExists(id, in: dir))
        viewModel.discardIfUnused()
        XCTAssertFalse(imageExists(id, in: dir))
    }

    func testStalePhotoIsIgnoredAfterManualEdit() {
        let (controller, _) = makeTestController()
        let viewModel = ImportPuzzleViewModel(controller: controller)
        let token = viewModel.beginPhotoRequest()
        viewModel.selectedIndex = 0
        viewModel.setDigit(5)
        viewModel.applyPhoto(image(), token: token)
        XCTAssertNil(viewModel.image)
        XCTAssertEqual(viewModel.gridValues[0], 5)
    }
}

final class ImageOrientationTests: XCTestCase {
    func testSidewaysPhotoIsRedrawnUpright() throws {
        // A 40x20 bitmap flagged "rotate right", like an iPhone portrait photo.
        let raw = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
        let sideways = UIImage(cgImage: try XCTUnwrap(raw.cgImage), scale: raw.scale, orientation: .right)
        XCTAssertEqual(sideways.size, CGSize(width: 20, height: 40))

        let upright = SudokuImageDetector.upright(sideways)
        let cg = try XCTUnwrap(upright.cgImage)
        XCTAssertEqual(upright.imageOrientation, .up)
        XCTAssertLessThan(cg.width, cg.height, "pixels must now be portrait")
    }
}

final class ImageResizeTests: XCTestCase {
    func testResizeCapsPixelsNotPoints() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 4032, height: 3024), format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4032, height: 3024))
        }
        let store = ImportedImageStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let resized = store.resize(image: big, maxDimension: 2048)
        let cg = try XCTUnwrap(resized.cgImage)
        XCTAssertEqual(cg.width, 2048)
        XCTAssertEqual(cg.height, 1536)
    }
}
