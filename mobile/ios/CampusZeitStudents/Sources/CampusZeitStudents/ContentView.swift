#if canImport(UIKit)
  import SwiftUI
  import StudentCore

  @MainActor
  final class StudentStore: ObservableObject {
    @Published var credential: DeviceCredential?
    @Published var feed: StudentFeed?
    @Published var examRows: [StudentEvent] = []
    @Published var busy = false
    @Published var error: String?
    @Published var selectedDate = Date()
    var calendar: Calendar { institutionCalendar(credential?.login.timezone ?? "Europe/Berlin") }

    init() {
      do {
        if let saved = try DeviceKeychain.read() {
          _ = try serverURL(saved.server.absoluteString)
          if saved.login.expires > Date() { credential = saved } else { try DeviceKeychain.clear() }
        }
      } catch { self.error = error.localizedDescription }
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
        do { try DeviceKeychain.save(saved) } catch {
          try? await api.logout(token: reply.token)
          throw error
        }
        feed = nil
        examRows = []
        selectedDate = Date()
        credential = saved
      } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
      guard let saved = credential, !busy else { return }
      let requestedDate = selectedDate
      busy = true
      defer {
        busy = false
        if selectedDate != requestedDate { Task { await refresh() } }
      }
      do {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)!.start
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        let today = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: 120, to: today)!
        let api = StudentAPI(server: saved.server)
        async let week = api.feed(
          token: saved.login.token, start: start, end: end, zone: saved.login.timezone)
        async let future = api.feed(
          token: saved.login.token, start: today, end: horizon, zone: saved.login.timezone)
        let (result, upcoming) = try await (week, future)
        guard credential?.login.token == saved.login.token else { return }
        feed = result
        examRows = upcoming.rows.filter { $0.kind == "exam" }
        error = nil
      } catch StudentError.expired {
        guard credential?.login.token == saved.login.token else { return }
        try? DeviceKeychain.clear()
        credential = nil
        feed = nil
        examRows = []
        error = StudentError.expired.localizedDescription
      } catch is CancellationError {} catch {
        if credential?.login.token == saved.login.token { self.error = error.localizedDescription }
      }
    }
    func logout() async {
      guard let saved = credential else { return }
      do { try DeviceKeychain.clear() } catch {
        self.error = error.localizedDescription
        return
      }
      credential = nil
      feed = nil
      examRows = []
      error = nil
      do { try await StudentAPI(server: saved.server).logout(token: saved.login.token) } catch {
        self.error =
          "Auf diesem Gerät abgemeldet. Die Serverabmeldung war nicht erreichbar. Die Verwaltung kann den Zugang bei Bedarf sperren."
      }
    }
  }

  struct ContentView: View {
    @StateObject private var store = StudentStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var account = false
    @State private var appeared = false
    private let blue = Color(red: 33 / 255, green: 75 / 255, blue: 118 / 255)

    var body: some View {
      Group {
        if store.credential != nil {
          TabView {
            schedule.tabItem { Label("Stundenplan", systemImage: "calendar") }
            exams.tabItem { Label("Prüfungen", systemImage: "graduationcap") }
            notices.tabItem { Label("Mitteilungen", systemImage: "bell") }
          }
        } else {
          StudentLogin(store: store)
        }
      }
      .opacity(appeared ? 1 : 0)
      .offset(y: appeared || reduceMotion ? 0 : 10)
      .onAppear {
        if reduceMotion {
          appeared = true
        } else {
          withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
      }
      .tint(blue)
      .environment(\.locale, Locale(identifier: "de_DE"))
      .environment(\.calendar, store.calendar)
      .environment(\.timeZone, store.calendar.timeZone)
      .sheet(isPresented: $account) {
        NavigationStack {
          Form {
            Section("Gruppenzugang") {
              LabeledContent("Einrichtung", value: store.credential?.login.institution ?? "")
              LabeledContent("Gruppe / Jahrgang", value: store.credential?.login.scope ?? "")
              LabeledContent("Server", value: store.credential?.server.host ?? "")
            }
            Section {
              Text(
                "Dieser Zugang wird gemeinsam von der Gruppe genutzt. Persönliche Noten und Teilnehmerlisten werden nicht angezeigt."
              )
              Button("Auf diesem Gerät abmelden", role: .destructive) {
                account = false
                Task { await store.logout() }
              }
            }
          }
          .navigationTitle("Mein Zugang")
          .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Fertig") { account = false } }
          }
        }
      }
      .task(id: store.credential?.login.token) {
        guard store.credential != nil else { return }
        await store.refresh()
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(60)) } catch { return }
          if scenePhase == .active { await store.refresh() }
        }
      }
      .onChange(of: scenePhase) { _, next in if next == .active { Task { await store.refresh() } } }
    }
    @ViewBuilder private var status: some View {
      if let error = store.error { Text(error).foregroundStyle(.red).font(.callout) }
      if let feed = store.feed {
        Text(
          "Stand: \(displayDate(feed.updated, template: "dd.MM., HH:mm", zone: store.calendar.timeZone))"
        ).font(
          .caption
        ).foregroundStyle(.secondary)
      }
      if store.busy { ProgressView("Wird aktualisiert …") }
    }
    private var header: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(store.credential?.login.scope ?? "").font(.headline)
        Text(store.credential?.login.institution ?? "").font(.subheadline).foregroundStyle(
          .secondary)
        status
      }.padding(.vertical, 4)
    }
    private var schedule: some View {
      NavigationStack {
        List {
          Section { header }
          Section {
            HStack {
              Button {
                moveWeek(-1)
              } label: {
                Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
              }.accessibilityLabel("Vorherige Woche")
              DatePicker("Datum", selection: $store.selectedDate, displayedComponents: .date)
                .onChange(of: store.selectedDate) { _, _ in Task { await store.refresh() } }
              Button {
                moveWeek(1)
              } label: {
                Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
              }.accessibilityLabel("Nächste Woche")
            }.buttonStyle(.borderless)
            Button("Diese Woche") { store.selectedDate = Date() }
          }
          if let feed = store.feed {
            let monday = store.calendar.dateInterval(of: .weekOfYear, for: store.selectedDate)!
              .start
            ForEach(0..<7, id: \.self) { offset in
              let day = store.calendar.date(byAdding: .day, value: offset, to: monday)!
              let next = store.calendar.date(byAdding: .day, value: 1, to: day)!
              let events = feed.rows.filter { $0.start < next && $0.end > day }
              Section(displayDate(day, template: "EEEE, dd. MMM", zone: store.calendar.timeZone)) {
                if events.isEmpty { Text("Keine Veranstaltungen").foregroundStyle(.secondary) }
                ForEach(events) { event in
                  NavigationLink {
                    EventDetails(event: event)
                  } label: {
                    EventRow(event: event)
                  }
                }
              }
            }
          } else if !store.busy {
            ContentUnavailableView(
              "Noch kein Stundenplan geladen", systemImage: "calendar",
              description: Text("Ziehe die Ansicht nach unten zum Aktualisieren."))
          }
        }
        .navigationTitle("Stundenplan")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { accountButton } }
        .refreshable { await store.refresh() }
      }
    }
    private var exams: some View {
      NavigationStack {
        List {
          Section { header }
          if store.feed != nil {
            let today = store.calendar.startOfDay(for: Date())
            let events = store.examRows.filter { $0.end >= today }
            Section("Freigegebene Prüfungstermine") {
              if events.isEmpty {
                Text("Im geladenen Zeitraum sind keine Prüfungen veröffentlicht.").foregroundStyle(
                  .secondary)
              }
              ForEach(events) { event in
                NavigationLink {
                  EventDetails(event: event)
                } label: {
                  VStack(alignment: .leading, spacing: 6) {
                    Text(
                      displayDate(
                        event.start, template: "EEE, dd. MMM yyyy", zone: store.calendar.timeZone)
                    ).font(
                      .subheadline
                    ).foregroundStyle(.secondary)
                    EventRow(event: event)
                  }
                }
              }
            }
            Section {
              Text(
                "Zeitraum: heute und die nächsten 120 Tage. Weitere Prüfungen erscheinen nach Veröffentlichung."
              ).font(.footnote).foregroundStyle(.secondary)
            }
          }
        }
        .navigationTitle("Prüfungen")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { accountButton } }
        .refreshable { await store.refresh() }
      }
    }
    private var notices: some View {
      NavigationStack {
        List {
          Section { header }
          if let feed = store.feed {
            if feed.notices.isEmpty {
              ContentUnavailableView(
                "Keine Mitteilungen", systemImage: "bell",
                description: Text("Neue Hinweise deiner Verwaltung erscheinen hier."))
            }
            ForEach(feed.notices) { notice in
              Section {
                Text(notice.title).font(.headline)
                Text(notice.body).textSelection(.enabled)
                Text(
                  displayDate(
                    notice.created, template: "dd.MM.yyyy, HH:mm", zone: store.calendar.timeZone)
                ).font(
                  .caption
                ).foregroundStyle(.secondary)
              }
            }
          }
        }
        .navigationTitle("Mitteilungen")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { accountButton } }
        .refreshable { await store.refresh() }
      }
    }
    private var accountButton: some View {
      Button {
        account = true
      } label: {
        Image(systemName: "person.crop.circle")
      }.accessibilityLabel("Mein Zugang")
    }
    private func moveWeek(_ offset: Int) {
      store.selectedDate = store.calendar.date(
        byAdding: .day, value: offset * 7, to: store.selectedDate)!
    }
  }

  struct EventRow: View {
    let event: StudentEvent
    @Environment(\.timeZone) private var zone
    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(
            "\(displayDate(event.start, template: "HH:mm", zone: zone))–\(displayDate(event.end, template: "HH:mm", zone: zone))"
          ).font(.subheadline.monospacedDigit())
          if event.cancelled {
            Text("Abgesagt").font(.caption.bold())
          } else if event.kind == "exam" {
            Text("Prüfung").font(.caption.bold())
          }
        }
        Text(event.name).font(.headline).strikethrough(event.cancelled)
        if let rooms = event.roomNames, !rooms.isEmpty {
          Label(rooms.joined(separator: ", "), systemImage: "mappin.and.ellipse").font(.subheadline)
        }
      }.foregroundStyle(event.cancelled ? Color.red : Color.primary).padding(.vertical, 4)
    }
  }
  struct EventDetails: View {
    let event: StudentEvent
    @Environment(\.timeZone) private var zone
    var body: some View {
      List {
        Section { EventRow(event: event) }
        Section {
          LabeledContent(
            "Datum", value: displayDate(event.start, template: "dd.MM.yyyy", zone: zone))
          LabeledContent(
            "Dauer", value: "\(Int(event.end.timeIntervalSince(event.start) / 60)) Minuten")
          LabeledContent("Art", value: event.kind == "exam" ? "Prüfung" : "Lehrveranstaltung")
        }
        if let teachers = event.teacherNames, !teachers.isEmpty {
          Section("Lehrende / Aufsicht") { ForEach(teachers, id: \.self) { Text($0) } }
        }
        if let groups = event.groupNames, !groups.isEmpty {
          Section(event.kind == "exam" ? "Prüfungsangaben" : "Gruppen") {
            ForEach(groups, id: \.self) { Text($0) }
          }
        }
      }.navigationTitle("Termindetails").navigationBarTitleDisplayMode(.inline)
    }
  }
#endif
