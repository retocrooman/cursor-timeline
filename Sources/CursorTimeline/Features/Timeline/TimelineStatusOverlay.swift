import SwiftUI
import CursorTimelineCore

public struct TimelineStatusOverlay: View {
    let isLoading: Bool
    let emptyMessage: String?
    let errorMessage: String?

    public init(isLoading: Bool, emptyMessage: String? = nil, errorMessage: String? = nil) {
        self.isLoading = isLoading
        self.emptyMessage = emptyMessage
        self.errorMessage = errorMessage
    }

    public var body: some View {
        if isLoading {
            loadingView
        } else if let errorMessage {
            statusView(
                title: "読み込みエラー",
                systemImage: "exclamationmark.triangle",
                message: errorMessage
            )
        } else if let emptyMessage {
            statusView(
                title: "セッションなし",
                systemImage: "calendar.badge.clock",
                message: emptyMessage
            )
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("読み込み中…")
                .font(.headline)
            Text("Cursor のセッション情報を取得しています")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func statusView(title: String, systemImage: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

public enum TimelineEmptyMessages {
    public static let noSessionsInWindow = """
        この3日間に表示できるセッションはありません。
        ← → で日付を移動するか、Today で直近3日に戻してください。
        """

    public static let databaseHint = """
        データの場所: ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
        """
}
