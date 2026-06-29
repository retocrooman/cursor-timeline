import Foundation

public enum UsageCSVReader {
    public static func load(from url: URL) throws -> [UsageRecord] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(text: text)
    }

    public static func parse(text: String) throws -> [UsageRecord] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerLine = lines.first else { return [] }

        let headers = parseCSVRow(headerLine)
        guard headers.first == "Date" else {
            throw UsageCSVError.invalidHeader
        }

        var records: [UsageRecord] = []
        records.reserveCapacity(lines.count - 1)

        for (offset, line) in lines.dropFirst().enumerated() {
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let fields = parseCSVRow(line)
            guard fields.count >= headers.count else { continue }
            let row = Dictionary(uniqueKeysWithValues: zip(headers, fields))

            guard let dateString = row["Date"],
                  let timestamp = parseISO8601(dateString) else {
                continue
            }

            let cost = parseCost(row["Cost"])
            let tokens = Int(row["Total Tokens"] ?? "") ?? 0

            records.append(
                UsageRecord(
                    id: "csv-\(offset)",
                    timestamp: timestamp,
                    user: row["User"] ?? "",
                    model: row["Model"] ?? "",
                    kind: row["Kind"] ?? "",
                    costUSD: cost,
                    totalTokens: tokens
                )
            )
        }

        return records.sorted { $0.timestamp < $1.timestamp }
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func parseCost(_ raw: String?) -> Decimal {
        guard let raw else { return 0 }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "Free" { return 0 }
        return Decimal(string: trimmed) ?? 0
    }

    /// 引用符付き CSV 1 行をパース
    private static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }
}

public enum UsageCSVError: Error, Equatable {
    case invalidHeader
    case fileNotFound
}
