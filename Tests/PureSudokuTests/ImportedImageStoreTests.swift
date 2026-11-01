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
