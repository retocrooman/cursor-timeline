import Foundation
import CoreGraphics
import CursorTimelineCore

public enum TimelineMetrics {
    public static let hourStart = TimelineAxis.hourStart
    public static let hourEnd = TimelineAxis.hourEnd
    public static let hourHeight: CGFloat = 52
    public static let dayColumnMinWidth: CGFloat = 280
    public static let gutterWidth: CGFloat = 56
    static let dotSize: CGFloat = 7
    static let minBlockHeight: CGFloat = 28
    static let maxSessionWidthFraction: CGFloat = 0.5
    static let blockHorizontalPadding: CGFloat = 4

    static var timelineHeight: CGFloat {
        CGFloat(TimelineAxis.slotCount) * hourHeight
    }

    static func yPosition(for date: Date, onDay day: Date, calendar: Calendar = .current) -> CGFloat {
        CGFloat(TimelineAxis.minutesFromVisibleStart(of: date, onDay: day, calendar: calendar) / 60)
            * hourHeight
    }

    static func blockHeight(start: Date, end: Date, onDay day: Date, calendar: Calendar = .current) -> CGFloat {
        max(yPosition(for: end, onDay: day, calendar: calendar) - yPosition(for: start, onDay: day, calendar: calendar), minBlockHeight)
    }

    static func sessions(on day: Date, in sessions: [TimelineSession], calendar: Calendar = .current) -> [TimelineSession] {
        sessions.filter { session in
            DaySessionClipper.overlaps(
                sessionStart: session.startAt,
                sessionEnd: session.endAt,
                on: day,
                calendar: calendar
            )
        }
    }

    static func blockWidth(columnWidth: CGFloat, placement: OverlapPlacement) -> CGFloat {
        let columnCount = CGFloat(max(placement.totalColumns, 1))
        let slotWidth = columnWidth / columnCount
        let maxWidth = columnWidth * maxSessionWidthFraction
        return max(min(slotWidth, maxWidth) - blockHorizontalPadding, 40)
    }

    static func blockXOffset(columnWidth: CGFloat, placement: OverlapPlacement) -> CGFloat {
        let columnCount = CGFloat(max(placement.totalColumns, 1))
        return columnWidth * CGFloat(placement.column) / columnCount + 2
    }

    static func overlapIntervals(
        for sessions: [TimelineSession],
        on day: Date,
        calendar: Calendar = .current
    ) -> [OverlapLayout.SessionInterval] {
        sessions.compactMap { session in
            guard let clip = DaySessionClipper.clip(
                sessionStart: session.startAt,
                sessionEnd: session.endAt,
                on: day,
                calendar: calendar
            ) else { return nil }

            return OverlapLayout.SessionInterval(id: session.id, start: clip.start, end: clip.end)
        }
    }
}
