import CursorTimelineCore
import XCTest

final class SessionVisibilityTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyUntitledSessionIsHidden() {
        let session = TimelineSession(
            id: "1",
            repoId: "empty-window",
            repoLabel: "ホーム",
            title: "Untitled",
            startAt: base,
            endAt: base,
            source: .composer,
            prompts: []
        )
        XCTAssertFalse(SessionVisibility.isDisplayable(session))
    }

    func testUntitledWithPromptsIsVisible() {
        let session = TimelineSession(
            id: "1",
            repoId: "repo",
            repoLabel: "repo",
            title: "Untitled",
            startAt: base,
            endAt: base,
            source: .composer,
            prompts: [
                PromptEvent(
                    id: "p1",
                    sessionId: "1",
                    timestamp: base,
                    text: "hello",
                    model: .sonnet,
                    confidence: .high
                ),
            ]
        )
        XCTAssertTrue(SessionVisibility.isDisplayable(session))
    }
}
