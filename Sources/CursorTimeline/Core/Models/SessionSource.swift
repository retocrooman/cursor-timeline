import Foundation

public enum SessionSource: String, Codable, Sendable, Equatable {
    case composer
    case agentTranscript
    case merged
}
