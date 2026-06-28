import Foundation

public struct ThreeDayWindow: Equatable, Sendable {
    /// 表示 3 日の先頭日 00:00（ローカル）
    public var start: Date

    public init(start: Date) {
        self.start = start
    }

    /// 右端（index 2）が「今日」になる初期ウィンドウ（一昨日・昨日・今日）
    public static func today(
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> ThreeDayWindow {
        let startOfToday = calendar.startOfDay(for: now)
        guard let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: startOfToday) else {
            return ThreeDayWindow(start: startOfToday)
        }
        return ThreeDayWindow(start: dayBeforeYesterday)
    }

    public var days: [Date] {
        let calendar = Calendar.current
        return (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// 今日は常に右端（index 2）— `today()` 基準の相対位置
    public static let todayIndex = 2

    public mutating func goPrev(calendar: Calendar = .current) {
        guard let newStart = calendar.date(byAdding: .day, value: -3, to: start) else { return }
        start = newStart
    }

    public mutating func goNext(calendar: Calendar = .current) {
        guard let newStart = calendar.date(byAdding: .day, value: 3, to: start) else { return }
        start = newStart
    }

    public mutating func goToday(calendar: Calendar = .current, now: Date = Date()) {
        self = Self.today(calendar: calendar, now: now)
    }

    /// セッション [startAt, endAt] がこの 3 日ウィンドウと時間的に重なるか
    public func overlaps(
        sessionStart: Date,
        sessionEnd: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let firstDay = days.first, let lastDay = days.last else { return false }
        let windowStart = calendar.startOfDay(for: firstDay)
        guard let windowEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay)) else {
            return false
        }
        return sessionStart < windowEnd && sessionEnd > windowStart
    }

    public func contains(day: Date, calendar: Calendar = .current) -> Bool {
        days.contains { calendar.isDate($0, inSameDayAs: day) }
    }
}
