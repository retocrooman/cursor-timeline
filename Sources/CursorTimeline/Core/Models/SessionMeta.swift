import Foundation

/// ADR-016 段1: bubble 本文なしの軽量インデックス
public struct SessionMeta: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let repoId: String
    public let repoLabel: String
    public let title: String
    public let startAt: Date
    public let endAt: Date
    public let messageCount: Int
    public let source: SessionSource

    public init(
        id: String,
        repoId: String,
        repoLabel: String,
        title: String,
        startAt: Date,
        endAt: Date,
        messageCount: Int,
        source: SessionSource
    ) {
        self.id = id
        self.repoId = repoId
        self.repoLabel = repoLabel
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.messageCount = messageCount
        self.source = source
    }
}
