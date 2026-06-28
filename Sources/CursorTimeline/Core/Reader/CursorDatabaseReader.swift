import Foundation
import GRDB

public struct CursorDatabaseReader: Sendable {
    public let paths: CursorPaths

    public init(paths: CursorPaths = CursorPaths()) {
        self.paths = paths
    }

    public func fetchSessionIndex() throws -> [SessionMeta] {
        let dbQueue = try DatabaseConnection.openGlobalDatabase(at: paths.globalDatabase)
        return try dbQueue.read { db in
            var metas = try Self.loadHeadersIndex(db: db)
            let knownIDs = Set(metas.map(\.id))
            let orphans = try Self.loadOrphanComposerData(db: db, excluding: knownIDs)
            metas.append(contentsOf: orphans)
            return metas.sorted { $0.startAt > $1.startAt }
        }
    }

    public func fetchUserBubbles(composerIds: [String]) throws -> [RawUserBubble] {
        guard !composerIds.isEmpty else { return [] }

        let dbQueue = try DatabaseConnection.openGlobalDatabase(at: paths.globalDatabase)
        return try dbQueue.read { db in
            var results: [RawUserBubble] = []
            results.reserveCapacity(composerIds.count * 4)

            for composerId in composerIds {
                let prefix = "bubbleId:\(composerId):"
                let rows = try Row.fetchAll(
                    db,
                    sql: "SELECT key, value FROM cursorDiskKV WHERE key LIKE ? ESCAPE '\\'",
                    arguments: ["\(prefix)%"]
                )

                for row in rows {
                    guard let key: String = row["key"],
                          let data = Self.data(from: row) else { continue }
                    let dict = try CursorJSON.dictionary(from: data)
                    guard Self.isUserBubble(dict) else { continue }

                    let bubbleId = key.split(separator: ":").last.map(String.init) ?? key
                    let text = Self.extractText(from: dict)
                    guard !text.isEmpty else { continue }

                    results.append(
                        RawUserBubble(
                            composerId: composerId,
                            bubbleId: bubbleId,
                            createdAt: CursorDateParser.date(from: dict["createdAt"]),
                            text: text,
                            modelRaw: Self.extractModelRaw(from: dict)
                        )
                    )
                }
            }

            return results
        }
    }

    private static func loadHeadersIndex(db: Database) throws -> [SessionMeta] {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT value FROM ItemTable WHERE key = ?",
            arguments: ["composer.composerHeaders"]
        ), let data = data(from: row) else {
            return []
        }

        let root = try CursorJSON.dictionary(from: data)
        guard let composers = root["allComposers"] as? [[String: Any]] else {
            return []
        }

        return composers.compactMap { entry in
            guard let composerId = entry["composerId"] as? String else { return nil }
            return makeSessionMeta(
                composerId: composerId,
                name: entry["name"] as? String,
                createdAt: CursorDateParser.date(from: entry["createdAt"]),
                lastUpdatedAt: CursorDateParser.date(from: entry["lastUpdatedAt"]),
                workspacePath: workspacePath(from: entry),
                messageCount: 0,
                source: .composer
            )
        }
    }

    private static func loadOrphanComposerData(
        db: Database,
        excluding knownIDs: Set<String>
    ) throws -> [SessionMeta] {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT key FROM cursorDiskKV WHERE key LIKE 'composerData:%'"
        )

        var orphans: [SessionMeta] = []
        orphans.reserveCapacity(32)

        for row in rows {
            guard let key: String = row["key"] else { continue }
            let composerId = String(key.dropFirst("composerData:".count))
            guard !knownIDs.contains(composerId) else { continue }

            guard let valueRow = try Row.fetchOne(
                db,
                sql: "SELECT value FROM cursorDiskKV WHERE key = ?",
                arguments: [key]
            ), let data = data(from: valueRow) else { continue }

            let dict = try CursorJSON.dictionary(from: data)
            let headers = dict["fullConversationHeadersOnly"] as? [[String: Any]]
            orphans.append(
                makeSessionMeta(
                    composerId: composerId,
                    name: dict["name"] as? String,
                    createdAt: CursorDateParser.date(from: dict["createdAt"]),
                    lastUpdatedAt: CursorDateParser.date(from: dict["createdAt"]),
                    workspacePath: nil,
                    messageCount: headers?.count ?? 0,
                    source: .composer
                )
            )
        }

        return orphans
    }

    private static func makeSessionMeta(
        composerId: String,
        name: String?,
        createdAt: Date?,
        lastUpdatedAt: Date?,
        workspacePath: String?,
        messageCount: Int,
        source: SessionSource
    ) -> SessionMeta {
        let repo = RepoResolver.resolve(workspacePath: workspacePath)
        let start = createdAt ?? lastUpdatedAt ?? .distantPast
        let end = lastUpdatedAt ?? createdAt ?? start
        let title = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Untitled"

        return SessionMeta(
            id: composerId,
            repoId: repo.repoId,
            repoLabel: repo.repoLabel,
            title: title,
            startAt: start,
            endAt: end,
            messageCount: messageCount,
            source: source
        )
    }

    private static func workspacePath(from entry: [String: Any]) -> String? {
        guard let workspace = entry["workspaceIdentifier"] as? [String: Any] else { return nil }
        if let uri = workspace["uri"] as? [String: Any],
           let fsPath = uri["fsPath"] as? String,
           !fsPath.isEmpty {
            return fsPath
        }
        if let id = workspace["id"] as? String, !id.isEmpty {
            return id
        }
        return nil
    }

    private static func data(from row: Row) -> Data? {
        if let data: Data = row["value"] { return data }
        if let string: String = row["value"] { return Data(string.utf8) }
        return nil
    }

    private static func isUserBubble(_ dict: [String: Any]) -> Bool {
        if let type = dict["type"] as? Int { return type == 1 }
        if let type = dict["type"] as? Double { return Int(type) == 1 }
        if let type = dict["type"] as? String, let intType = Int(type) { return intType == 1 }
        return false
    }

    private static func extractText(from dict: [String: Any]) -> String {
        for key in ["text", "rawText", "richText"] {
            if let text = dict[key] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    private static func extractModelRaw(from dict: [String: Any]) -> String? {
        if let modelInfo = dict["modelInfo"] as? [String: Any],
           let modelName = modelInfo["modelName"] as? String,
           !modelName.isEmpty {
            return modelName
        }
        if let modelType = dict["modelType"] as? String, !modelType.isEmpty {
            return modelType
        }
        if let model = dict["model"] as? String, !model.isEmpty {
            return model
        }
        return nil
    }
}
