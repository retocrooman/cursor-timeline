import SwiftUI
import CursorTimelineCore

struct ContentView: View {
    @State private var store = TimelineStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cursor Timeline")
                .font(.title2)

            if store.isLoading {
                ProgressView("読み込み中…")
            }

            if let error = store.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Text("Index: \(store.sessionIndex.count) 件")
            Text("直近3日: \(store.sessions.count) 件（メタ \(store.sessionsInWindowCount) 件）")

            HStack {
                Button("←") { Task { await store.goPrev() } }
                Button("Today") { Task { await store.goToday() } }
                Button("→") { Task { await store.goNext() } }
                Button("Refresh") { Task { await store.reload() } }
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 320, alignment: .topLeading)
        .task {
            await store.reload()
        }
    }
}

#Preview {
    ContentView()
}
