import XCTest

@testable import StudentCore

final class StudentCoreTests: XCTestCase {
  func testQRAndServerTrustBoundary() throws {
    let key = String(repeating: "a", count: 43)
    let valid =
      "{\"version\":1,\"server\":\"https://campus.example.org\",\"access\":\"2f30647f-87ec-48b8-b5db-efb6b2d74af4\",\"key\":\"\(key)\"}"
    XCTAssertEqual(try LoginQR.parse(valid).server, "https://campus.example.org")
    XCTAssertThrowsError(
      try LoginQR.parse(valid.replacingOccurrences(of: "\"version\":1", with: "\"version\":2")))
    XCTAssertThrowsError(try LoginQR.parse("https://campus.example.org"))
    XCTAssertThrowsError(try serverURL("https://user:password@campus.example.org"))
    XCTAssertThrowsError(try serverURL("https://campus.example.org/path"))
    XCTAssertThrowsError(try serverURL("http://campus.example.org"))
    XCTAssertEqual(try serverURL("http://192.168.1.10:8000").port, 8000)
  }
  func testPublishedFeedDatesAndCancelledEvent() throws {
    let json = """
      {"institution":"Testhochschule","scope":"WI26 A1","timezone":"Europe/Berlin","updated":"2026-10-25T12:00:00.123Z",
      "rows":[{"id":"1:2","name":"Mathematik","start":"2026-10-25T09:00:00+01:00","end":"2026-10-25T10:30:00+01:00","kind":"teaching","cancelled":true,"room_names":["R 1.1"],"group_names":["WI26 A1"],"teacher_names":[]}],"notices":[{"id":7,"title":"Raumänderung","body":"Die Vorlesung findet in R 1.1 statt.","created":"2026-10-25T08:00:00Z"}]}
      """
    let feed = try feedDecoder().decode(StudentFeed.self, from: Data(json.utf8))
    XCTAssertTrue(feed.rows[0].cancelled)
    XCTAssertEqual(feed.rows[0].name, "Mathematik")
    XCTAssertEqual(feed.notices.first?.id, 7)
    XCTAssertEqual(feed.notices.first?.title, "Raumänderung")
    XCTAssertEqual(feed.notices.first?.body, "Die Vorlesung findet in R 1.1 statt.")
    XCTAssertEqual(feed.rows[0].end.timeIntervalSince(feed.rows[0].start), 90 * 60)
    let calendar = institutionCalendar(feed.timezone)
    let interval = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: feed.rows[0].start))
    XCTAssertEqual(calendar.component(.weekday, from: interval.start), 2)
    XCTAssertEqual(interval.duration, 7 * 86400 + 3600)
  }
  func testClientAgainstDisposableBackend() async throws {
    guard let path = ProcessInfo.processInfo.environment["STUDENT_APP_FIXTURE"] else {
      throw XCTSkip("Set STUDENT_APP_FIXTURE to credentials from the disposable browser fixture.")
    }
    let values =
      try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)))
      as! [String: String]
    let api = StudentAPI(server: try serverURL(values["server"]!))
    let reply = try await api.login(code: values["code"]!, password: values["password"]!)
    let calendar = institutionCalendar(reply.timezone)
    let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
    let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
    let feed = try await api.feed(token: reply.token, start: start, end: end, zone: reply.timezone)
    XCTAssertFalse(feed.rows.isEmpty)
    XCTAssertEqual(feed.scope, reply.scope)
    try await api.logout(token: reply.token)
    do {
      _ = try await api.feed(token: reply.token, start: start, end: end, zone: reply.timezone)
      XCTFail("Logged-out device must lose access")
    } catch StudentError.expired {}
  }

  func testScheduleSequentialParallelAndMidnightEvents() throws {
    let calendar = institutionCalendar("Europe/Berlin")
    let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    func event(_ id: String, _ start: Int, _ end: Int) -> StudentEvent {
      StudentEvent(
        id: id, name: id, start: day.addingTimeInterval(Double(start * 3600)),
        end: day.addingTimeInterval(Double(end * 3600)), kind: "teaching", cancelled: false,
        roomNames: [], groupNames: [], teacherNames: [])
    }
    let sequential = schedulePlacements(
      [event("c", 14, 17), event("a", 8, 11), event("b", 11, 14)], day: day, calendar: calendar)
    XCTAssertEqual(sequential.map(\.id), ["a", "b", "c"])
    XCTAssertTrue(sequential.allSatisfy { $0.lane == 0 && $0.lanes == 1 })
    let parallel = schedulePlacements(
      [event("solo", 8, 9), event("a", 10, 12), event("b", 11, 13), event("c", 12, 14)],
      day: day, calendar: calendar)
    XCTAssertEqual(parallel.map(\.lanes), [1, 2, 2, 2])
    XCTAssertEqual(parallel.map(\.lane), [0, 0, 1, 0])
    let midnight = schedulePlacements(
      [
        event("before", -2, 1), event("after", 23, 26), event("invalid", 10, 9),
        event("next", 24, 25),
      ],
      day: day, calendar: calendar)
    XCTAssertEqual(midnight.map(\.id), ["before", "after"])
    XCTAssertEqual(midnight.first?.start, day)
    XCTAssertEqual(midnight.last?.end, calendar.date(byAdding: .day, value: 1, to: day))
  }

  func testExamCountdownUsesLocalDaysAcrossClockChange() {
    let calendar = institutionCalendar("Europe/Berlin")
    let now = calendar.date(
      from: DateComponents(year: 2026, month: 10, day: 24, hour: 23, minute: 55))!
    let tomorrow = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 8))!
    let following = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 8))!
    XCTAssertEqual(
      examCountdown(to: now.addingTimeInterval(-3600), now: now, calendar: calendar), "Heute")
    XCTAssertEqual(examCountdown(to: tomorrow, now: now, calendar: calendar), "Morgen")
    XCTAssertEqual(examCountdown(to: following, now: now, calendar: calendar), "In 2 Tagen")
    XCTAssertEqual(examCountdown(to: now, now: following, calendar: calendar), "Vor 2 Tagen")
  }
}
