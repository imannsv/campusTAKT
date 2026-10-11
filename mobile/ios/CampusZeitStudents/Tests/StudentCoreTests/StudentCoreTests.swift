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
      "rows":[{"id":"1:2","name":"Mathematik","start":"2026-10-25T09:00:00+01:00","end":"2026-10-25T10:30:00+01:00","kind":"teaching","cancelled":true,"room_names":["R 1.1"],"group_names":["WI26 A1"],"teacher_names":[]}],"notices":[]}
      """
    let feed = try feedDecoder().decode(StudentFeed.self, from: Data(json.utf8))
    XCTAssertTrue(feed.rows[0].cancelled)
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
}
