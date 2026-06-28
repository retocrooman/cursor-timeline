import Foundation

public struct PromptEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let sessionId: String
    public let timestamp: Date
    public let text: String
    public let model: ModelFamily
    public let confidence: TimestampConfidence

    public init(
        id: String,
        sessionId: String,
        timestamp: Date,
        text: String,
        model: ModelFamily,
        confidence: TimestampConfidence
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.text = text
        self.model = model
        self.confidence = confidence
    }
}
