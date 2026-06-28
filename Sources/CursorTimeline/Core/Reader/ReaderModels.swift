import Foundation

public struct RawUserBubble: Sendable, Equatable {
    public let composerId: String
    public let bubbleId: String
    public let createdAt: Date?
    public let text: String
    public let modelRaw: String?

    public init(
        composerId: String,
        bubbleId: String,
        createdAt: Date?,
        text: String,
        modelRaw: String?
    ) {
        self.composerId = composerId
        self.bubbleId = bubbleId
        self.createdAt = createdAt
        self.text = text
        self.modelRaw = modelRaw
    }
}

public struct AgentTranscriptMessage: Sendable, Equatable {
    public let lineIndex: Int
    public let text: String

    public init(lineIndex: Int, text: String) {
        self.lineIndex = lineIndex
        self.text = text
    }
}

public struct AgentTranscriptSession: Sendable, Equatable {
    public let composerId: String
    public let projectSlug: String
    public let fileURL: URL
    public let fileModifiedAt: Date
    public let userMessages: [AgentTranscriptMessage]

    public init(
        composerId: String,
        projectSlug: String,
        fileURL: URL,
        fileModifiedAt: Date,
        userMessages: [AgentTranscriptMessage]
    ) {
        self.composerId = composerId
        self.projectSlug = projectSlug
        self.fileURL = fileURL
        self.fileModifiedAt = fileModifiedAt
        self.userMessages = userMessages
    }
}
