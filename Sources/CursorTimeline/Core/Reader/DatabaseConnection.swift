import Foundation
import GRDB

enum DatabaseConnection {
    static func openReadonly(at url: URL) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.readonly = true
        return try DatabaseQueue(path: url.path, configuration: configuration)
    }

    static func openGlobalDatabase(at url: URL) throws -> DatabaseQueue {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CursorReaderError.databaseNotFound
        }

        do {
            return try openReadonly(at: url)
        } catch {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cursor-timeline-\(UUID().uuidString).vscdb")
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.copyItem(at: url, to: tempURL)
            return try openReadonly(at: tempURL)
        }
    }
}
