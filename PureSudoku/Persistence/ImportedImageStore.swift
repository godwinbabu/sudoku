import Foundation
import OSLog
import UIKit

final class ImportedImageStore {
    private let fileManager: FileManager
    private let baseURL: URL
    private let maxImages: Int
    private let maxDimension: CGFloat
    private let compressionQuality: CGFloat

    init(
        fileManager: FileManager = .default,
        directory: URL? = nil,
        maxImages: Int = 50,
        maxDimension: CGFloat = 2048,
        compressionQuality: CGFloat = 0.7
    ) {
        self.fileManager = fileManager
        self.maxImages = maxImages
        self.maxDimension = maxDimension
        self.compressionQuality = compressionQuality
        self.baseURL = directory ?? ImportedImageStore.defaultDirectory(using: fileManager)
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        excludeFromBackup()
    }

    /// Import photos stay on this iPhone: keep them out of iCloud and computer backups. Set on every
    /// open, so installs from before it are covered. This does not remove earlier backups.
    private func excludeFromBackup() {
        var url = baseURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        do {
            try url.setResourceValues(values)
        } catch {
            Logger().error("Could not exclude imported images from backup: \(error.localizedDescription)")
        }
    }

    func save(image: UIImage) -> String? {
        let resized = resize(image: image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else { return nil }
        let id = UUID().uuidString
        let url = baseURL.appendingPathComponent("\(id).jpg")
        do {
            try data.write(to: url, options: .atomic)
            evictOldest()
            return id
        } catch {
            return nil
        }
    }

    func delete(id: String) {
        let url = baseURL.appendingPathComponent("\(id).jpg")
        try? fileManager.removeItem(at: url)
    }

    func clearAll() {
        guard let files = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else { return }
        for url in files {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Deletes every image whose ID is not in `ids` (BYOS: remove orphaned images).
    func removeOrphans(keeping ids: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil) else { return }
        for url in files where !ids.contains(url.deletingPathExtension().lastPathComponent) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Keeps only the newest `maxImages` images (BYOS: delete oldest beyond the limit).
    func evictOldest() {
        let files = (try? fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let sorted = files.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return leftDate > rightDate
        }
        if sorted.count > maxImages {
            for url in sorted.suffix(from: maxImages) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private static func defaultDirectory(using fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("PureSudoku", isDirectory: true)
            .appendingPathComponent("ImportedImages", isDirectory: true)
    }

    /// Downscales so the longest side is at most `maxDimension` pixels (BYOS: 2048 px cap).
    func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let maxSide = max(pixelSize.width, pixelSize.height)
        guard maxSide > maxDimension else { return image }
        let factor = maxDimension / maxSide
        let newSize = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // size is in pixels; the default would multiply by the screen scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
