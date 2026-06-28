import SwiftUI
import CursorTimelineCore
import CursorTimelineUI

struct ContentView: View {
    @State private var store = TimelineStore()

    var body: some View {
        VStack(spacing: 0) {
            TimelineToolbar(store: store)

            if let error = store.lastError, !store.sessions.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
            }

            HSplitView {
                ZStack {
                    ThreeDayTimelineView(
                        days: store.window.days,
                        sessions: store.sessions,
                        selectedSessionID: store.selection?.id,
                        onSelect: { session in
                            Task { await store.loadPrompts(for: session.id) }
                        }
                    )
                    .frame(minWidth: TimelineMetrics.gutterWidth + TimelineMetrics.dayColumnMinWidth * 3)
                    .opacity(store.sessions.isEmpty ? 0.35 : 1)

                    TimelineStatusOverlay(
                        isLoading: store.showsInitialLoading,
                        emptyMessage: store.showsEmptyState ? TimelineEmptyMessages.noSessionsInWindow : nil,
                        errorMessage: store.lastError.flatMap { error in
                            store.sessions.isEmpty ? error + "\n\n" + TimelineEmptyMessages.databaseHint : nil
                        }
                    )
                }

                SessionInspectorView(session: store.selection)
            }

            LegendView(sessions: store.sessions)
        }
        .frame(minWidth: 1100, minHeight: 640)
        .task {
            await store.reload()
        }
    }
}

public struct TimelinePreviewHost: View {
    @State private var selection: TimelineSession?
    private let sessions = TimelinePreviewData.mockSessions()
    private let days = TimelinePreviewData.mockWindow.days

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Text("Cursor Timeline — Preview")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)

            HSplitView {
                ThreeDayTimelineView(
                    days: days,
                    sessions: sessions,
                    selectedSessionID: selection?.id,
                    onSelect: { selection = $0 }
                )
                SessionInspectorView(session: selection)
            }

            LegendView(sessions: sessions)
        }
        .frame(width: 1100, height: 640)
    }
}

#Preview {
    TimelinePreviewHost()
}
