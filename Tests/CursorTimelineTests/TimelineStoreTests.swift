import CursorTimelineCore
import XCTest

final class TimelineStoreTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar = cal
    }

    private func meta(id: String, startOffsetHours: Int, title: String = "Session") -> SessionMeta {
        let start = base.addingTimeInterval(TimeInterval(startOffsetHours) * 3600)
        return SessionMeta(
            id: id,
            repoId: "repo",
            repoLabel: "repo",
            title: title,
            startAt: start,
            endAt: start.addingTimeInterval(3600),
            messageCount: 1,
            source: .composer
        )
    }

    private func bubble(composerId: String, id: String, offsetHours: Int) -> RawUserBubble {
        RawUserBubble(
            composerId: composerId,
            bubbleId: id,
            createdAt: base.addingTimeInterval(TimeInterval(offsetHours) * 3600),
            text: "prompt \(id)",
            modelRaw: "claude-4-sonnet"
        )
    }

    func testReloadLoadsIndexAndWindowSessions() async {
        let mock = MockTimelineLoader()
        mock.index = [
            meta(id: "in-window", startOffsetHours: 1),
            meta(id: "out-window", startOffsetHours: -200, title: "Old"),
        ]
        mock.bubblesByComposer["in-window"] = [bubble(composerId: "in-window", id: "b1", offsetHours: 1)]

        let store = TimelineStore(loader: mock, window: ThreeDayWindow(start: calendar.startOfDay(for: base)))
        await store.reload()

        XCTAssertEqual(mock.fetchIndexCallCount, 1)
        XCTAssertEqual(store.sessionIndex.count, 2)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.id, "in-window")
        XCTAssertEqual(store.loadedComposerIds, ["in-window"])
    }

    func testLoadWindowDoesNotRefetchIndex() async {
        let mock = MockTimelineLoader()
        mock.index = [meta(id: "a", startOffsetHours: 1)]
        mock.bubblesByComposer["a"] = [bubble(composerId: "a", id: "b1", offsetHours: 1)]

        let store = TimelineStore(loader: mock, window: ThreeDayWindow(start: calendar.startOfDay(for: base)))
        await store.reload()
        mock.fetchIndexCallCount = 0

        await store.goPrev()

        XCTAssertEqual(mock.fetchIndexCallCount, 0)
        XCTAssertEqual(mock.fetchBubblesCallCount, 1)
    }

    func testLoadedComposerIdsPreventDuplicateBubbleFetch() async {
        let mock = MockTimelineLoader()
        mock.index = [meta(id: "a", startOffsetHours: 1)]
        mock.bubblesByComposer["a"] = [bubble(composerId: "a", id: "b1", offsetHours: 1)]

        let window = ThreeDayWindow(start: calendar.startOfDay(for: base))
        let store = TimelineStore(loader: mock, window: window)
        await store.reload()
        await store.loadWindow()

        XCTAssertEqual(mock.fetchedBubbleIDSets.filter { $0 == ["a"] }.count, 1)
    }

    func testLoadPromptsFetchesWhenBubbleCacheEmpty() async {
        let mock = MockTimelineLoader()
        mock.index = [meta(id: "lazy", startOffsetHours: 1)]
        mock.bubblesByComposer = [:]

        let store = TimelineStore(loader: mock, window: ThreeDayWindow(start: calendar.startOfDay(for: base)))
        await store.reload()
        XCTAssertEqual(store.sessions.first?.prompts.count, 0)

        mock.bubblesByComposer["lazy"] = [bubble(composerId: "lazy", id: "b1", offsetHours: 1)]
        await store.loadPrompts(for: "lazy")

        XCTAssertTrue(mock.fetchedBubbleIDSets.contains { $0 == ["lazy"] })
        XCTAssertEqual(store.selection?.id, "lazy")
        XCTAssertEqual(store.selection?.prompts.count, 1)
    }

    func testGoTodayResetsWindow() async {
        let mock = MockTimelineLoader()
        mock.index = []
        let store = TimelineStore(loader: mock)
        await store.reload()
        store.window.goPrev()

        await store.goToday()

        let expected = ThreeDayWindow.today(calendar: calendar).days.last
        XCTAssertEqual(store.window.days.last, expected)
    }
}
