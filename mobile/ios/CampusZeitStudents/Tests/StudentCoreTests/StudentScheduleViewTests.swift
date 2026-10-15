import XCTest

@testable import StudentCore

final class StudentScheduleViewTests: XCTestCase {
  func testShortViewsSpanWeekBoundariesAndUseOnlyVisibleEventBounds() throws {
    let calendar = institutionCalendar("Europe/Berlin")
    let friday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 23)))
    let saturday = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: friday))
    let monday = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: friday))
    func event(_ day: Date, hour: Int) -> StudentEvent {
      let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
      return StudentEvent(
        id: "\(day)", name: "Vorlesung", start: start,
        end: calendar.date(byAdding: .hour, value: 1, to: start)!, kind: "teaching",
        cancelled: false, roomNames: [], groupNames: [], teacherNames: [])
    }
    let rows = [event(friday, hour: 10), event(saturday, hour: 8), event(monday, hour: 6)]
    let day = ScheduleWeek(events: rows, date: friday, calendar: calendar, view: .day)
    XCTAssertEqual(day.days, [friday])
    XCTAssertEqual(day.startMinute, 600)
    XCTAssertEqual(day.endMinute, 660)
    let two = ScheduleWeek(events: rows, date: friday, calendar: calendar, view: .twoDays)
    XCTAssertEqual(two.days, [friday, saturday])
    XCTAssertEqual(two.startMinute, 480)
    let three = ScheduleWeek(events: rows, date: saturday, calendar: calendar, view: .threeDays)
    XCTAssertEqual(three.days.last, monday)
    XCTAssertEqual(three.startMinute, 360)
    XCTAssertEqual(calendar.dateComponents([.day], from: saturday, to: monday).day, 2)
    // The end of daylight saving time must not turn Sunday and Monday into the same day.
    XCTAssertEqual(Set(three.days).count, 3)
  }
}
