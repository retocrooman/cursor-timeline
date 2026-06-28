import SwiftUI
import CursorTimelineCore

public struct SessionInspectorView: View {
    let session: TimelineSession?

    public init(session: TimelineSession?) {
        self.session = session
    }

    public var body: some View {
        Group {
            if let session {
                inspectorContent(for: session)
            } else {
                ContentUnavailableView(
                    "セッションを選択",
                    systemImage: "sidebar.right",
                    description: Text("タイムラインのブロックをクリックするとプロンプトが表示されます")
                )
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func inspectorContent(for session: TimelineSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                repoHeader(for: session)
                timeRange(for: session)
                Divider()
                Text("プロンプト")
                    .font(.headline)
                if session.prompts.isEmpty {
                    Text("プロンプトなし")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(session.prompts) { prompt in
                        promptRow(prompt)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func repoHeader(for session: TimelineSession) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(RepoColorPalette.color(for: session.repoId))
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.repoLabel)
                    .font(.headline)
                Text(session.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func timeRange(for session: TimelineSession) -> some View {
        Text("\(Self.timeFormatter.string(from: session.startAt)) – \(Self.timeFormatter.string(from: session.endAt))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func promptRow(_ prompt: PromptEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(ModelColorPalette.color(for: prompt.model))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(Self.timeFormatter.string(from: prompt.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ModelColorPalette.label(for: prompt.model))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(prompt.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
