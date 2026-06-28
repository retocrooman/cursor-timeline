import Foundation

public protocol TimelineLoading: Sendable {
    func fetchSessionIndex() throws -> [SessionMeta]
    func fetchUserBubbles(composerIds: [String]) throws -> [RawUserBubble]
    func fetchTranscripts(for composerIds: Set<String>) throws -> [AgentTranscriptSession]
}

extension TimelineDataLoader: TimelineLoading {
    public func fetchTranscripts(for composerIds: Set<String>) throws -> [AgentTranscriptSession] {
        try AgentTranscriptReader(paths: paths).fetchSessions(for: composerIds)
    }
}

public enum TimelineSessionBuilder {
    public static func build(
        index: [SessionMeta],
        bubbles: [RawUserBubble],
        transcripts: [AgentTranscriptSession]
    ) -> [TimelineSession] {
        let merged = TimelineMerger.merge(index: index, bubbles: bubbles, transcripts: transcripts)
        return SessionVisibility.filterDisplayable(merged)
    }
}
