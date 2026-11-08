import Foundation

final class PersistenceManager {
    enum PersistenceError: Error {
        case failedToResolveDirectory
        case fileProtected(String)
    }

    /// Files that failed to read this session; saving over them is refused.
    private var protectedFiles: Set<String> = []
    /// Files moved aside as unreadable this session (`quarantine`), in order.
    private(set) var setAsideFiles: [String] = []

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let directoryName = "PureSudoku"
    private let overrideDirectory: URL?

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        overrideDirectory = directory
    }

    private func baseURL() throws -> URL {
        if let overrideDirectory {
            if !fileManager.fileExists(atPath: overrideDirectory.path) {
                try fileManager.createDirectory(at: overrideDirectory, withIntermediateDirectories: true)
            }
            return overrideDirectory
        }

        guard let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.failedToResolveDirectory
        }
        let directory = url.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    func save<T: Codable>(_ value: T, to fileName: String) throws {
        guard !protectedFiles.contains(fileName) else { throw PersistenceError.fileProtected(fileName) }
        let data = try encoder.encode(value)
        let url = try baseURL().appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
    }

    /// Loads a file. A file that cannot be read is protected from being overwritten this session.
    /// A file that reads but cannot be decoded is moved aside as `name.corrupt-<time>.json`, so the
    /// app can start fresh without destroying the old data.
    func load<T: Codable>(_ type: T.Type, from fileName: String) throws -> T? {
        let url = try baseURL().appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            protectedFiles.insert(fileName)
            throw error
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            quarantine(url, fileName: fileName)
            throw error
        }
    }

    private func quarantine(_ url: URL, fileName: String) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let base = url.deletingPathExtension().lastPathComponent
        var backup = url.deletingLastPathComponent().appendingPathComponent("\(base).corrupt-\(stamp).json")
        var suffix = 1
        while fileManager.fileExists(atPath: backup.path) {
            backup = url.deletingLastPathComponent().appendingPathComponent("\(base).corrupt-\(stamp)-\(suffix).json")
            suffix += 1
        }
        do {
            try fileManager.moveItem(at: url, to: backup)
            setAsideFiles.append(fileName)
        } catch {
            protectedFiles.insert(fileName)
        }
    }

    /// True while a copy of `fileName` set aside by `load` (`name.corrupt-<time>.json`) is on disk:
    /// the data may still be restored, even on a later launch where the file itself is missing.
    func hasSetAsideCopy(of fileName: String) -> Bool {
        guard let directory = try? baseURL(),
              let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return false }
        let prefix = (fileName as NSString).deletingPathExtension + ".corrupt-"
        return names.contains { $0.hasPrefix(prefix) }
    }

    func delete(_ fileName: String) {
        guard let url = try? baseURL().appendingPathComponent(fileName) else { return }
        try? fileManager.removeItem(at: url)
    }
}
