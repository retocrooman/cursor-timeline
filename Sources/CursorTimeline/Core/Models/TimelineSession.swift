import Foundation

public struct TimelineSession: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let repoId: String
    public let repoLabel: String
    public let title: String
    public let startAt: Date
    public let endAt: Date
    public let source: SessionSource
    public let prompts: [PromptEvent]

    public init(
        id: String,
        repoId: String,
        repoLabel: String,
        title: String,
        startAt: Date,
        endAt: Date,
        source: SessionSource,
        prompts: [PromptEvent]
    ) {
        self.id = id
        self.repoId = repoId
        self.repoLabel = repoLabel
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.source = source
        self.prompts = prompts
    }
}
