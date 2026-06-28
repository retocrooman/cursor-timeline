import CursorTimelineCore
import XCTest

final class RepoResolverTests: XCTestCase {
    func testEmptyWindowUsesHomeLabel() {
        let repo = RepoResolver.resolve(workspacePath: "empty-window")
        XCTAssertEqual(repo.repoId, "empty-window")
        XCTAssertEqual(repo.repoLabel, "ホーム")
    }

    func testProjectPathUsesLastComponentAsLabel() {
        let repo = RepoResolver.resolve(workspacePath: "/Users/shiho/Github/retocrooman/cursor-timeline")
        XCTAssertEqual(repo.repoLabel, "cursor-timeline")
        XCTAssertEqual(repo.repoId, "/Users/shiho/Github/retocrooman/cursor-timeline")
    }

    func testEmptyPathReturnsUnknown() {
        let repo = RepoResolver.resolve(workspacePath: nil)
        XCTAssertEqual(repo.repoId, "unknown")
        XCTAssertEqual(repo.repoLabel, "unknown")
    }
}
