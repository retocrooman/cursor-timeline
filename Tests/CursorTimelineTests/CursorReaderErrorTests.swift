import XCTest
import CursorTimelineCore

final class CursorReaderErrorTests: XCTestCase {
    func testDatabaseNotFoundMessageIsJapanese() {
        let message = CursorReaderError.databaseNotFound.errorDescription
        XCTAssertEqual(
            message,
            "Cursor のデータベースが見つかりません。Cursor を一度起動してから、再読み込み（↻）してください。"
        )
    }
}
