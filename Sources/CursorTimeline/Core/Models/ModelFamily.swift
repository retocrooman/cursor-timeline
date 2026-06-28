import Foundation

public enum ModelFamily: String, CaseIterable, Codable, Sendable, Equatable {
    case opus
    case sonnet
    case composer
    case gpt
    case other
}
