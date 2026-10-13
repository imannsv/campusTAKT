import Foundation

public struct StudentOfflineWeek: Codable, Sendable {
  public let start: Date
  public let end: Date
  public var rows: [StudentEvent]
  public let savedAt: Date
}
public struct StudentOfflineArchive: Codable, Sendable {
  private let version: Int
  private let session: String
  public private(set) var metadata: StudentFeed?
  public private(set) var weeks: [StudentOfflineWeek] = []
  public private(set) var savedAt: Date?
  public init(session: String) {
    version = 1
    self.session = session
  }

  public mutating func update(_ feed: StudentFeed, start: Date, end: Date, savedAt: Date) {
    let calendar = institutionCalendar(feed.timezone)
    // Replace the whole fetched interval, including removals and overnight events in adjacent weeks.
    let incomingIDs = Set(feed.rows.map(\.id))
    for index in weeks.indices {
      let week = weeks[index]
      weeks[index].rows.removeAll {
        ($0.start < end && $0.end > start) || incomingIDs.contains($0.id)
      }
      weeks[index].rows.append(
        contentsOf: feed.rows.filter {
          $0.start < week.end && $0.end > week.start
        })
    }
    var cursor = start
    while cursor < end {
      let next = calendar.date(byAdding: .day, value: 7, to: cursor)!
      weeks.removeAll { $0.start == cursor }
      weeks.append(
        StudentOfflineWeek(
          start: cursor, end: next,
          rows: feed.rows.filter { $0.start < next && $0.end > cursor }, savedAt: savedAt))
      cursor = next
    }
    weeks.sort { $0.savedAt == $1.savedAt ? $0.start > $1.start : $0.savedAt > $1.savedAt }
    weeks = Array(weeks.prefix(30))
    metadata = StudentFeed(
      institution: feed.institution, scope: feed.scope,
      timezone: feed.timezone, updated: feed.updated, rows: [], notices: feed.notices)
    self.savedAt = savedAt
  }

  public func feed(for date: Date) -> StudentFeed? {
    guard let metadata,
      let week = weeks.first(where: { $0.start <= date && date < $0.end })
    else { return nil }
    return StudentFeed(
      institution: metadata.institution, scope: metadata.scope,
      timezone: metadata.timezone, updated: week.savedAt, rows: week.rows, notices: metadata.notices
    )
  }

  public func events(from date: Date) -> [StudentEvent] {
    var ids = Set<String>()
    return weeks.flatMap(\.rows).filter { $0.end > date && ids.insert($0.id).inserted }
      .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
  }

  public func save(to url: URL) throws {
    let data = try JSONEncoder().encode(self)
    guard data.count <= 10_000_000 else {
      throw StudentError.service(
        "Der Offline-Stand ist zu groß. Bitte die Verwaltung kontaktieren.")
    }
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var backupURL = directory
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try backupURL.setResourceValues(values)
    #if os(iOS)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
      try data.write(to: url, options: [.atomic, .completeFileProtection])
    #else
      try data.write(to: url, options: .atomic)
    #endif
    backupURL = url
    try backupURL.setResourceValues(values)
  }

  public static func load(from url: URL, session: String, expires: Date, now: Date = Date()) throws
    -> Self?
  {
    guard expires > now, FileManager.default.fileExists(atPath: url.path) else { return nil }
    let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
    guard let size, size.intValue <= 10_000_000 else { return nil }
    let archive = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    guard archive.version == 1, archive.session == session,
      archive.weeks.count <= 30, archive.metadata != nil,
      Set(archive.weeks.map(\.start)).count == archive.weeks.count
    else { return nil }
    let calendar = institutionCalendar(archive.metadata!.timezone)
    guard
      archive.weeks.allSatisfy({
        $0.start == calendar.dateInterval(of: .weekOfYear, for: $0.start)?.start
          && $0.end == calendar.date(byAdding: .day, value: 7, to: $0.start)
      })
    else { return nil }
    return archive
  }

  public static func clear(at url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
