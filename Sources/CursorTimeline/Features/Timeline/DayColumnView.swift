import SwiftUI
import CursorTimelineCore

struct DayColumnView: View {
    let day: Date
    let isToday: Bool
    let sessions: [TimelineSession]
    let placements: [String: OverlapPlacement]
    let selectedSessionID: String?
    let onSelect: (TimelineSession) -> Void

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            ZStack(alignment: .topLeading) {
                gridLines
                GeometryReader { geometry in
                    ForEach(sessions) { session in
                        if let placement = placements[session.id],
                           let clip = DaySessionClipper.clip(
                               sessionStart: session.startAt,
                               sessionEnd: session.endAt,
                               on: day
                           ) {
                            SessionBlockView(
                                session: session,
                                columnDay: day,
                                displayStart: clip.start,
                                displayEnd: clip.end,
                                displayPrompts: DaySessionClipper.prompts(session.prompts, within: clip),
                                placement: placement,
                                columnWidth: geometry.size.width,
                                isSelected: session.id == selectedSessionID,
                                onSelect: { onSelect(session) }
                            )
                        }
                    }
                }
            }
            .frame(height: TimelineMetrics.timelineHeight)
        }
        .frame(width: TimelineMetrics.dayColumnMinWidth)
        .background(isToday ? Color.accentColor.opacity(0.04) : Color.clear)
    }

    private var dayHeader: some View {
        VStack(spacing: 2) {
            Text(Self.weekdayFormatter.string(from: day))
                .font(.caption)
                .foregroundStyle(isToday ? Color.accentColor : .secondary)
            Text(Self.dayFormatter.string(from: day))
                .font(.headline)
                .foregroundStyle(isToday ? Color.accentColor : .primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isToday ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(height: isToday ? 2 : 1)
        }
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            ForEach(TimelineMetrics.hourStart..<TimelineMetrics.hourEnd, id: \.self) { _ in
                VStack(spacing: 0) {
                    Divider()
                    Spacer()
                }
                .frame(height: TimelineMetrics.hourHeight)
            }
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
