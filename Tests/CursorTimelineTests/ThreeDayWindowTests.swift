import CursorTimelineCore
import XCTest

final class ThreeDayWindowTests: XCTestCase {
    private var calendar: Calendar!
    private var timeZone: TimeZone!

    override func setUp() {
        super.setUp()
        timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        calendar = cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 0))!
    }

    func testTodayWindowIsDayBeforeYesterdayThroughToday() {
        let now = date(2026, 6, 28)
        let window = ThreeDayWindow.today(calendar: calendar, now: now)

        XCTAssertEqual(window.days.count, 3)
        XCTAssertEqual(window.days[0], date(2026, 6, 26))
        XCTAssertEqual(window.days[1], date(2026, 6, 27))
        XCTAssertEqual(window.days[2], date(2026, 6, 28))
        XCTAssertEqual(ThreeDayWindow.todayIndex, 2)
    }

    func testGoPrevSlidesThreeDaysIntoPast() {
        var window = ThreeDayWindow.today(calendar: calendar, now: date(2026, 6, 28))
        window.goPrev(calendar: calendar)

        XCTAssertEqual(window.days[0], date(2026, 6, 23))
        XCTAssertEqual(window.days[1], date(2026, 6, 24))
        XCTAssertEqual(window.days[2], date(2026, 6, 25))
    }

    func testGoNextReturnsTowardToday() {
        var window = ThreeDayWindow.today(calendar: calendar, now: date(2026, 6, 28))
        window.goPrev(calendar: calendar)
        window.goNext(calendar: calendar)

        XCTAssertEqual(window.days[0], date(2026, 6, 26))
        XCTAssertEqual(window.days[2], date(2026, 6, 28))
    }

    func testGoTodayResetsWindow() {
        var window = ThreeDayWindow.today(calendar: calendar, now: date(2026, 6, 28))
        window.goPrev(calendar: calendar)
        window.goToday(calendar: calendar, now: date(2026, 6, 28))

        XCTAssertEqual(window.days[2], date(2026, 6, 28))
    }

    func testOverlapsSessionInWindow() {
        let window = ThreeDayWindow.today(calendar: calendar, now: date(2026, 6, 28))
        let sessionStart = date(2026, 6, 27).addingTimeInterval(3600 * 10)
        let sessionEnd = sessionStart.addingTimeInterval(3600)

        XCTAssertTrue(window.overlaps(sessionStart: sessionStart, sessionEnd: sessionEnd, calendar: calendar))
    }
}
