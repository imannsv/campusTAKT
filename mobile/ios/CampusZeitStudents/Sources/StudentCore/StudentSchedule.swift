import Foundation

public struct ScheduledEvent: Identifiable {
  public var id: String { event.id }
  public let event: StudentEvent
  public let start: Date
  public let end: Date
  public let lane: Int
  public var lanes: Int
}
public func scheduleSwipeStep(horizontal: Double, vertical: Double) -> Int {
  guard abs(horizontal) >= 60, abs(horizontal) > abs(vertical) * 1.5 else { return 0 }
  return horizontal < 0 ? 1 : -1
}
public enum StudentScheduleView: Int, CaseIterable, Sendable {
  case day = 1
  case twoDays = 2
  case threeDays = 3
  case week = 7
  public var title: String {
    switch self {
    case .day: return "Tag"
    case .twoDays: return "2 Tage"
    case .threeDays: return "3 Tage"
    case .week: return "Woche"
    }
  }
}
public struct ScheduleWeek {
  public let days: [Date]
  public let placements: [[ScheduledEvent]]
  public let startMinute: Int
  public let endMinute: Int
  public var timeTicks: [Int] {
    [startMinute] + Array(stride(from: (startMinute / 60 + 1) * 60, to: endMinute, by: 60))
  }

  public init(
    events: [StudentEvent], date: Date, calendar: Calendar,
    view: StudentScheduleView = .week
  ) {
    let first =
      view == .week
      ? calendar.dateInterval(of: .weekOfYear, for: date)!.start : calendar.startOfDay(for: date)
    let count = view == .week ? 6 : view.rawValue
    var weekDays = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first)! }
    var weekPlacements = weekDays.map { schedulePlacements(events, day: $0, calendar: calendar) }
    if view == .week && weekPlacements[5].isEmpty {
      weekDays.removeLast()
      weekPlacements.removeLast()
    }
    days = weekDays
    placements = weekPlacements
    let rows = weekPlacements.flatMap { $0 }
    startMinute =
      rows.map {
        calendar.component(.hour, from: $0.start) * 60 + calendar.component(.minute, from: $0.start)
      }.min() ?? 480
    endMinute = max(
      startMinute + 1,
      rows.map {
        calendar.isDate($0.end, inSameDayAs: $0.start)
          ? calendar.component(.hour, from: $0.end) * 60 + calendar.component(.minute, from: $0.end)
            + (calendar.component(.second, from: $0.end) > 0 ? 1 : 0)
          : 1440
      }.max() ?? 1080)
  }
}
public func scheduleShortTitle(_ title: String) -> String {
  let words = title.split(whereSeparator: { $0.isWhitespace || $0 == "·" || $0 == "-" })
  if words.count > 1 { return String(words.compactMap(\.first).prefix(6)).uppercased() }
  return title.count <= 6 ? title : String(title.prefix(5)) + "…"
}
public func scheduleHit(
  _ placements: [ScheduledEvent], time: Date, laneFraction: Double, tolerance: TimeInterval
) -> StudentEvent? {
  let candidates = placements.filter {
    let lane = min(max(0, Int(laneFraction * Double($0.lanes))), $0.lanes - 1)
    return lane == $0.lane && time >= $0.start.addingTimeInterval(-tolerance)
      && time < $0.end.addingTimeInterval(tolerance)
  }
  return candidates.min { a, b in
    let aContains = time >= a.start && time < a.end
    let bContains = time >= b.start && time < b.end
    if aContains != bContains { return aContains }
    return min(abs(time.timeIntervalSince(a.start)), abs(time.timeIntervalSince(a.end)))
      < min(abs(time.timeIntervalSince(b.start)), abs(time.timeIntervalSince(b.end)))
  }?.event
}
public func schedulePlacements(
  _ events: [StudentEvent], day: Date, calendar: Calendar
) -> [ScheduledEvent] {
  let start = calendar.startOfDay(for: day)
  let end = calendar.date(byAdding: .day, value: 1, to: start)!
  let sorted = events.filter { $0.start < end && $0.end > start && $0.end > $0.start }
    .sorted { $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start }
  var result: [ScheduledEvent] = []
  var group: [ScheduledEvent] = []
  var ends: [Date] = []
  var groupEnd = start
  for event in sorted {
    let eventStart = max(start, event.start)
    let eventEnd = min(end, event.end)
    if eventStart >= groupEnd {
      result += group.map { item in
        var placed = item
        placed.lanes = ends.count
        return placed
      }
      group = []
      ends = []
    }
    let lane = ends.firstIndex { $0 <= eventStart } ?? ends.count
    if lane == ends.count { ends.append(eventEnd) } else { ends[lane] = eventEnd }
    group.append(
      ScheduledEvent(event: event, start: eventStart, end: eventEnd, lane: lane, lanes: 0))
    groupEnd = group.count == 1 ? eventEnd : max(groupEnd, eventEnd)
  }
  result += group.map { item in
    var placed = item
    placed.lanes = ends.count
    return placed
  }
  return result
}
public func examCountdown(to date: Date, now: Date, calendar: Calendar) -> String {
  let days =
    calendar.dateComponents(
      [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)
    ).day ?? 0
  switch days {
  case 0: return "Heute"
  case 1: return "Morgen"
  case 2...: return "In \(days) Tagen"
  case -1: return "Gestern"
  default: return "Vor \(-days) Tagen"
  }
}
