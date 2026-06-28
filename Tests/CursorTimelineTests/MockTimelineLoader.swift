import CursorTimelineCore
import Foundation

final class MockTimelineLoader: TimelineLoading, @unchecked Sendable {
    var fetchIndexCallCount = 0
    var fetchBubblesCallCount = 0
    var fetchedBubbleIDSets: [[String]] = []

    var index: [SessionMeta] = []
    var bubblesByComposer: [String: [RawUserBubble]] = [:]
    var transcripts: [AgentTranscriptSession] = []

    func fetchSessionIndex() throws -> [SessionMeta] {
        fetchIndexCallCount += 1
        return index
    }

    func fetchUserBubbles(composerIds: [String]) throws -> [RawUserBubble] {
        fetchBubblesCallCount += 1
        fetchedBubbleIDSets.append(composerIds)
        return composerIds.flatMap { bubblesByComposer[$0] ?? [] }
    }

    func fetchTranscripts(for composerIds: Set<String>) throws -> [AgentTranscriptSession] {
        transcripts.filter { composerIds.contains($0.composerId) }
    }
}
