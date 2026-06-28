import Foundation
import Observation

@Observable
public final class TimelineStore {
    public private(set) var sessionIndex: [SessionMeta] = []
    public var window: ThreeDayWindow
    public private(set) var sessions: [TimelineSession] = []
    public var selection: TimelineSession?
    public private(set) var loadedComposerIds: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var lastError: String?

    private var bubbleCache: [String: [RawUserBubble]] = [:]
    private let loader: any TimelineLoading

    public init(
        loader: any TimelineLoading = TimelineDataLoader(),
        window: ThreeDayWindow = .today()
    ) {
        self.loader = loader
        self.window = window
    }

    /// 段1: index 全件 → 段2–3: 現在ウィンドウ
    public func reload() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let index = try await runOnBackground { try self.loader.fetchSessionIndex() }
            sessionIndex = index
            bubbleCache = [:]
            loadedComposerIds = []
            await loadWindow()
        } catch {
            lastError = Self.userMessage(for: error)
        }
    }

    /// 段2–3: メタ再利用 + 未ロード composer の bubble のみ追加取得
    public func loadWindow() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let metasInWindow = sessionIndex.filter {
                window.overlaps(sessionStart: $0.startAt, sessionEnd: $0.endAt)
            }
            let idsInWindow = metasInWindow.map(\.id)
            let newIDs = idsInWindow.filter { !loadedComposerIds.contains($0) }

            if !newIDs.isEmpty {
                let fetched = try await runOnBackground {
                    try self.loader.fetchUserBubbles(composerIds: newIDs)
                }
                for bubble in fetched {
                    bubbleCache[bubble.composerId, default: []].append(bubble)
                }
                loadedComposerIds.formUnion(newIDs)
            }

            let bubbles = idsInWindow.flatMap { bubbleCache[$0] ?? [] }
            let transcripts = try await runOnBackground {
                try self.loader.fetchTranscripts(for: Set(idsInWindow))
            }

            sessions = TimelineSessionBuilder.build(
                index: metasInWindow,
                bubbles: bubbles,
                transcripts: transcripts
            )

            if let selectedID = selection?.id {
                selection = sessions.first { $0.id == selectedID }
            }
        } catch {
            lastError = Self.userMessage(for: error)
        }
    }

    /// 段4: Inspector 用。プロンプト未ロードなら bubble を追加取得
    public func loadPrompts(for sessionID: String) async {
        let needsFetch = bubbleCache[sessionID]?.isEmpty ?? true
        if needsFetch {
            isLoading = true
            defer { isLoading = false }

            do {
                let fetched = try await runOnBackground {
                    try self.loader.fetchUserBubbles(composerIds: [sessionID])
                }
                bubbleCache[sessionID] = fetched
                loadedComposerIds.insert(sessionID)
            } catch {
                lastError = Self.userMessage(for: error)
                return
            }
        }

        await loadWindow()
        selection = sessions.first { $0.id == sessionID }
    }

    public func goPrev() async {
        window.goPrev()
        await loadWindow()
    }

    public func goNext() async {
        window.goNext()
        await loadWindow()
    }

    public func goToday() async {
        window.goToday()
        await loadWindow()
    }

    public var sessionsInWindowCount: Int {
        sessionIndex.filter { window.overlaps(sessionStart: $0.startAt, sessionEnd: $0.endAt) }.count
    }

    public var showsEmptyState: Bool {
        !isLoading && lastError == nil && sessions.isEmpty
    }

    public var showsInitialLoading: Bool {
        isLoading && sessions.isEmpty && sessionIndex.isEmpty
    }

    private static func userMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }

    private func runOnBackground<T: Sendable>(_ work: @Sendable @escaping () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try work()
        }.value
    }
}
