#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import StudentCore

  private let campusBlue = Color(red: 33 / 255, green: 75 / 255, blue: 118 / 255)
  private let campusCanvas = Color(red: 242 / 255, green: 243 / 255, blue: 246 / 255)
  private let campusInk = Color(red: 31 / 255, green: 47 / 255, blue: 61 / 255)

  @MainActor
  final class StudentStore: ObservableObject {
    @Published var credential: DeviceCredential?
    @Published var feed: StudentFeed?
    @Published var upcomingRows: [StudentEvent] = []
    var examRows: [StudentEvent] { upcomingRows.filter { $0.kind == "exam" } }
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
        upcomingRows = []
        selectedDate = Date()
        credential = saved
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
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
        upcomingRows = upcoming.rows
        error = nil
      } catch StudentError.expired {
        guard credential?.login.token == saved.login.token else { return }
        try? DeviceKeychain.clear()
        credential = nil
        feed = nil
        upcomingRows = []
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
      upcomingRows = []
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
    @State private var tab = 0
    @State private var noticeSearch = ""
    @State private var appeared = false
    @State private var selectedEvent: StudentEvent?
    @State private var daySummary: ScheduleDaySummary?
    @State private var calendarOpen = false

    var body: some View {
      Group {
        if store.credential != nil {
          TabView(selection: $tab) {
            home.tabItem { Label("Start", systemImage: "building.2") }.tag(0)
            schedule.tabItem { Label("Stundenplan", systemImage: "calendar") }.tag(1)
            exams.tabItem { Label("Prüfungen", systemImage: "graduationcap") }.tag(2)
            notices.tabItem { Label("Mitteilungen", systemImage: "envelope") }.tag(3)
            profile.tabItem { Label("Profil", systemImage: "person.crop.circle") }.tag(4)
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
      .tint(campusBlue)
      .preferredColorScheme(.light)
      .environment(\.locale, Locale(identifier: "de_DE"))
      .environment(\.calendar, store.calendar)
      .environment(\.timeZone, store.calendar.timeZone)
      .sheet(item: $selectedEvent) { event in
        NavigationStack {
          EventDetails(event: event)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { selectedEvent = nil }
              }
            }
        }
      }
      .sheet(item: $daySummary) { summary in
        NavigationStack {
          List {
            if summary.events.isEmpty {
              Text("Keine Veranstaltungen an diesem Tag").foregroundStyle(.secondary)
            }
            ForEach(summary.events) { event in
              NavigationLink {
                EventDetails(event: event)
              } label: {
                EventRow(event: event)
              }
            }
          }.navigationTitle(
            displayDate(summary.date, template: "EEEE, dd. MMM", zone: store.calendar.timeZone)
          )
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Fertig") { daySummary = nil } }
          }
        }
      }
      .onChange(of: store.credential?.login.token) { _, _ in
        selectedEvent = nil
        tab = 0
        noticeSearch = ""
        calendarOpen = false
        daySummary = nil
      }
      .task(id: store.credential?.login.token) {
        guard store.credential != nil else { return }
        await store.refresh()
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(60)) } catch { return }
          if scenePhase == .active { await store.refresh() }
        }
      }
      .sheet(isPresented: $calendarOpen) {
        NavigationStack {
          DatePicker("Datum auswählen", selection: $store.selectedDate, displayedComponents: .date)
            .datePickerStyle(.graphical).padding(16)
            .onChange(of: store.selectedDate) { _, _ in calendarOpen = false }
            .navigationTitle("Datum auswählen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { calendarOpen = false }
              }
            }
        }.presentationDetents([.medium, .large])
      }
      .onChange(of: store.selectedDate) { previous, next in
        if store.calendar.dateInterval(of: .weekOfYear, for: previous)?.start
          != store.calendar.dateInterval(of: .weekOfYear, for: next)?.start
        {
          Task { await store.refresh() }
        }
      }
      .onChange(of: scenePhase) { _, next in if next == .active { Task { await store.refresh() } } }
    }
    @ViewBuilder private var status: some View {
      if let error = store.error {
        Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red).font(.callout)
      }
    }
    @ViewBuilder private var header: some View {
      if store.error != nil { status.padding(.horizontal, 24).padding(.vertical, 8) }
    }
    private var groupIdentity: some View {
      Button {
        tab = 4
      } label: {
        VStack(spacing: 2) {
          Text(store.credential?.login.institution ?? "").font(.caption).foregroundStyle(.secondary)
          HStack(spacing: 6) {
            Text(store.credential?.login.scope ?? "").font(.subheadline.weight(.semibold))
              .foregroundStyle(campusInk)
            if store.busy { ProgressView().controlSize(.mini) }
          }
        }.lineLimit(1).frame(minHeight: 44)
      }.buttonStyle(.plain).accessibilityHint("Gruppenzugang und Aktualisierungsstand öffnen")
    }
    @ViewBuilder private var brandSymbol: some View {
      if let url = Bundle.module.url(forResource: "Mark", withExtension: "png"),
        let mark = UIImage(contentsOfFile: url.path)
      {
        Image(uiImage: mark).resizable().scaledToFit().frame(width: 52, height: 52)
          .frame(width: 44, height: 44).clipped().accessibilityLabel("CampusZeit")
      }
    }
    private var dateCaption: String {
      let calendar = store.calendar
      let week = ScheduleWeek(
        events: store.feed?.rows ?? [], date: store.selectedDate,
        now: Date(), calendar: calendar)
      let monday = week.days.first!
      let lastDay = week.days.last!
      let sameMonth = calendar.isDate(monday, equalTo: lastDay, toGranularity: .month)
      return displayDate(monday, template: sameMonth ? "dd." : "dd. MMM", zone: calendar.timeZone)
        + "–" + displayDate(lastDay, template: "dd. MMM", zone: calendar.timeZone)
    }
    private func moveWeek(_ step: Int) {
      store.selectedDate = store.calendar.date(
        byAdding: .day, value: step * 7, to: store.selectedDate)!
    }
    private var weekMenu: some View {
      Menu {
        Section(dateCaption) {
          Button("Vorherige Woche", systemImage: "chevron.left") { moveWeek(-1) }
          Button("Nächste Woche", systemImage: "chevron.right") { moveWeek(1) }
          Button("Diese Woche", systemImage: "calendar") {
            store.selectedDate = Date()
            Task { await store.refresh() }
          }
          Button("Datum auswählen", systemImage: "calendar.badge.clock") { calendarOpen = true }
        }
        Button("Aktualisieren", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
      } label: {
        Image(systemName: "ellipsis").frame(width: 44, height: 44)
      }.accessibilityLabel("Wochenwahl und Kalender").accessibilityValue(dateCaption)
    }
    private var schedule: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          if let feed = store.feed {
            StudentWeekGrid(
              events: feed.rows, date: store.selectedDate, calendar: store.calendar,
              selectedEvent: $selectedEvent, openCalendar: { calendarOpen = true },
              openDay: { date, rows in
                daySummary = ScheduleDaySummary(date: date, events: rows)
              }
            )
            .simultaneousGesture(
              DragGesture(minimumDistance: 40).onEnded { drag in
                let step = scheduleSwipeStep(
                  horizontal: Double(drag.translation.width),
                  vertical: Double(drag.translation.height))
                if step != 0 { moveWeek(step) }
              })
          } else if store.busy {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            StudentEmptyState(
              title: "Noch kein Stundenplan geladen", symbol: "calendar",
              detail: "Öffne das Menü oben rechts und wähle Aktualisieren."
            ).padding(24)
            Spacer()
          }
        }.background(campusCanvas).navigationTitle("").navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(.white, for: .navigationBar, .tabBar)
          .toolbarBackground(.visible, for: .navigationBar, .tabBar)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) { brandSymbol }
            ToolbarItem(placement: .principal) { groupIdentity }
            ToolbarItem(placement: .topBarTrailing) { weekMenu }
          }
      }
    }
    private var exams: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          TimelineView(.periodic(from: .now, by: 60)) { clock in
            ScrollView {
              VStack(alignment: .leading, spacing: 16) {
                Text("Prüfungen").font(.title2.weight(.semibold)).foregroundStyle(campusInk)
                if store.feed != nil {
                  let today = store.calendar.startOfDay(for: clock.date)
                  let events = store.examRows.filter { $0.end >= today }
                  let nextID = events.first { !$0.cancelled && $0.end >= clock.date }?.id
                  if events.isEmpty {
                    StudentEmptyState(
                      title: "Keine Prüfungstermine", symbol: "graduationcap",
                      detail: "Noch keine Prüfungen im geladenen Zeitraum veröffentlicht.")
                  }
                  ForEach(events) { event in
                    Button {
                      selectedEvent = event
                    } label: {
                      StudentExamCard(
                        event: event, now: clock.date, calendar: store.calendar,
                        prominent: event.id == nextID)
                    }.buttonStyle(.plain)
                  }
                  Text("Veröffentlichte Prüfungen der nächsten 120 Tage.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                } else if !store.busy {
                  StudentEmptyState(
                    title: "Noch keine Prüfungen geladen", symbol: "graduationcap",
                    detail: "Ziehe die Ansicht nach unten zum Aktualisieren.")
                }
              }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.refreshable { await store.refresh() }
          }
        }.background(campusCanvas)
          .navigationTitle("").navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(.white, for: .navigationBar, .tabBar)
          .toolbarBackground(.visible, for: .navigationBar, .tabBar)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) { brandSymbol }
            ToolbarItem(placement: .principal) { groupIdentity }
            ToolbarItem(placement: .topBarTrailing) { accountButton }
          }
      }
    }
    private var notices: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Mitteilungen suchen", text: $noticeSearch)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
            if !noticeSearch.isEmpty {
              Button {
                noticeSearch = ""
              } label: {
                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
              }
              .accessibilityLabel("Suche löschen")
            }
          }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10)).padding(16)
          List {
            if let feed = store.feed {
              let matches = feed.notices.filter {
                noticeSearch.isEmpty || $0.title.localizedStandardContains(noticeSearch)
                  || $0.body.localizedStandardContains(noticeSearch)
              }
              if matches.isEmpty {
                StudentEmptyState(
                  title: noticeSearch.isEmpty ? "Keine Mitteilungen" : "Keine Treffer",
                  symbol: "envelope",
                  detail: noticeSearch.isEmpty
                    ? "Neue Hinweise deiner Verwaltung erscheinen hier."
                    : "Versuche einen anderen Suchbegriff."
                )
                .listRowBackground(Color.white)
              }
              ForEach(matches) { notice in
                NavigationLink {
                  ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                      Text(notice.title).font(.title2.weight(.semibold))
                      Text(
                        displayDate(
                          notice.created, template: "dd. MMMM yyyy, HH:mm",
                          zone: store.calendar.timeZone)
                      ).font(.subheadline).foregroundStyle(.secondary)
                      Divider()
                      Text(notice.body).font(.body).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                  }.background(.white).navigationTitle("Mitteilung").navigationBarTitleDisplayMode(
                    .inline)
                } label: {
                  HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "envelope").foregroundStyle(campusBlue)
                      .frame(width: 40, height: 40).background(campusCanvas, in: Circle())
                      .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                      HStack(alignment: .firstTextBaseline) {
                        Text(notice.title).font(.body.weight(.semibold)).lineLimit(2)
                        Spacer(minLength: 8)
                        Text(
                          displayDate(
                            notice.created, template: "dd. MMM", zone: store.calendar.timeZone)
                        )
                        .font(.caption).foregroundStyle(.secondary)
                      }
                      Text(notice.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                  }.foregroundStyle(campusInk).padding(.vertical, 10)
                }.listRowBackground(Color.white)
              }
            } else if !store.busy {
              StudentEmptyState(
                title: "Noch keine Mitteilungen geladen", symbol: "envelope",
                detail: "Ziehe die Ansicht nach unten zum Aktualisieren."
              ).listRowBackground(Color.white)
            }
          }.listStyle(.plain).scrollContentBackground(.hidden)
            .refreshable { await store.refresh() }
        }.background(campusCanvas).navigationTitle("Mitteilungen").navigationBarTitleDisplayMode(
          .inline
        )
        .toolbarBackground(.white, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar { ToolbarItem(placement: .topBarLeading) { brandSymbol } }
      }
    }
    private var home: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          TimelineView(.periodic(from: .now, by: 60)) { clock in
            let today = store.calendar.startOfDay(for: clock.date)
            let rows = schedulePlacements(store.upcomingRows, day: today, calendar: store.calendar)
              .map(\.event)
            let next = rows.first { !$0.cancelled && $0.end > clock.date }
            ScrollView {
              VStack(alignment: .leading, spacing: 24) {
                Text(store.credential?.login.institution ?? "CampusZeit")
                  .font(.title.weight(.semibold)).foregroundStyle(campusInk)
                Button {
                  daySummary = ScheduleDaySummary(date: today, events: rows)
                } label: {
                  HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                      Text(displayDate(today, template: "EEEE", zone: store.calendar.timeZone))
                        .font(.subheadline)
                      Text(displayDate(today, template: "dd", zone: store.calendar.timeZone))
                        .font(.largeTitle.weight(.semibold).monospacedDigit()).foregroundStyle(
                          campusBlue)
                      Text(displayDate(today, template: "MMMM", zone: store.calendar.timeZone))
                        .font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                      if let next {
                        Text(next.start <= clock.date ? "Jetzt" : "Als Nächstes")
                          .font(.caption.weight(.semibold)).foregroundStyle(campusBlue)
                        Text(next.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text(
                          displayDate(next.start, template: "HH:mm", zone: store.calendar.timeZone)
                            + " – "
                            + displayDate(
                              next.end, template: "HH:mm", zone: store.calendar.timeZone)
                        )
                        .font(.subheadline.monospacedDigit())
                        if let room = next.roomNames?.first {
                          Label(room, systemImage: "door.left.hand.open").font(.subheadline)
                        }
                      } else {
                        Text(
                          store.feed == nil
                            ? (store.busy ? "Stundenplan wird geladen" : "Noch keine Daten geladen")
                            : rows.isEmpty
                              ? "Heute keine Termine" : "Heute keine weiteren Termine"
                        ).font(.headline)
                        Text(
                          store.feed == nil
                            ? "Ziehe die Ansicht zum Aktualisieren nach unten."
                            : "\(rows.count) veröffentlichte Termine heute"
                        ).font(.subheadline)
                          .foregroundStyle(.secondary)
                      }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                      .background(campusBlue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                  }.padding(20).foregroundStyle(campusInk)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                }.buttonStyle(.plain).accessibilityHint("Alle heutigen Termine öffnen")
                VStack(spacing: 0) {
                  homeLink("Mein Stundenplan", symbol: "calendar", destination: 1)
                  Divider().padding(.leading, 52)
                  homeLink("Meine Prüfungen", symbol: "graduationcap", destination: 2)
                  Divider().padding(.leading, 52)
                  homeLink("Mitteilungen", symbol: "envelope", destination: 3)
                }.background(.white, in: RoundedRectangle(cornerRadius: 14))
                Text("\(store.credential?.login.scope ?? "") · Gruppenzugang")
                  .font(.subheadline).foregroundStyle(.secondary)
              }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.refreshable { await store.refresh() }
          }
        }.background(campusCanvas).navigationTitle("").navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(.white, for: .navigationBar, .tabBar)
          .toolbarBackground(.visible, for: .navigationBar, .tabBar)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) { brandSymbol }
            ToolbarItem(placement: .principal) { groupIdentity }
          }
      }
    }
    private func homeLink(_ title: String, symbol: String, destination: Int) -> some View {
      Button {
        if destination == 1 { store.selectedDate = Date() }
        tab = destination
      } label: {
        HStack(spacing: 16) {
          Image(systemName: symbol).font(.title3).foregroundStyle(campusBlue).frame(width: 24)
          Text(title).font(.body).foregroundStyle(campusInk)
          Spacer()
          Image(systemName: "chevron.right").foregroundStyle(.secondary).font(.subheadline)
        }.padding(18).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
          .contentShape(Rectangle())
      }.buttonStyle(.plain)
    }
    private var profile: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          Form {
            Section {
              HStack(spacing: 16) {
                Image(systemName: "person.2").font(.title2).foregroundStyle(campusBlue)
                  .frame(width: 52, height: 52).background(campusCanvas, in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                  Text(store.credential?.login.scope ?? "").font(.title3.weight(.semibold))
                  Text(store.credential?.login.institution ?? "").font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text("Gemeinsamer Gruppenzugang").font(.caption).foregroundStyle(campusBlue)
                }
              }.padding(.vertical, 8)
            }
            Section("Verbindung") {
              LabeledContent("Server", value: store.credential?.server.host ?? "")
              if let feed = store.feed {
                LabeledContent(
                  "Aktualisiert",
                  value: displayDate(
                    feed.updated,
                    template: "dd.MM.yyyy, HH:mm", zone: store.calendar.timeZone))
              }
              Button("Jetzt aktualisieren", systemImage: "arrow.clockwise") {
                Task { await store.refresh() }
              }.disabled(store.busy)
            }
            Section("Über CampusZeit") {
              Text("Stundenplan, Prüfungen und Mitteilungen deiner Verwaltung.")
              Text(
                "Dieser Zugang wird gemeinsam von der Gruppe genutzt. Persönliche Noten und Teilnehmerlisten werden nicht angezeigt."
              )
              .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
              Button(
                "Auf diesem Gerät abmelden", systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive
              ) {
                Task { await store.logout() }
              }
            }
          }.scrollContentBackground(.hidden)
        }.background(campusCanvas).navigationTitle("Mein Zugang").navigationBarTitleDisplayMode(
          .large
        )
        .toolbarBackground(.white, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar { ToolbarItem(placement: .topBarLeading) { brandSymbol } }
      }
    }
    private var accountButton: some View {
      Button {
        tab = 4
      } label: {
        Image(systemName: "person.crop.circle")
      }.accessibilityLabel("Mein Zugang")
    }

  }

  private struct ScheduleDaySummary: Identifiable {
    let date: Date
    let events: [StudentEvent]
    var id: Date { date }
  }

  private func eventTint(_ event: StudentEvent) -> Color {
    let colors = [
      campusBlue, Color(red: 0.18, green: 0.43, blue: 0.33),
      Color(red: 0.53, green: 0.36, blue: 0.12),
    ]
    if event.cancelled { return Color(red: 0.7, green: 0.13, blue: 0.17) }
    if event.kind == "exam" { return colors[2] }
    return colors[event.name.utf8.reduce(0) { ($0 + Int($1)) % colors.count }]
  }

  private struct StudentWeekGrid: View {
    let events: [StudentEvent]
    let date: Date
    let calendar: Calendar
    @Binding var selectedEvent: StudentEvent?
    let openCalendar: () -> Void
    let openDay: (Date, [StudentEvent]) -> Void
    @ScaledMetric(relativeTo: .caption) private var axisWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var headerHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .footnote) private var footerHeight: CGFloat = 44

    var body: some View {
      TimelineView(.periodic(from: .now, by: 60)) { clock in
        let week = ScheduleWeek(events: events, date: date, now: clock.date, calendar: calendar)
        GeometryReader { viewport in
          let axis = min(axisWidth, 72)
          let column = max(1, (viewport.size.width - 16 - axis) / CGFloat(week.days.count))
          let plotHeight = max(1, viewport.size.height - headerHeight - footerHeight - 8)
          let scale = plotHeight / CGFloat((week.endHour - week.startHour) * 60)
          let today = week.days.first { calendar.isDate($0, inSameDayAs: clock.date) }
          let nowMinutes = today.map {
            clock.date.timeIntervalSince(
              calendar.date(
                bySettingHour: week.startHour, minute: 0,
                second: 0, of: $0)!) / 60
          }
          VStack(spacing: 0) {
            HStack(spacing: 0) {
              Button(action: openCalendar) {
                VStack(alignment: .leading, spacing: 4) {
                  Text("KW \(calendar.component(.weekOfYear, from: week.days[0]))").font(.caption)
                  Text(displayDate(week.days[0], template: "MMM", zone: calendar.timeZone))
                    .font(.subheadline.weight(.semibold))
                }.frame(width: axis, height: headerHeight, alignment: .leading)
                  .foregroundStyle(.secondary)
              }.buttonStyle(.plain).accessibilityLabel("Kalender öffnen")
                .accessibilityValue(
                  displayDate(week.days[0], template: "MMMM yyyy", zone: calendar.timeZone))
              ForEach(week.days.indices, id: \.self) { index in
                let day = week.days[index]
                Button {
                  openDay(day, week.placements[index].map(\.event))
                } label: {
                  VStack(spacing: 4) {
                    Text(displayDate(day, template: "EE", zone: calendar.timeZone)).font(.caption)
                    Text(displayDate(day, template: "dd", zone: calendar.timeZone))
                      .font(.subheadline.weight(.semibold).monospacedDigit())
                  }.frame(width: column, height: headerHeight)
                    .foregroundStyle(
                      calendar.isDate(day, inSameDayAs: clock.date)
                        ? campusBlue : campusInk.opacity(0.75)
                    )
                    .background(
                      calendar.isDate(day, inSameDayAs: clock.date)
                        ? campusBlue.opacity(0.08) : Color.white)
                }.buttonStyle(.plain)
                  .accessibilityLabel(
                    displayDate(day, template: "EEEE, dd. MMMM", zone: calendar.timeZone)
                  )
                  .accessibilityHint("Alle Termine dieses Tages anzeigen")
              }
            }.frame(height: headerHeight).background(.white)
            HStack(spacing: 0) {
              ZStack(alignment: .topLeading) {
                ForEach(week.startHour..<week.endHour, id: \.self) { hour in
                  Text(String(format: "%02d:00", hour)).font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary).lineLimit(1)
                    .opacity(
                      nowMinutes.map { abs($0 - Double((hour - week.startHour) * 60)) < 15 } == true
                        ? 0 : 1
                    )
                    .offset(y: CGFloat((hour - week.startHour) * 60) * scale)
                }
              }.frame(width: axis, height: plotHeight, alignment: .topLeading).accessibilityHidden(
                true)
              ForEach(week.days.indices, id: \.self) { index in
                dayColumn(
                  week: week, index: index, width: column, height: plotHeight,
                  scale: scale, now: clock.date)
              }
            }.frame(height: plotHeight)
              .overlay(alignment: .topLeading) {
                if let minutes = nowMinutes {
                  HStack(spacing: 0) {
                    Text(displayDate(clock.date, template: "HH:mm", zone: calendar.timeZone))
                      .font(.caption.weight(.semibold).monospacedDigit())
                      .foregroundStyle(Color(red: 0.7, green: 0.13, blue: 0.17))
                      .frame(width: axis, alignment: .leading).background(campusCanvas)
                    Rectangle().fill(.red).frame(height: 1)
                  }.frame(height: 20).offset(y: CGFloat(minutes) * scale - 10)
                    .allowsHitTesting(false)
                    .accessibilityLabel(
                      "Aktuelle Uhrzeit \(displayDate(clock.date, template: "HH:mm", zone: calendar.timeZone))"
                    )
                }
              }
            Menu {
              ForEach(week.days.indices, id: \.self) { index in
                Button(
                  displayDate(week.days[index], template: "EEEE, dd. MMM", zone: calendar.timeZone)
                ) {
                  openDay(week.days[index], week.placements[index].map(\.event))
                }
              }
            } label: {
              Label("Termine & Details", systemImage: "list.bullet").font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: footerHeight)
            }
          }.padding(.horizontal, 8).padding(.bottom, 8).background(campusCanvas)
        }
      }
    }
    private func dayColumn(
      week: ScheduleWeek, index: Int, width: CGFloat,
      height: CGFloat, scale: CGFloat, now: Date
    ) -> some View {
      let day = week.days[index]
      let start = calendar.date(bySettingHour: week.startHour, minute: 0, second: 0, of: day)!
      let rows = week.placements[index]
      return ZStack(alignment: .topLeading) {
        Rectangle().fill(campusBlue.opacity(calendar.isDate(day, inSameDayAs: now) ? 0.025 : 0))
        ForEach(week.startHour..<week.endHour, id: \.self) { hour in
          Rectangle().fill(campusBlue.opacity(0.10)).frame(width: width, height: 0.5)
            .offset(y: CGFloat((hour - week.startHour) * 60) * scale)
        }
        ForEach(rows) { item in
          let lane = width / CGFloat(item.lanes)
          let blockHeight = CGFloat(item.end.timeIntervalSince(item.start) / 60) * scale
          let tint = eventTint(item.event)
          VStack(alignment: .leading, spacing: 3) {
            if blockHeight >= 20 {
              Text(scheduleShortTitle(item.event.name)).font(.subheadline.weight(.semibold))
                .strikethrough(item.event.cancelled).lineLimit(1)
              if blockHeight >= 48, let teacher = item.event.teacherNames?.first {
                Text(scheduleShortTitle(teacher)).font(.caption).lineLimit(1)
                  .strikethrough(item.event.cancelled)
              }
              if blockHeight >= 68, let room = item.event.roomNames?.first {
                Text(room.replacingOccurrences(of: " ", with: "")).font(.caption).lineLimit(1)
                  .strikethrough(item.event.cancelled)
              }
              Spacer(minLength: 0)
              if blockHeight >= 96 {
                Image(systemName: item.event.cancelled ? "xmark.circle.fill" : "info.circle")
                  .font(.caption).foregroundStyle(tint).frame(
                    maxWidth: .infinity, alignment: .trailing)
              }
            }
          }.padding(.leading, 6).padding(.trailing, 3).padding(.vertical, blockHeight >= 40 ? 6 : 1)
            .frame(width: max(1, lane - 4), height: max(1, blockHeight - 4), alignment: .topLeading)
            .foregroundStyle(item.event.cancelled ? tint : campusInk)
            .background(item.event.cancelled ? tint.opacity(0.05) : Color.white)
            .overlay(alignment: .leading) { Rectangle().fill(tint.opacity(0.7)).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
              RoundedRectangle(cornerRadius: 4).stroke(
                item.event.cancelled ? tint : campusInk.opacity(0.12),
                lineWidth: item.event.cancelled ? 1.5 : 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            .offset(
              x: CGFloat(item.lane) * lane + 1,
              y: CGFloat(item.start.timeIntervalSince(start) / 60) * scale + 1)
        }
      }.frame(width: width, height: height).clipped()
        .overlay(alignment: .trailing) {
          Rectangle().fill(campusBlue.opacity(0.10)).frame(width: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 1, coordinateSpace: .local) { point in
          let time = start.addingTimeInterval(Double(point.y / scale) * 60)
          if let event = scheduleHit(
            rows, time: time, laneFraction: Double(point.x / width),
            tolerance: Double(22 / scale) * 60)
          {
            selectedEvent = event
          } else {
            openDay(day, rows.map(\.event))
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(displayDate(day, template: "EEEE, dd. MMMM", zone: calendar.timeZone)), \(rows.count) Termine"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { openDay(day, rows.map(\.event)) }
    }
  }

  private struct StudentExamCard: View {
    let event: StudentEvent
    let now: Date
    let calendar: Calendar
    let prominent: Bool
    @ScaledMetric(relativeTo: .body) private var badgeWidth: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var badgeHeight: CGFloat = 64
    var body: some View {
      let ink = event.cancelled ? Color(red: 0.7, green: 0.13, blue: 0.17) : campusInk
      let accent = event.cancelled ? Color(red: 0.7, green: 0.13, blue: 0.17) : campusBlue
      return VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(prominent ? "Nächste Prüfung" : "Prüfungstermin")
            .font(.caption.weight(.semibold)).foregroundStyle(accent)
          Spacer()
          Text(
            event.cancelled
              ? "Abgesagt"
              : event.end < now
                ? "Beendet"
                : examCountdown(to: event.start, now: now, calendar: calendar)
          )
          .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
          .padding(.horizontal, 10).padding(.vertical, 5)
          .background(accent.opacity(0.08), in: Capsule())
        }
        HStack(alignment: .top, spacing: 14) {
          VStack(spacing: 4) {
            Text(displayDate(event.start, template: "dd", zone: calendar.timeZone))
              .font(.title2.weight(.semibold).monospacedDigit())
            Text(displayDate(event.start, template: "MMM", zone: calendar.timeZone).uppercased())
              .font(.caption.weight(.semibold))
          }.frame(width: badgeWidth, height: badgeHeight).foregroundStyle(accent)
            .background(
              accent.opacity(prominent ? 0.12 : 0.06),
              in: RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 8) {
            Text(event.name).font(prominent ? .title3.weight(.semibold) : .body.weight(.semibold))
              .strikethrough(event.cancelled).fixedSize(horizontal: false, vertical: true)
            Text(displayDate(event.start, template: "EEEE, yyyy", zone: calendar.timeZone))
              .font(.subheadline).foregroundStyle(.secondary)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
        VStack(alignment: .leading, spacing: 8) {
          Label(
            "\(displayDate(event.start, template: "HH:mm", zone: calendar.timeZone)) – \(displayDate(event.end, template: "HH:mm", zone: calendar.timeZone))",
            systemImage: "clock")
          if let rooms = event.roomNames, !rooms.isEmpty {
            Label(rooms.joined(separator: ", "), systemImage: "door.left.hand.open")
          }
        }.font(.subheadline).foregroundStyle(ink.opacity(0.85))
      }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(ink).background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
          if prominent {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3).padding(.vertical, 18)
          }
        }
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
    }
  }

  struct EventRow: View {
    let event: StudentEvent
    @Environment(\.timeZone) private var zone
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth: CGFloat = 56
    var body: some View {
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(displayDate(event.start, template: "HH:mm", zone: zone))
            .font(.subheadline.weight(.semibold).monospacedDigit())
          Text(displayDate(event.end, template: "HH:mm", zone: zone))
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }.frame(width: timeWidth, alignment: .leading)
          .foregroundStyle(event.cancelled ? Color(red: 0.7, green: 0.13, blue: 0.17) : campusBlue)
        VStack(alignment: .leading, spacing: 8) {
          Text(event.name).font(.body.weight(.medium)).strikethrough(event.cancelled)
            .fixedSize(horizontal: false, vertical: true)
          if event.cancelled {
            Label("Abgesagt", systemImage: "xmark.circle").font(.subheadline.weight(.medium))
          } else if event.kind == "exam" {
            Text("Prüfung").font(.caption.weight(.medium)).foregroundStyle(.secondary)
          }
          if let rooms = event.roomNames, !rooms.isEmpty {
            Label(rooms.joined(separator: ", "), systemImage: "door.left.hand.open")
              .font(.footnote).foregroundStyle(.secondary)
          }
        }
      }.foregroundStyle(event.cancelled ? Color(red: 0.7, green: 0.13, blue: 0.17) : campusInk)
        .padding(.vertical, 16)
    }
  }
  private struct StudentEmptyState: View {
    let title: String
    let symbol: String
    let detail: String
    var body: some View {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: symbol).font(.title3).foregroundStyle(campusBlue)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
          Text(title).font(.body.weight(.medium)).foregroundStyle(campusInk)
          Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
      }.padding(.vertical, 24)
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
      }.scrollContentBackground(.hidden).background(campusCanvas)
        .navigationTitle("Termindetails").navigationBarTitleDisplayMode(.inline)
    }
  }
#endif
