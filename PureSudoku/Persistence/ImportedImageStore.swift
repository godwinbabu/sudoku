import Foundation
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

    private func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
