import SwiftUI
import CursorTimelineCore

public struct TimelineToolbar: View {
    @Bindable var store: TimelineStore

    public init(store: TimelineStore) {
        self.store = store
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.goPrev() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("3日前へ")

            Text(dateRangeLabel)
                .font(.headline)
                .frame(minWidth: 180)

            Button {
                Task { await store.goNext() }
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("3日後へ")

            Divider()
                .frame(height: 20)

            Button("Today") {
                Task { await store.goToday() }
            }
            .help("一昨日・昨日・今日へ")

            Button {
                Task { await store.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("再読み込み")

            Spacer()

            Text("b\(BuildInfo.bundleVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var dateRangeLabel: String {
        guard let first = store.window.days.first,
              let last = store.window.days.last else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }
}
