import CursorTimelineCore
import XCTest

final class CursorDatabaseReaderIntegrationTests: XCTestCase {
    private var paths: CursorPaths!

    override func setUp() {
        super.setUp()
        paths = CursorPaths()
    }

    func testFetchSessionIndexWhenDatabaseExists() throws {
        guard FileManager.default.fileExists(atPath: paths.globalDatabase.path) else {
            throw XCTSkip("Cursor global database not found on this machine")
        }

        let reader = CursorDatabaseReader(paths: paths)
        let start = Date()
        let index = try reader.fetchSessionIndex()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThan(index.count, 0)
        XCTAssertLessThan(elapsed, 60, "fetchSessionIndex should stay under 60s")

        let titles = Set(index.map(\.title))
        XCTAssertFalse(titles.isEmpty)
    }

    func testFetchUserBubblesForSessionWithPrompts() throws {
        guard FileManager.default.fileExists(atPath: paths.globalDatabase.path) else {
            throw XCTSkip("Cursor global database not found on this machine")
        }

        let reader = CursorDatabaseReader(paths: paths)
        let index = try reader.fetchSessionIndex()

        var matched = false
        for meta in index.prefix(30) {
            let bubbles = try reader.fetchUserBubbles(composerIds: [meta.id])
            guard !bubbles.isEmpty else { continue }
            XCTAssertTrue(bubbles.allSatisfy { $0.composerId == meta.id })
            matched = true
            break
        }

        XCTAssertTrue(matched, "Expected user bubbles in at least one recent session")
    }

    func testTimelineDataLoaderProducesSessionsForRecentWindow() throws {
        guard FileManager.default.fileExists(atPath: paths.globalDatabase.path) else {
            throw XCTSkip("Cursor global database not found on this machine")
        }

        let loader = TimelineDataLoader(paths: paths)
        let index = try loader.fetchSessionIndex()
        let window = ThreeDayWindow.today()
        let recentIDs = index
            .filter { window.overlaps(sessionStart: $0.startAt, sessionEnd: $0.endAt) }
            .prefix(5)
            .map(\.id)

        guard !recentIDs.isEmpty else {
            throw XCTSkip("No sessions in current 3-day window")
        }

        let sessions = try loader.loadSessions(composerIdsForBubbles: Array(recentIDs))
        XCTAssertGreaterThanOrEqual(sessions.count, index.count > 0 ? 1 : 0)
        XCTAssertTrue(sessions.contains { recentIDs.contains($0.id) })
    }
}
