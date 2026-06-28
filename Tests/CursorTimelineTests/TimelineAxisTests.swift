import XCTest
import CursorTimelineCore

final class TimelineAxisTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }

    func testYAxisUsesColumnDayNotInstantDay() throws {
        let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28)))
        let sundayAfternoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 13)))
        let mondayMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29)))

        let startMinutes = TimelineAxis.minutesFromVisibleStart(of: sundayAfternoon, onDay: sunday, calendar: calendar)
        let endMinutes = TimelineAxis.minutesFromVisibleStart(of: mondayMidnight, onDay: sunday, calendar: calendar)

        XCTAssertEqual(startMinutes, 5 * 60)
        XCTAssertEqual(endMinutes, 15 * 60)
        XCTAssertGreaterThan(endMinutes, startMinutes)
    }
}

final class DaySessionClipperPromptTests: XCTestCase {
    func testPromptsWithinClipExcludesOutsideInterval() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let early = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 10)))
        let inside = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 14)))
        let clip = DaySessionClip(
            start: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 13))),
            end: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 29)))
        )

        let prompts = [
            PromptEvent(id: "a", sessionId: "s", timestamp: early, text: "early", model: .sonnet, confidence: .high),
            PromptEvent(id: "b", sessionId: "s", timestamp: inside, text: "inside", model: .sonnet, confidence: .high),
        ]

        let filtered = DaySessionClipper.prompts(prompts, within: clip)
        XCTAssertEqual(filtered.map(\.id), ["b"])
    }
}
