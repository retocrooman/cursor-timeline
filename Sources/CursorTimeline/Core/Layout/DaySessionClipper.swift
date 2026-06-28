import Foundation

public struct DaySessionClip: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum DaySessionClipper {
    /// セッション [start, end] と日付列の交差部分。日跨ぎは列ごとに切る（DESIGN §7）。
    public static func clip(
        sessionStart: Date,
        sessionEnd: Date,
        on day: Date,
        calendar: Calendar = .current
    ) -> DaySessionClip? {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        let start = max(sessionStart, dayStart)
        let end = min(sessionEnd, dayEnd)
        guard start < end else { return nil }

        return DaySessionClip(start: start, end: end)
    }

    public static func overlaps(
        sessionStart: Date,
        sessionEnd: Date,
        on day: Date,
        calendar: Calendar = .current
    ) -> Bool {
        clip(sessionStart: sessionStart, sessionEnd: sessionEnd, on: day, calendar: calendar) != nil
    }

    public static func prompts(
        _ prompts: [PromptEvent],
        on day: Date,
        calendar: Calendar = .current
    ) -> [PromptEvent] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return prompts.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
    }

    /// 列内クリップ区間 [clip.start, clip.end) に含まれるプロンプトのみ（ドット整合用）
    public static func prompts(
        _ prompts: [PromptEvent],
        within clip: DaySessionClip
    ) -> [PromptEvent] {
        prompts.filter { $0.timestamp >= clip.start && $0.timestamp < clip.end }
    }
}
