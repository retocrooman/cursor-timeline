import SwiftUI
import CursorTimelineCore

public struct ThreeDayTimelineView: View {
    let days: [Date]
    let sessions: [TimelineSession]
    var selectedSessionID: String?
    var onSelect: (TimelineSession) -> Void

    private var calendar: Calendar { .current }

    public init(
        days: [Date],
        sessions: [TimelineSession],
        selectedSessionID: String? = nil,
        onSelect: @escaping (TimelineSession) -> Void
    ) {
        self.days = days
        self.sessions = sessions
        self.selectedSessionID = selectedSessionID
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                TimeGutterView()
                ForEach(days, id: \.timeIntervalSince1970) { day in
                    let daySessions = TimelineMetrics.sessions(on: day, in: sessions, calendar: calendar)
                    let placements = OverlapLayout.compute(
                        sessions: TimelineMetrics.overlapIntervals(
                            for: daySessions,
                            on: day,
                            calendar: calendar
                        )
                    )
                    DayColumnView(
                        day: day,
                        isToday: calendar.isDateInToday(day),
                        sessions: daySessions,
                        placements: placements,
                        selectedSessionID: selectedSessionID,
                        onSelect: onSelect
                    )
                }
            }
            .frame(width: TimelineMetrics.gutterWidth + TimelineMetrics.dayColumnMinWidth * 3)
        }
    }
}
