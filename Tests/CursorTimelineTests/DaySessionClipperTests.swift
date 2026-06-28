import XCTest
import CursorTimelineCore

final class DaySessionClipperTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }

    func testClipKeepsPortionWithinDay() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29)))
        let sessionStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 13)))
        let sessionEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 0, minute: 7)))

        let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28)))
        let sundayClip = DaySessionClipper.clip(
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            on: sunday,
            calendar: calendar
        )
        XCTAssertEqual(sundayClip?.start, sessionStart)
        XCTAssertEqual(sundayClip?.end, try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29))))

        let mondayClip = DaySessionClipper.clip(
            sessionStart: sessionStart,
            sessionEnd: sessionEnd,
            on: day,
            calendar: calendar
        )
        XCTAssertEqual(mondayClip?.start, day)
        XCTAssertEqual(mondayClip?.end, sessionEnd)
    }
}
