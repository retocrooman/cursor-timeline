import SwiftUI
import UniformTypeIdentifiers
import CursorTimelineCore

public struct TimelineToolbar: View {
    @Bindable var store: TimelineStore
    @State private var showCSVImporter = false

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

            Divider()
                .frame(height: 20)

            Button("Import CSV…") {
                showCSVImporter = true
            }
            .help("Team usage CSV をインポートしてプロンプトに $ を突合")

            if let label = store.usageCSVLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 140)
            }

            Spacer()

            Text("b\(BuildInfo.bundleVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if store.isLoading || store.isReconciling {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .fileImporter(
            isPresented: $showCSVImporter,
            allowedContentTypes: Self.csvImportTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                await store.importUsageCSV(from: url)
            }
        }
    }

    private static let csvImportTypes: [UTType] = {
        var types: [UTType] = [.commaSeparatedText, .plainText]
        if let csv = UTType(filenameExtension: "csv") {
            types.append(csv)
        }
        return types
    }()

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
