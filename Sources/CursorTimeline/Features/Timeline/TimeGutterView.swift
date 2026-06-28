import SwiftUI

struct TimeGutterView: View {
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 32)
            ForEach(TimelineMetrics.hourStart..<TimelineMetrics.hourEnd, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: TimelineMetrics.hourHeight, alignment: .topTrailing)
                    .padding(.trailing, 6)
            }
        }
        .frame(width: TimelineMetrics.gutterWidth, height: 32 + TimelineMetrics.timelineHeight)
    }
}
