import SwiftUI
import CursorTimelineCore

struct SessionBlockView: View {
    let session: TimelineSession
    let columnDay: Date
    let displayStart: Date
    let displayEnd: Date
    let displayPrompts: [PromptEvent]
    let placement: OverlapPlacement
    let columnWidth: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    private var repoColor: Color {
        RepoColorPalette.color(for: session.repoId)
    }

    var body: some View {
        let width = TimelineMetrics.blockWidth(columnWidth: columnWidth, placement: placement)
        let x = TimelineMetrics.blockXOffset(columnWidth: columnWidth, placement: placement)
        let y = TimelineMetrics.yPosition(for: displayStart, onDay: columnDay)
        let height = TimelineMetrics.blockHeight(start: displayStart, end: displayEnd, onDay: columnDay)
        let stackedPrompts = Self.stackPrompts(displayPrompts, calendar: .current)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(repoColor.opacity(0.16))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(repoColor)
                        .frame(width: 4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }

            Text(session.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(stackedPrompts) { item in
                PromptDotView(prompt: item.prompt)
                    .position(
                        x: width - 10 - CGFloat(item.stackIndex * 6),
                        y: TimelineMetrics.yPosition(for: item.prompt.timestamp, onDay: columnDay)
                            - y
                            - CGFloat(item.stackIndex * 4)
                    )
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .offset(x: x, y: y)
        .onTapGesture(perform: onSelect)
    }

    private struct StackedPrompt: Identifiable {
        let prompt: PromptEvent
        let stackIndex: Int
        var id: String { prompt.id }
    }

    private static func stackPrompts(_ prompts: [PromptEvent], calendar: Calendar) -> [StackedPrompt] {
        var counts: [String: Int] = [:]
        return prompts
            .sorted { $0.timestamp < $1.timestamp }
            .map { prompt in
                let key = minuteKey(for: prompt.timestamp, calendar: calendar)
                let index = counts[key, default: 0]
                counts[key] = index + 1
                return StackedPrompt(prompt: prompt, stackIndex: index)
            }
    }

    private static func minuteKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)-\(parts.hour ?? 0)-\(parts.minute ?? 0)"
    }
}
