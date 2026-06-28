import Foundation

enum CursorJSON {
    static func dictionary(from data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw CursorReaderError.invalidJSON
        }
        return dictionary
    }

    static func data(fromRowValue value: (any Sendable)?) -> Data? {
        if let data = value as? Data { return data }
        if let string = value as? String { return Data(string.utf8) }
        return nil
    }
}

enum CursorDateParser {
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: Any?) -> Date? {
        switch value {
        case let number as Double:
            return date(fromMilliseconds: number)
        case let number as Int:
            return date(fromMilliseconds: Double(number))
        case let number as Int64:
            return date(fromMilliseconds: Double(number))
        case let string as String:
            if let parsed = iso8601Fractional.date(from: string) ?? iso8601.date(from: string) {
                return parsed
            }
            if let ms = Double(string) {
                return date(fromMilliseconds: ms)
            }
            return nil
        default:
            return nil
        }
    }

    static func date(fromMilliseconds ms: Double) -> Date {
        let seconds = ms > 1_000_000_000_000 ? ms / 1000 : ms
        return Date(timeIntervalSince1970: seconds)
    }
}

public enum CursorReaderError: Error, Equatable {
    case databaseNotFound
    case openFailed
    case invalidJSON
}

extension CursorReaderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Cursor のデータベースが見つかりません。Cursor を一度起動してから、再読み込み（↻）してください。"
        case .openFailed:
            return "データベースを開けませんでした。Cursor を終了してから再度お試しください。"
        case .invalidJSON:
            return "Cursor のデータ形式を読み取れませんでした。"
        }
    }
}
