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
  func testHTTPServerRequiresAnActualLocalHost() throws {
    for host in [
      "127.0.0.1.attacker.example", "192.168.1.10.attacker.example",
      "10.attacker.0.0.1", "192..168.1.10", "192.168.1.10.",
      "192.168.1.256", "+10.0.0.1", "010.0.0.1", "127.1", "2130706433",
      "0x7f000001", "8.8.8.8", "172.15.0.1", "172.32.0.1",
    ] {
      XCTAssertThrowsError(try serverURL("http://\(host):8000"), host)
    }
    for host in [
      "localhost", "campus.local", "127.0.0.1", "10.0.0.1", "192.168.1.10",
      "172.16.0.1", "172.31.255.255",
    ] {
      let url = try serverURL(" http://\(host):8000/ ")
      XCTAssertEqual(url.host, host)
      XCTAssertEqual(url.port, 8000)
    }
    XCTAssertNoThrow(try serverURL("https://127.0.0.1.attacker.example"))
    let qr = """
      {"version":1,"server":"http://127.0.0.1.attacker.example","access":"2f30647f-87ec-48b8-b5db-efb6b2d74af4","key":"\(String(repeating: "a", count: 43))"}
      """
    XCTAssertThrowsError(try LoginQR.parse(qr))
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
  func testNoticeDeliveryIgnoresInitialFeedAndRepeatedRefreshes() {
    let first = StudentNotice(id: 1, title: "Alt", body: "Vorhanden", created: Date(timeIntervalSince1970: 10))
    let second = StudentNotice(id: 2, title: "Neu", body: "Ausfall", created: Date(timeIntervalSince1970: 20))
    let third = StudentNotice(id: 3, title: "Neu", body: "Hinweis", created: second.created)
    XCTAssertTrue(newStudentNotices([first], knownIDs: nil).isEmpty)
    XCTAssertEqual(newStudentNotices([third, second, first], knownIDs: [1]).map(\.id), [2, 3])
    XCTAssertTrue(newStudentNotices([third, second, first], knownIDs: [1, 2, 3]).isEmpty)
    XCTAssertEqual(newStudentNotices([second], knownIDs: []).map(\.id), [2])
    XCTAssertTrue(newStudentNotices([], knownIDs: [1]).isEmpty)
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

  func testWeekStartsAtFirstEventInsteadOfCurrentTime() {
    let calendar = institutionCalendar("Europe/Berlin")
    let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let event = StudentEvent(id: "morning", name: "Vorlesung",
      start: monday.addingTimeInterval(10 * 3600 + 30 * 60),
      end: monday.addingTimeInterval(12 * 3600), kind: "teaching", cancelled: false,
      roomNames: [], groupNames: [], teacherNames: [])
    let week = ScheduleWeek(events: [event], date: monday, calendar: calendar)
    XCTAssertEqual(week.startMinute, 630)
    XCTAssertEqual(week.endMinute, 720)
    XCTAssertEqual(week.timeTicks, [630, 660])
  }

  func testWeekBoundsUseAllVisibleDaysAndPreserveMidnightEvents() {
    let calendar = institutionCalendar("Europe/Berlin")
    let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    func event(_ id: String, day: Int, start: Int, end: Int) -> StudentEvent {
      let date = calendar.date(byAdding: .day, value: day, to: monday)!
      return StudentEvent(id: id, name: id, start: date.addingTimeInterval(Double(start * 60)),
        end: date.addingTimeInterval(Double(end * 60)), kind: "teaching", cancelled: false,
        roomNames: [], groupNames: [], teacherNames: [])
    }
    let rows = [event("late", day: 0, start: 600, end: 810),
      event("early", day: 2, start: 465, end: 645),
      event("outside-week", day: 7, start: 0, end: 60)]
    let week = ScheduleWeek(events: rows, date: monday, calendar: calendar)
    XCTAssertEqual(week.startMinute, 465)
    XCTAssertEqual(week.endMinute, 810)
    XCTAssertEqual(week.timeTicks.first, 465)
    XCTAssertEqual(week.timeTicks.last, 780)
    let overnight = ScheduleWeek(events: [event("night", day: 4, start: 1380, end: 1500)],
      date: monday, calendar: calendar)
    XCTAssertEqual(overnight.days.count, 6)
    XCTAssertEqual(overnight.startMinute, 0)
    XCTAssertEqual(overnight.endMinute, 1440)
    let tiny = ScheduleWeek(events: [event("short", day: 0, start: 630, end: 631)],
      date: monday, calendar: calendar)
    XCTAssertGreaterThan(tiny.endMinute, tiny.startMinute)
    XCTAssertEqual(tiny.timeTicks, [630])
  }

  func testCancelledFeedThrowsCancellationError() async throws {
    let api = StudentAPI(server: try serverURL("http://127.0.0.1:9"))
    let start = Date()
    let task = Task {
      try await api.feed(token: "test-only", start: start,
        end: start.addingTimeInterval(86400), zone: "Europe/Berlin")
    }
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("Cancelled requests must not produce a feed")
    } catch is CancellationError {
    } catch {
      XCTFail("Expected silent task cancellation, got \(error)")
    }
  }

  func testWeekSwipeDirectionIgnoresVerticalScrollingAndSmallDrags() {
    XCTAssertEqual(scheduleSwipeStep(horizontal: -130, vertical: 20), 1)
    XCTAssertEqual(scheduleSwipeStep(horizontal: 130, vertical: -20), -1)
    XCTAssertEqual(scheduleSwipeStep(horizontal: 40, vertical: 0), 0)
    XCTAssertEqual(scheduleSwipeStep(horizontal: 80, vertical: 140), 0)
    XCTAssertEqual(scheduleSwipeStep(horizontal: -100, vertical: 90), 0)
    let calendar = institutionCalendar("Europe/Berlin")
    let sunday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
    let next = calendar.date(byAdding: .day,
      value: scheduleSwipeStep(horizontal: -130, vertical: 0) * 7, to: sunday)!
    XCTAssertEqual(calendar.component(.day, from: next), 1)
    XCTAssertEqual(calendar.component(.hour, from: next), 12)
    XCTAssertNotEqual(calendar.dateInterval(of: .weekOfYear, for: sunday)?.start,
      calendar.dateInterval(of: .weekOfYear, for: next)?.start)
  }
  func testWholeWeekUsesWeekdaysAndCommonTimeBounds() {
    let calendar = institutionCalendar("Europe/Berlin")
    let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
    let hidden = StudentEvent(id: "sun", name: "Sonntag", start: sunday.addingTimeInterval(36000),
      end: sunday.addingTimeInterval(39600), kind: "teaching", cancelled: false,
      roomNames: [], groupNames: [], teacherNames: [])
    let week = ScheduleWeek(events: [hidden], date: sunday, calendar: calendar)
    XCTAssertEqual(week.days.count, 5)
    XCTAssertEqual(calendar.component(.weekday, from: week.days.first!), 2)
    XCTAssertEqual(calendar.component(.weekday, from: week.days.last!), 6)
    XCTAssertTrue(week.placements.allSatisfy { $0.isEmpty })
    XCTAssertEqual(week.startMinute, 480)
    XCTAssertEqual(week.endMinute, 1080)
    XCTAssertEqual(scheduleShortTitle("Management von Projekten"), "MVP")
    XCTAssertEqual(scheduleShortTitle("C++"), "C++")
  }

  func testSaturdayAppearsOnlyForEventsInTheDisplayedWeek() {
    let calendar = institutionCalendar("Europe/Berlin")
    let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let saturday = calendar.date(byAdding: .day, value: 5, to: monday)!
    func event(_ start: Date, _ end: Date, cancelled: Bool = false) -> StudentEvent {
      StudentEvent(id: "test", name: "Samstag", start: start, end: end, kind: "teaching",
        cancelled: cancelled, roomNames: [], groupNames: [], teacherNames: [])
    }
    func week(_ rows: [StudentEvent], date: Date? = nil) -> ScheduleWeek {
      ScheduleWeek(events: rows, date: date ?? monday, calendar: calendar)
    }
    XCTAssertEqual(week([]).days.count, 5)
    let lecture = event(saturday.addingTimeInterval(8 * 3600), saturday.addingTimeInterval(11 * 3600))
    let withSaturday = week([lecture])
    XCTAssertEqual(withSaturday.days.count, 6)
    XCTAssertEqual(withSaturday.days.last, saturday)
    XCTAssertEqual(withSaturday.placements.last?.map(\.id), [lecture.id])
    XCTAssertEqual(week([event(lecture.start, lecture.end, cancelled: true)]).days.count, 6)
    XCTAssertEqual(week([lecture], date: calendar.date(byAdding: .day, value: 7, to: monday)!).days.count, 5)
    XCTAssertEqual(week([event(saturday.addingTimeInterval(-3600), saturday)]).days.count, 5)
    XCTAssertEqual(week([event(saturday.addingTimeInterval(-3600), saturday.addingTimeInterval(3600))]).days.count, 6)
    XCTAssertEqual(week([event(lecture.end, lecture.start)]).days.count, 5)
  }

  func testCompactWeekHitTestingSelectsAdjacentAndParallelEvents() {
    let calendar = institutionCalendar("Europe/Berlin")
    let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    func event(_ id: String, _ start: Double, _ end: Double) -> StudentEvent {
      StudentEvent(id: id, name: id, start: day.addingTimeInterval(start * 3600),
        end: day.addingTimeInterval(end * 3600), kind: "teaching", cancelled: false,
        roomNames: [], groupNames: [], teacherNames: [])
    }
    let rows = schedulePlacements([event("short", 8, 8.25), event("next", 8.25, 8.5),
      event("left", 9, 10), event("right", 9, 10)], day: day, calendar: calendar)
    func hit(_ hour: Double, _ x: Double) -> String? {
      scheduleHit(rows, time: day.addingTimeInterval(hour * 3600), laneFraction: x,
        tolerance: 15 * 60)?.id
    }
    XCTAssertEqual(hit(8.1, 0.5), "short")
    XCTAssertEqual(hit(8.25, 0.5), "next")
    XCTAssertEqual(hit(9.5, 0.25), "left")
    XCTAssertEqual(hit(9.5, 0.75), "right")
    XCTAssertNil(hit(12, 0.5))
  }

  func testTodaySummaryKeepsCurrentEventsWhenBrowsingAnotherWeek() {
    let calendar = institutionCalendar("Europe/Berlin")
    let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
    let upcoming = [
      StudentEvent(id: "today", name: "Heute", start: today.addingTimeInterval(8 * 3600),
        end: today.addingTimeInterval(11 * 3600), kind: "teaching", cancelled: false,
        roomNames: ["R 1.1"], groupNames: [], teacherNames: []),
      StudentEvent(id: "cancelled", name: "Abgesagt", start: today.addingTimeInterval(11 * 3600),
        end: today.addingTimeInterval(14 * 3600), kind: "teaching", cancelled: true,
        roomNames: [], groupNames: [], teacherNames: []),
      StudentEvent(id: "next-week", name: "Andere Woche", start: nextWeek.addingTimeInterval(8 * 3600),
        end: nextWeek.addingTimeInterval(11 * 3600), kind: "teaching", cancelled: false,
        roomNames: [], groupNames: [], teacherNames: []),
    ]
    let browsed = ScheduleWeek(events: upcoming, date: nextWeek, calendar: calendar)
    XCTAssertEqual(browsed.placements.flatMap { $0 }.map(\.id), ["next-week"])
    let summary = schedulePlacements(upcoming, day: today, calendar: calendar).map(\.event)
    XCTAssertEqual(summary.map(\.id), ["today", "cancelled"])
    XCTAssertTrue(summary.last!.cancelled)
  }

}
