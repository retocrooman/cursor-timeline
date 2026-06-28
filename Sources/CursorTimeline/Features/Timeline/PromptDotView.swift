import SwiftUI
import CursorTimelineCore

struct PromptDotView: View {
    let prompt: PromptEvent

    var body: some View {
        Circle()
            .fill(ModelColorPalette.color(for: prompt.model))
            .frame(width: TimelineMetrics.dotSize, height: TimelineMetrics.dotSize)
            .help(tooltipText)
    }

    private var tooltipText: String {
        let time = Self.timeFormatter.string(from: prompt.timestamp)
        let model = ModelColorPalette.label(for: prompt.model)
        let preview = prompt.text.replacingOccurrences(of: "\n", with: " ")
        let clipped = String(preview.prefix(60))
        return "\(time) · \(model) · \(clipped)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
