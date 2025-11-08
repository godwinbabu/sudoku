import Foundation

final class PersistenceManager {
    enum PersistenceError: Error {
        case failedToResolveDirectory
    }

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
        let data = try encoder.encode(value)
        let url = try baseURL().appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
    }

    func load<T: Codable>(_ type: T.Type, from fileName: String) throws -> T? {
        let url = try baseURL().appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    func delete(_ fileName: String) {
        guard let url = try? baseURL().appendingPathComponent(fileName) else { return }
        try? fileManager.removeItem(at: url)
    }
}
