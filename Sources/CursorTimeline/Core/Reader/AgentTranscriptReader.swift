import Foundation

public struct AgentTranscriptReader: Sendable {
    public let paths: CursorPaths

    public init(paths: CursorPaths = CursorPaths()) {
        self.paths = paths
    }

    public func fetchSessions(for composerIds: Set<String>) throws -> [AgentTranscriptSession] {
        guard !composerIds.isEmpty else { return [] }
        let files = try discoverTranscriptFiles()
        var sessions: [AgentTranscriptSession] = []
        sessions.reserveCapacity(composerIds.count)

        for fileURL in files {
            let composerId = fileURL.deletingPathExtension().lastPathComponent
            guard composerIds.contains(composerId) else { continue }
            if let session = try loadSession(fileURL: fileURL, composerId: composerId) {
                sessions.append(session)
            }
        }

        return sessions
    }

    public func fetchAllSessions() throws -> [AgentTranscriptSession] {
        let files = try discoverTranscriptFiles()
        var sessions: [AgentTranscriptSession] = []
        sessions.reserveCapacity(files.count)

        for fileURL in files {
            let composerId = fileURL.deletingPathExtension().lastPathComponent
            if let session = try loadSession(fileURL: fileURL, composerId: composerId) {
                sessions.append(session)
            }
        }

        return sessions
    }

    private func discoverTranscriptFiles() throws -> [URL] {
        let root = paths.agentTranscriptsRoot
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            if url.pathComponents.contains("subagents") { continue }
            guard url.pathExtension == "jsonl" else { continue }
            guard url.lastPathComponent == "\(url.deletingPathExtension().lastPathComponent).jsonl" else { continue }
            files.append(url)
        }
        return files
    }

    private func loadSession(fileURL: URL, composerId: String) throws -> AgentTranscriptSession? {
        let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
        let modifiedAt = values.contentModificationDate ?? .distantPast
        let projectSlug = projectSlug(from: fileURL)

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        var messages: [AgentTranscriptMessage] = []

        for (index, line) in content.split(whereSeparator: \.isNewline).enumerated() {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["role"] as? String == "user" else { continue }

            let text = extractUserText(from: object)
            guard !text.isEmpty else { continue }
            messages.append(AgentTranscriptMessage(lineIndex: index, text: text))
        }

        guard !messages.isEmpty else { return nil }

        return AgentTranscriptSession(
            composerId: composerId,
            projectSlug: projectSlug,
            fileURL: fileURL,
            fileModifiedAt: modifiedAt,
            userMessages: messages
        )
    }

    private func projectSlug(from fileURL: URL) -> String {
        let components = fileURL.pathComponents
        if let index = components.firstIndex(of: "projects"), index + 1 < components.count {
            return components[index + 1]
        }
        return fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
    }

    private func extractUserText(from object: [String: Any]) -> String {
        guard let message = object["message"] as? [String: Any] else { return "" }

        if let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let blocks = message["content"] as? [[String: Any]] {
            let texts = blocks.compactMap { block -> String? in
                guard let text = block["text"] as? String else { return nil }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return texts.joined(separator: "\n")
        }

        return ""
    }
}
