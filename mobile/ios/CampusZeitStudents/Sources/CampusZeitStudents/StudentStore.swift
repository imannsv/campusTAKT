#if canImport(UIKit)
  import CryptoKit
  import SwiftUI
  import StudentCore

  @MainActor
  final class StudentStore: ObservableObject {
    @Published var credential: DeviceCredential?
    @Published var feed: StudentFeed?
    @Published var upcomingRows: [StudentEvent] = []
    @Published private(set) var archive: StudentOfflineArchive?
    @Published private(set) var usingSavedData = false
    @Published private(set) var connectionUnavailable = false
    @Published private(set) var cacheError: String?
    @Published var busy = false
    @Published var error: String?
    @Published var selectedDate = Date()
    var examRows: [StudentEvent] { upcomingRows.filter { $0.kind == "exam" } }
    var metadata: StudentFeed? { archive?.metadata }
    var calendar: Calendar { institutionCalendar(credential?.login.timezone ?? "Europe/Berlin") }
    var selectedWeekSavedAt: Date? {
      archive?.weeks.first { $0.start <= selectedDate && selectedDate < $0.end }?.savedAt
    }
    var todaySaved: Bool { archive?.feed(for: calendar.startOfDay(for: Date())) != nil }
    let permissions: StudentPermissions
    private static let cacheURL = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    .appendingPathComponent("CampusZeit/offline.json")
    private func cacheSession(_ saved: DeviceCredential) -> String {
      SHA256.hash(data: Data((saved.server.absoluteString + "|" + saved.login.token).utf8))
        .map { String(format: "%02x", $0) }.joined()
    }

    init(permissions: StudentPermissions) {
      self.permissions = permissions
      do {
        if let saved = try DeviceKeychain.read() {
          _ = try serverURL(saved.server.absoluteString)
          if saved.login.expires > Date() { credential = saved } else { try DeviceKeychain.clear() }
        }
      } catch { self.error = error.localizedDescription }
      guard let saved = credential else {
        permissions.clearNotifications()
        try? StudentOfflineArchive.clear(at: Self.cacheURL)
        return
      }
      do {
        archive = try StudentOfflineArchive.load(
          from: Self.cacheURL, session: cacheSession(saved), expires: saved.login.expires)
        if archive == nil { try StudentOfflineArchive.clear(at: Self.cacheURL) }
        usingSavedData = archive != nil
        selectSavedWeek()
      } catch {
        try? StudentOfflineArchive.clear(at: Self.cacheURL)
        cacheError =
          "Der gespeicherte Stand konnte nicht gelesen werden. Bitte erneut herunterladen."
      }
    }

    func selectSavedWeek() {
      feed = archive?.feed(for: selectedDate)
      upcomingRows = archive?.events(from: calendar.startOfDay(for: Date())) ?? []
      if let stamp = selectedWeekSavedAt, let last = archive?.savedAt, stamp < last {
        usingSavedData = true
      }
    }

    func login(server: String, code: String, password: String, qr: LoginQR? = nil) async {
      guard !busy else { return }
      busy = true
      error = nil
      defer { busy = false }
      do {
        let url = try serverURL(server)
        let api = StudentAPI(server: url)
        let reply: LoginReply
        if let qr {
          reply = try await api.login(qr: qr)
        } else {
          reply = try await api.login(code: code, password: password)
        }
        let saved = DeviceCredential(server: url, login: reply)
        do {
          try StudentOfflineArchive.clear(at: Self.cacheURL)
          try DeviceKeychain.save(saved)
        } catch {
          try? await api.logout(token: reply.token)
          throw error
        }
        permissions.clearNotifications()
        archive = nil
        feed = nil
        upcomingRows = []
        cacheError = nil
        usingSavedData = false
        connectionUnavailable = false
        selectedDate = Date()
        credential = saved
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }

    private func expire() {
      try? DeviceKeychain.clear()
      try? StudentOfflineArchive.clear(at: Self.cacheURL)
      permissions.clearNotifications()
      credential = nil
      archive = nil
      feed = nil
      upcomingRows = []
      usingSavedData = false
      connectionUnavailable = false
      cacheError = nil
      error = StudentError.expired.localizedDescription
    }

    func refresh() async {
      guard let saved = credential, !busy else { return }
      guard saved.login.expires > Date() else {
        expire()
        return
      }
      let requestedDate = selectedDate
      busy = true
      defer {
        busy = false
        if selectedDate != requestedDate, credential != nil { Task { await refresh() } }
      }
      selectSavedWeek()
      do {
        let start = calendar.dateInterval(of: .weekOfYear, for: requestedDate)!.start
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        let today = calendar.startOfDay(for: Date())
        let downloadStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let horizon = calendar.date(byAdding: .day, value: 126, to: downloadStart)!
        let api = StudentAPI(server: saved.server)
        let upcoming = try await api.feed(
          token: saved.login.token, start: downloadStart, end: horizon, zone: saved.login.timezone)
        guard credential?.login.token == saved.login.token else { return }
        guard saved.login.expires > Date() else {
          expire()
          return
        }
        var snapshot = archive ?? StudentOfflineArchive(session: cacheSession(saved))
        snapshot.update(upcoming, start: downloadStart, end: horizon, savedAt: Date())
        archive = snapshot
        usingSavedData = false
        connectionUnavailable = false
        selectSavedWeek()
        error = nil
        persist(snapshot)
        await permissions.receive(upcoming.notices, credential: saved)
        guard credential?.login.token == saved.login.token else { return }
        if start < downloadStart || end > horizon {
          let week = try await api.feed(
            token: saved.login.token, start: start, end: end, zone: saved.login.timezone)
          guard credential?.login.token == saved.login.token else { return }
          guard saved.login.expires > Date() else {
            expire()
            return
          }
          snapshot.update(week, start: start, end: end, savedAt: Date())
          archive = snapshot
          usingSavedData = false
          selectSavedWeek()
          persist(snapshot)
        }
      } catch StudentError.expired {
        if credential?.login.token == saved.login.token { expire() }
      } catch is CancellationError {} catch {
        if credential?.login.token == saved.login.token {
          usingSavedData = archive != nil
          connectionUnavailable = true
          self.error =
            archive == nil
            ? "Der Server ist momentan nicht erreichbar. Bitte später erneut aktualisieren." : nil
        }
      }
    }

    private func persist(_ snapshot: StudentOfflineArchive) {
      do {
        try snapshot.save(to: Self.cacheURL)
        cacheError = nil
      } catch {
        cacheError =
          "Der Offline-Stand konnte nicht gespeichert werden. Die geladenen Daten bleiben bis zum Schließen verfügbar. Bitte erneut herunterladen."
      }
    }

    func logout() async {
      guard let saved = credential else { return }
      do {
        try StudentOfflineArchive.clear(at: Self.cacheURL)
        try DeviceKeychain.clear()
      } catch {
        self.error = "Die gespeicherten Daten konnten nicht entfernt werden. Bitte erneut abmelden."
        return
      }
      permissions.clearNotifications()
      credential = nil
      archive = nil
      feed = nil
      upcomingRows = []
      usingSavedData = false
      connectionUnavailable = false
      cacheError = nil
      error = nil
      do { try await StudentAPI(server: saved.server).logout(token: saved.login.token) } catch {
        self.error =
          "Auf diesem Gerät abgemeldet. Die Serverabmeldung war nicht erreichbar. Die Verwaltung kann den Zugang bei Bedarf sperren."
      }
    }
  }
#endif
