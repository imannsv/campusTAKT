import Foundation

import XCTest

@testable import StudentCore

final class StudentOfflineTests: XCTestCase {
  private let calendar = institutionCalendar("Europe/Berlin")
  private var monday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))! }
  private func day(_ offset: Int) -> Date {
    calendar.date(byAdding: .day, value: offset, to: monday)!
  }
  private func feed(_ rows: [StudentEvent] = [], notices: [StudentNotice] = []) -> StudentFeed {
    StudentFeed(
      institution: "Uni", scope: "A2", timezone: "Europe/Berlin", updated: monday,
      rows: rows, notices: notices)
  }
  private func event(_ id: String, start: Date, end: Date, cancelled: Bool = false) -> StudentEvent
  {
    StudentEvent(
      id: id, name: "Vorlesung", start: start, end: end, kind: "exam",
      cancelled: cancelled, roomNames: ["R 1"], groupNames: ["A2"], teacherNames: ["Lehrperson"])
  }
  func testOfflineRoundTripRestoresWeeksExamsAndNoticesAfterRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("offline.json")
    let row = event(
      "exam", start: day(10).addingTimeInterval(3600), end: day(10).addingTimeInterval(7200))
    let notice = StudentNotice(id: 1, title: "Ausfall", body: "Vollständiger Text", created: monday)
    var cache = StudentOfflineArchive(session: "session-a")
    cache.update(feed([row], notices: [notice]), start: monday, end: day(126), savedAt: monday)
    try cache.save(to: url)
    let restored = try XCTUnwrap(
      StudentOfflineArchive.load(from: url, session: "session-a", expires: day(90), now: day(1)))
    XCTAssertEqual(restored.feed(for: day(10))?.rows.first?.id, "exam")
    XCTAssertEqual(restored.metadata?.notices.first?.body, notice.body)
    XCTAssertEqual(restored.events(from: day(1)).filter { $0.kind == "exam" }.count, 1)
    XCTAssertTrue(try XCTUnwrap(restored.feed(for: monday)).rows.isEmpty)
    XCTAssertNil(restored.feed(for: day(126)))
    XCTAssertEqual(restored.savedAt, monday)
  }
  func testRefreshReplacesCancellationsRemovedEventsAndWithdrawnNotices() {
    let row = event("one", start: day(1), end: day(1).addingTimeInterval(3600))
    let notice = StudentNotice(id: 1, title: "Alt", body: "Alt", created: monday)
    var cache = StudentOfflineArchive(session: "a")
    cache.update(feed([row], notices: [notice]), start: monday, end: day(7), savedAt: monday)
    let cancelled = event("one", start: row.start, end: row.end, cancelled: true)
    cache.update(feed([cancelled]), start: monday, end: day(7), savedAt: day(1))
    XCTAssertTrue(cache.feed(for: monday)!.rows[0].cancelled)
    XCTAssertTrue(cache.metadata!.notices.isEmpty)
    cache.update(feed(), start: monday, end: day(7), savedAt: day(2))
    XCTAssertTrue(cache.feed(for: monday)!.rows.isEmpty)
  }
  func testWrongSessionExpiredCorruptOrUnsupportedFileNeverRestores() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("offline.json")
    var cache = StudentOfflineArchive(session: "a")
    cache.update(feed(), start: monday, end: day(7), savedAt: monday)
    try cache.save(to: url)
    XCTAssertNil(
      try StudentOfflineArchive.load(from: url, session: "b", expires: day(90), now: monday))
    XCTAssertNil(
      try StudentOfflineArchive.load(from: url, session: "a", expires: monday, now: monday))
    var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    json["version"] = 999
    try JSONSerialization.data(withJSONObject: json).write(to: url)
    XCTAssertNil(
      try StudentOfflineArchive.load(from: url, session: "a", expires: day(90), now: monday))
    try Data("broken".utf8).write(to: url)
    XCTAssertThrowsError(
      try StudentOfflineArchive.load(from: url, session: "a", expires: day(90), now: monday))
    try StudentOfflineArchive.clear(at: url)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    try StudentOfflineArchive.clear(at: url)
  }
  func testOvernightEventsRemainUniqueAndFreshAcrossWeekAndClockChange() {
    var cache = StudentOfflineArchive(session: "a")
    let row = event(
      "overnight", start: day(13).addingTimeInterval(23 * 3600),
      end: day(14).addingTimeInterval(2 * 3600))
    cache.update(feed([row]), start: monday, end: day(21), savedAt: monday)
    XCTAssertEqual(cache.events(from: monday).count, 1)
    XCTAssertEqual(cache.feed(for: day(14))?.rows.count, 1)
    cache.update(feed(), start: day(14), end: day(21), savedAt: day(1))
    XCTAssertTrue(cache.events(from: monday).isEmpty)
    XCTAssertEqual(cache.feed(for: day(7))?.rows.count, 0)
  }
  func testMovingEventReplacesItsOldPositionAcrossCachedWeeks() {
    var cache = StudentOfflineArchive(session: "a")
    let row = event("moved", start: day(1), end: day(1).addingTimeInterval(3600))
    cache.update(feed([row]), start: monday, end: day(7), savedAt: monday)
    let moved = event("moved", start: day(10), end: day(10).addingTimeInterval(3600))
    cache.update(feed([moved]), start: day(7), end: day(14), savedAt: day(1))
    XCTAssertTrue(cache.feed(for: monday)!.rows.isEmpty)
    XCTAssertEqual(cache.events(from: monday).map(\.start), [moved.start])
  }
  func testCacheIsBoundedAndRetainsDownloadedHistory() {
    var cache = StudentOfflineArchive(session: "a")
    cache.update(feed(), start: monday, end: day(126), savedAt: monday)
    cache.update(feed(), start: day(-7), end: monday, savedAt: day(1))
    XCTAssertNotNil(cache.feed(for: day(-1)))
    for index in 1...35 {
      cache.update(feed(), start: day(-7 * index), end: day(-7 * (index - 1)), savedAt: day(index))
    }
    XCTAssertLessThanOrEqual(cache.weeks.count, 30)
    XCTAssertNotNil(cache.feed(for: day(-7 * 35)))
    XCTAssertNil(cache.feed(for: day(120)))
  }
}
