import Foundation

/// 日付列の縦軸（08:00 開始）。`date` が隣日でも列の `day` 基準で位置を返す。
public enum TimelineAxis {
    public static let hourStart = 8
    /// 22:47 など深夜手前のセッションも収める（DESIGN 08–22 の拡張）
    public static let hourEnd = 23

    public static var slotCount: Int { hourEnd - hourStart }

    public static func minutesFromVisibleStart(
        of date: Date,
        onDay day: Date,
        calendar: Calendar = .current
    ) -> Double {
        let dayStart = calendar.startOfDay(for: day)
        guard let anchor = calendar.date(
            bySettingHour: hourStart,
            minute: 0,
            second: 0,
            of: dayStart
        ) else { return 0 }

        let minutes = date.timeIntervalSince(anchor) / 60
        let visibleMinutes = Double(slotCount * 60)
        return max(0, min(minutes, visibleMinutes))
    }
}
