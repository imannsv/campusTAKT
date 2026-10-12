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

public func scheduleTimeRange(
  _ placements: [ScheduledEvent], day: Date, now: Date, calendar: Calendar
) -> DateInterval {
  let defaultStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
  let defaultEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)!
  var first = min(defaultStart, placements.map(\.start).min() ?? defaultStart)
  var last = max(defaultEnd, placements.map(\.end).max() ?? defaultEnd)
  if calendar.isDate(day, inSameDayAs: now) {
    let currentHour = calendar.dateInterval(of: .hour, for: now)!
    first = min(first, currentHour.start)
    last = max(last, currentHour.end)
  }
  let start = calendar.dateInterval(of: .hour, for: first)!.start
  let end =
    last == calendar.dateInterval(of: .hour, for: last)!.start
    ? last : calendar.dateInterval(of: .hour, for: last)!.end
  return DateInterval(start: start, end: end)
}
