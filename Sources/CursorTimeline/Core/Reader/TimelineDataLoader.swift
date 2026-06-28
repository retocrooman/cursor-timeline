import Foundation

public struct TimelineDataLoader: Sendable {
    public let paths: CursorPaths
    private let databaseReader: CursorDatabaseReader
    private let transcriptReader: AgentTranscriptReader

    public init(paths: CursorPaths = CursorPaths()) {
        self.paths = paths
        self.databaseReader = CursorDatabaseReader(paths: paths)
        self.transcriptReader = AgentTranscriptReader(paths: paths)
    }

    public func fetchUserBubbles(composerIds: [String]) throws -> [RawUserBubble] {
        try databaseReader.fetchUserBubbles(composerIds: composerIds)
    }

    /// ADR-016 段1–3: index 全件 + 指定 ID の bubble / transcript（一括ロード用）
    public func loadSessions(
        composerIdsForBubbles: [String],
        includeAllTranscripts: Bool = false
    ) throws -> [TimelineSession] {
        let index = try fetchSessionIndex()
        let bubbles = try fetchUserBubbles(composerIds: composerIdsForBubbles)

        let composerIDs = Set(composerIdsForBubbles)
        let transcripts: [AgentTranscriptSession]
        if includeAllTranscripts {
            transcripts = try transcriptReader.fetchAllSessions()
        } else {
            transcripts = try transcriptReader.fetchSessions(for: composerIDs)
        }

        return TimelineSessionBuilder.build(index: index, bubbles: bubbles, transcripts: transcripts)
    }

    public func fetchSessionIndex() throws -> [SessionMeta] {
        try databaseReader.fetchSessionIndex()
    }
}
