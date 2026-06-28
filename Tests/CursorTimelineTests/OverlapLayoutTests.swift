import CursorTimelineCore
import XCTest

final class OverlapLayoutTests: XCTestCase {
    private var base: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 9))!
    }

    private func interval(id: String, startHour: Int, endHour: Int) -> OverlapLayout.SessionInterval {
        OverlapLayout.SessionInterval(
            id: id,
            start: base.addingTimeInterval(TimeInterval(startHour - 9) * 3600),
            end: base.addingTimeInterval(TimeInterval(endHour - 9) * 3600)
        )
    }

    func testNonOverlappingSessionsUseFullWidth() {
        let sessions = [
            interval(id: "a", startHour: 9, endHour: 10),
            interval(id: "b", startHour: 11, endHour: 12),
        ]

        let layout = OverlapLayout.compute(sessions: sessions)

        XCTAssertEqual(layout["a"], OverlapPlacement(column: 0, totalColumns: 1))
        XCTAssertEqual(layout["b"], OverlapPlacement(column: 0, totalColumns: 1))
    }

    func testThreeFullyOverlappingSessionsSplitIntoThreeColumns() {
        let sessions = [
            interval(id: "a", startHour: 9, endHour: 11),
            interval(id: "b", startHour: 9, endHour: 11),
            interval(id: "c", startHour: 9, endHour: 11),
        ]

        let layout = OverlapLayout.compute(sessions: sessions)

        XCTAssertEqual(layout["a"]?.totalColumns, 3)
        XCTAssertEqual(layout["b"]?.totalColumns, 3)
        XCTAssertEqual(layout["c"]?.totalColumns, 3)
        XCTAssertEqual(Set([layout["a"]!.column, layout["b"]!.column, layout["c"]!.column]), Set([0, 1, 2]))
    }

    func testPartialOverlapUsesTwoColumns() {
        let sessions = [
            interval(id: "a", startHour: 9, endHour: 11),
            interval(id: "b", startHour: 10, endHour: 12),
            interval(id: "c", startHour: 11, endHour: 13),
        ]

        let layout = OverlapLayout.compute(sessions: sessions)

        XCTAssertEqual(layout["a"]?.column, 0)
        XCTAssertEqual(layout["b"]?.column, 1)
        XCTAssertEqual(layout["c"]?.column, 0)
        XCTAssertEqual(layout["a"]?.totalColumns, 2)
        XCTAssertEqual(layout["b"]?.totalColumns, 2)
        XCTAssertEqual(layout["c"]?.totalColumns, 2)
    }
}
