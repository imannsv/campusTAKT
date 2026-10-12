#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import StudentCore

  private let campusBlue = Color(red: 33 / 255, green: 75 / 255, blue: 118 / 255)
  private let campusCanvas = Color.white
  private let campusInk = Color(red: 31 / 255, green: 47 / 255, blue: 61 / 255)

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
    @State private var selectedEvent: StudentEvent?
    @State private var daySummary: ScheduleDaySummary?
    @State private var calendarOpen = false

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
      .tint(campusBlue)
      .preferredColorScheme(.light)
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
              if let feed = store.feed {
                LabeledContent(
                  "Aktualisiert",
                  value: displayDate(
                    feed.updated,
                    template: "dd.MM.yyyy, HH:mm", zone: store.calendar.timeZone))
              }
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
        account = false
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
        account = true
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
      let monday = calendar.dateInterval(of: .weekOfYear, for: store.selectedDate)!.start
      let saturday = calendar.date(byAdding: .day, value: 5, to: monday)!
      let sameMonth = calendar.isDate(monday, equalTo: saturday, toGranularity: .month)
      return displayDate(monday, template: sameMonth ? "dd." : "dd. MMM", zone: calendar.timeZone)
        + "–" + displayDate(saturday, template: "dd. MMM", zone: calendar.timeZone)
    }
    private var dateButton: some View {
      Button {
        calendarOpen = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "calendar").foregroundStyle(campusBlue)
          Text(dateCaption)
            .foregroundStyle(campusInk)
        }.font(.subheadline.weight(.medium)).frame(minHeight: 44)
      }.buttonStyle(.plain).accessibilityLabel("Datum auswählen")
        .accessibilityValue(
          displayDate(store.selectedDate, template: "dd. MMMM yyyy", zone: store.calendar.timeZone))
    }
    private var currentWeekButton: some View {
      Button("Diese Woche") {
        store.selectedDate = Date()
        Task { await store.refresh() }
      }.font(.subheadline.weight(.medium)).frame(minHeight: 44)
    }
    private func moveWeek(_ step: Int) {
      store.selectedDate = store.calendar.date(
        byAdding: .day, value: step * 7, to: store.selectedDate)!
    }
    private var weekNavigation: some View {
      HStack(spacing: 4) {
        Button {
          moveWeek(-1)
        } label: {
          Image(systemName: "chevron.left").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Vorherige Woche")
        dateButton.frame(maxWidth: .infinity)
        Button {
          moveWeek(1)
        } label: {
          Image(systemName: "chevron.right").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Nächste Woche")
      }.buttonStyle(.plain)
    }
    private var weekControls: some View {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) {
          weekNavigation
          currentWeekButton
        }
        VStack(spacing: 0) {
          weekNavigation
          currentWeekButton
        }
      }.padding(.horizontal, 12).padding(.bottom, 4)
    }
    private var schedule: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          weekControls
          if let feed = store.feed {
            StudentWeekGrid(
              events: feed.rows, date: store.selectedDate, calendar: store.calendar,
              selectedEvent: $selectedEvent,
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
              detail: "Tippe auf Diese Woche zum Aktualisieren."
            ).padding(24)
            Spacer()
          }
        }.background(campusCanvas).navigationTitle("").navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(campusCanvas, for: .navigationBar, .tabBar)
          .toolbarBackground(.visible, for: .navigationBar, .tabBar)
          .toolbar {
            ToolbarItem(placement: .topBarLeading) { brandSymbol }
            ToolbarItem(placement: .principal) { groupIdentity }
            ToolbarItem(placement: .topBarTrailing) { accountButton }
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
        }.background(Color(red: 0.96, green: 0.97, blue: 0.98))
          .navigationTitle("").navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(campusCanvas, for: .navigationBar, .tabBar)
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
          List {
            if let feed = store.feed {
              if feed.notices.isEmpty {
                StudentEmptyState(
                  title: "Keine Mitteilungen", symbol: "bell",
                  detail: "Neue Hinweise deiner Verwaltung erscheinen hier."
                )
                .listRowBackground(campusCanvas).listRowSeparatorTint(campusBlue.opacity(0.12))
              }
              ForEach(feed.notices) { notice in
                VStack(alignment: .leading, spacing: 10) {
                  Text(notice.title).font(.headline).foregroundStyle(campusInk)
                  Text(notice.body).textSelection(.enabled)
                  Text(
                    displayDate(
                      notice.created, template: "dd.MM.yyyy, HH:mm", zone: store.calendar.timeZone)
                  ).font(
                    .caption
                  ).foregroundStyle(.secondary)
                }.padding(.vertical, 16).listRowBackground(campusCanvas).listRowSeparatorTint(
                  campusBlue.opacity(0.12))
              }
            } else if !store.busy {
              StudentEmptyState(
                title: "Noch keine Mitteilungen geladen", symbol: "bell",
                detail: "Ziehe die Ansicht nach unten zum Aktualisieren."
              )
              .listRowBackground(campusCanvas).listRowSeparatorTint(campusBlue.opacity(0.12))
            }
          }.listStyle(.plain).listRowSpacing(0)
            .contentMargins(.horizontal, 8, for: .scrollContent).scrollContentBackground(.hidden)
            .refreshable { await store.refresh() }
        }
        .background(campusCanvas).navigationTitle("Mitteilungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(campusCanvas, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) { brandSymbol }
          ToolbarItem(placement: .principal) { groupIdentity }
          ToolbarItem(placement: .topBarTrailing) { accountButton }
        }
      }
    }
    private var accountButton: some View {
      Button {
        account = true
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
    let openDay: (Date, [StudentEvent]) -> Void
    @ScaledMetric(relativeTo: .caption) private var axisWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .subheadline) private var headerHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .footnote) private var footerHeight: CGFloat = 44

    var body: some View {
      TimelineView(.periodic(from: .now, by: 60)) { clock in
        let week = ScheduleWeek(events: events, date: date, now: clock.date, calendar: calendar)
        GeometryReader { viewport in
          let axis = min(axisWidth, 72)
          let column = max(1, (viewport.size.width - 16 - axis) / 6)
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
              Color.clear.frame(width: axis)
              ForEach(week.days.indices, id: \.self) { index in
                let day = week.days[index]
                Button {
                  openDay(day, week.placements[index].map(\.event))
                } label: {
                  VStack(spacing: 4) {
                    Text(displayDate(day, template: "EE", zone: calendar.timeZone)).font(.caption)
                    Text(displayDate(day, template: "dd", zone: calendar.timeZone))
                      .font(.subheadline.weight(.semibold).monospacedDigit())
                  }.frame(width: column, height: headerHeight).foregroundStyle(campusBlue)
                    .background(
                      campusBlue.opacity(
                        calendar.isDate(day, inSameDayAs: clock.date) ? 0.10 : 0.025))
                }.buttonStyle(.plain)
                  .accessibilityLabel(
                    displayDate(day, template: "EEEE, dd. MMMM", zone: calendar.timeZone)
                  )
                  .accessibilityHint("Alle Termine dieses Tages anzeigen")
              }
            }.frame(height: headerHeight)
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
          }.padding(.horizontal, 8).padding(.bottom, 8)
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
          VStack(spacing: 4) {
            if blockHeight >= 20 {
              Text(scheduleShortTitle(item.event.name)).font(.subheadline.weight(.semibold))
                .strikethrough(item.event.cancelled).lineLimit(1)
              if blockHeight >= 48, let room = item.event.roomNames?.first {
                Text(room.replacingOccurrences(of: " ", with: "")).font(.caption).lineLimit(1)
              }
              if item.event.cancelled && blockHeight >= 70 { Image(systemName: "xmark.circle") }
            }
          }.padding(.horizontal, 2).frame(width: max(1, lane - 2), height: max(1, blockHeight - 2))
            .foregroundStyle(tint).background(tint.opacity(0.14))
            .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
      let ink =
        prominent
        ? Color.white : event.cancelled ? Color(red: 0.7, green: 0.13, blue: 0.17) : campusInk
      let accent = event.cancelled ? Color(red: 0.7, green: 0.13, blue: 0.17) : campusBlue
      return VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(prominent ? "Nächste Prüfung" : "Prüfungstermin")
            .font(.caption.weight(.semibold)).foregroundStyle(
              prominent ? .white.opacity(0.85) : accent)
          Spacer()
          Text(
            event.cancelled
              ? "Abgesagt"
              : event.end < now
                ? "Beendet"
                : examCountdown(to: event.start, now: now, calendar: calendar)
          )
          .font(.subheadline.weight(.semibold)).foregroundStyle(prominent ? .white : accent)
        }
        HStack(alignment: .top, spacing: 14) {
          VStack(spacing: 4) {
            Text(displayDate(event.start, template: "dd", zone: calendar.timeZone))
              .font(.title2.weight(.semibold).monospacedDigit())
            Text(displayDate(event.start, template: "MMM", zone: calendar.timeZone).uppercased())
              .font(.caption.weight(.semibold))
          }.frame(width: badgeWidth, height: badgeHeight).foregroundStyle(
            prominent ? .white : accent
          )
          .background(
            prominent ? Color.white.opacity(0.13) : accent.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10))
          VStack(alignment: .leading, spacing: 8) {
            Text(event.name).font(prominent ? .title3.weight(.semibold) : .body.weight(.semibold))
              .strikethrough(event.cancelled).fixedSize(horizontal: false, vertical: true)
            Text(displayDate(event.start, template: "EEEE, yyyy", zone: calendar.timeZone))
              .font(.subheadline).foregroundStyle(prominent ? Color.white.opacity(0.85) : campusInk.opacity(0.75))
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
        .foregroundStyle(ink).background(
          prominent ? campusBlue : .white,
          in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14).stroke(prominent ? .clear : accent.opacity(0.12))
        )
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
