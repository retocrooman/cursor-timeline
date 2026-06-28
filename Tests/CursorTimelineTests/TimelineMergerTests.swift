import CursorTimelineCore
import XCTest

final class TimelineMergerTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func testComposerAndMatchingTranscriptMergeIntoOneSession() {
        let meta = SessionMeta(
            id: "abc",
            repoId: "repo-a",
            repoLabel: "repo-a",
            title: "My Session",
            startAt: base,
            endAt: base.addingTimeInterval(3600),
            messageCount: 1,
            source: .composer
        )
        let bubbles = [
            RawUserBubble(
                composerId: "abc",
                bubbleId: "b1",
                createdAt: base,
                text: "hello",
                modelRaw: "claude-4-sonnet"
            ),
        ]
        let transcript = AgentTranscriptSession(
            composerId: "abc",
            projectSlug: "repo-a",
            fileURL: URL(fileURLWithPath: "/tmp/a.jsonl"),
            fileModifiedAt: base.addingTimeInterval(60),
            userMessages: [
                AgentTranscriptMessage(lineIndex: 0, text: "hello"),
                AgentTranscriptMessage(lineIndex: 1, text: "follow up"),
            ]
        )

        let sessions = TimelineMerger.merge(index: [meta], bubbles: bubbles, transcripts: [transcript])

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].source, .merged)
        XCTAssertEqual(sessions[0].prompts.count, 2)
        XCTAssertEqual(sessions[0].prompts[0].confidence, .high)
        XCTAssertEqual(sessions[0].prompts[1].confidence, .medium)
    }

    func testTranscriptOnlySessionUsesLowConfidence() {
        let transcript = AgentTranscriptSession(
            composerId: "tx-1",
            projectSlug: "proj",
            fileURL: URL(fileURLWithPath: "/tmp/tx.jsonl"),
            fileModifiedAt: base,
            userMessages: [AgentTranscriptMessage(lineIndex: 0, text: "solo transcript")]
        )

        let sessions = TimelineMerger.merge(index: [], bubbles: [], transcripts: [transcript])

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].source, .agentTranscript)
        XCTAssertEqual(sessions[0].prompts.first?.confidence, .low)
    }
}
