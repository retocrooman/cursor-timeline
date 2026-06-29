import Foundation

public enum UsageCSVStore {
    public static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cursor-timeline", isDirectory: true)
    }

    public static var cacheURL: URL {
        cacheDirectory.appendingPathComponent("latest-usage.csv", isDirectory: false)
    }

    /// インポート元を Application Support にコピーして保存
    public static func saveImport(from source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
        }
        try FileManager.default.copyItem(at: source, to: cacheURL)
        return cacheURL
    }

    public static func loadCached() throws -> [UsageRecord]? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        return try UsageCSVReader.load(from: cacheURL)
    }

    public static var cachedFilename: String? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        return cacheURL.lastPathComponent
    }
}
