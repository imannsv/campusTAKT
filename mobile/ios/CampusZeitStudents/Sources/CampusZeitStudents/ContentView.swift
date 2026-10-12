#if canImport(UIKit)
  import SwiftUI
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
    @State private var focusNow = 0
    @ScaledMetric(relativeTo: .subheadline) private var dayWidth: CGFloat = 44

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
      .onChange(of: store.credential?.login.token) { _, _ in
        selectedEvent = nil
        account = false
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
    private var dateNavigation: some View {
      HStack(spacing: 4) {
        Button {
          moveWeek(-1)
        } label: {
          Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
        }.accessibilityLabel("Vorherige Woche")
        DatePicker("Datum auswählen", selection: $store.selectedDate, displayedComponents: .date)
          .labelsHidden().datePickerStyle(.compact)
          .onChange(of: store.selectedDate) { previous, next in
            if store.calendar.dateInterval(of: .weekOfYear, for: previous)?.start
              != store.calendar.dateInterval(of: .weekOfYear, for: next)?.start
            {
              Task { await store.refresh() }
            }
          }
        Button {
          moveWeek(1)
        } label: {
          Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
        }.accessibilityLabel("Nächste Woche")
      }.buttonStyle(.borderless)
    }
    private var currentWeekButton: some View {
      Button("Diese Woche") {
        store.selectedDate = Date()
        focusNow += 1
      }
      .font(.subheadline.weight(.medium)).frame(minHeight: 44)
    }
    private var weekControls: some View {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) {
          dateNavigation
          Spacer(minLength: 0)
          currentWeekButton
        }
        VStack(alignment: .leading, spacing: 4) {
          dateNavigation
          currentWeekButton
        }
      }.padding(.horizontal, 16).padding(.bottom, 12)
        .overlay(alignment: .bottom) { Divider() }
    }
    private var weekdays: some View {
      let monday = store.calendar.dateInterval(of: .weekOfYear, for: store.selectedDate)!.start
      return LazyVGrid(columns: [GridItem(.adaptive(minimum: dayWidth), spacing: 4)], spacing: 4) {
        ForEach(0..<7, id: \.self) { offset in
          let day = store.calendar.date(byAdding: .day, value: offset, to: monday)!
          let selected = store.calendar.isDate(day, inSameDayAs: store.selectedDate)
          Button {
            store.selectedDate = day
          } label: {
            VStack(spacing: 6) {
              Text(displayDate(day, template: "EE", zone: store.calendar.timeZone)).font(
                .caption)
              Text(displayDate(day, template: "dd", zone: store.calendar.timeZone))
                .font(.subheadline.weight(.semibold).monospacedDigit())
            }.frame(maxWidth: .infinity).frame(minHeight: 52)
              .foregroundStyle(selected ? .white : campusInk)
              .background(selected ? campusBlue : .clear, in: RoundedRectangle(cornerRadius: 10))
              .overlay(alignment: .bottom) {
                if store.calendar.isDateInToday(day) && !selected {
                  Circle().fill(campusBlue).frame(width: 4, height: 4).padding(.bottom, 2)
                }
              }
          }.buttonStyle(.plain)
            .accessibilityLabel(
              displayDate(day, template: "EEEE, dd. MMMM", zone: store.calendar.timeZone)
            )
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }.padding(.horizontal, 16).padding(.vertical, 8)
    }
    private var schedule: some View {
      NavigationStack {
        VStack(spacing: 0) {
          header
          weekControls
          weekdays
          if let feed = store.feed {
            StudentDayGrid(
              events: feed.rows, day: store.selectedDate, calendar: store.calendar,
              selectedEvent: $selectedEvent, focusRequest: focusNow,
              refresh: { await store.refresh() })
          } else if store.busy {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            ScrollView {
              StudentEmptyState(
                title: "Noch kein Stundenplan geladen", symbol: "calendar",
                detail: "Ziehe die Ansicht nach unten zum Aktualisieren."
              ).padding(24)
            }.refreshable { await store.refresh() }
          }
        }.background(campusCanvas).navigationTitle("").navigationBarTitleDisplayMode(.inline)
          .toolbarBackground(campusCanvas, for: .navigationBar, .tabBar)
          .toolbarBackground(.visible, for: .navigationBar, .tabBar)
          .toolbar {
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
            List {
              if store.feed != nil {
                let today = store.calendar.startOfDay(for: clock.date)
                let events = store.examRows.filter { $0.end >= today }
                Section {
                  if events.isEmpty {
                    StudentEmptyState(
                      title: "Keine Prüfungstermine", symbol: "graduationcap",
                      detail: "Im geladenen Zeitraum sind keine Prüfungen veröffentlicht."
                    )
                    .listRowBackground(campusCanvas).listRowSeparatorTint(campusBlue.opacity(0.12))
                  }
                  ForEach(events) { event in
                    NavigationLink {
                      EventDetails(event: event)
                    } label: {
                      VStack(alignment: .leading, spacing: 4) {
                        ViewThatFits(in: .horizontal) {
                          HStack {
                            Text(
                              displayDate(
                                event.start, template: "EEE, dd. MMM yyyy",
                                zone: store.calendar.timeZone)
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(
                              examCountdown(
                                to: event.start, now: clock.date, calendar: store.calendar)
                            )
                            .font(.subheadline.weight(.semibold)).foregroundStyle(
                              event.cancelled ? .red : campusBlue)
                          }
                          VStack(alignment: .leading, spacing: 4) {
                            Text(
                              examCountdown(
                                to: event.start, now: clock.date, calendar: store.calendar)
                            )
                            .font(.subheadline.weight(.semibold)).foregroundStyle(
                              event.cancelled ? .red : campusBlue)
                            Text(
                              displayDate(
                                event.start, template: "EEE, dd. MMM yyyy",
                                zone: store.calendar.timeZone)
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                          }
                        }
                        EventRow(event: event)
                      }
                    }.listRowBackground(campusCanvas).listRowSeparatorTint(campusBlue.opacity(0.12))
                  }
                }
                Section {
                  Text(
                    "Zeitraum: heute und die nächsten 120 Tage. Weitere Prüfungen erscheinen nach Veröffentlichung."
                  ).font(.footnote).foregroundStyle(.secondary)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
              } else if !store.busy {
                StudentEmptyState(
                  title: "Noch keine Prüfungen geladen", symbol: "graduationcap",
                  detail: "Ziehe die Ansicht nach unten zum Aktualisieren."
                )
                .listRowBackground(campusCanvas).listRowSeparatorTint(campusBlue.opacity(0.12))
              }
            }.listStyle(.plain).listRowSpacing(0)
              .contentMargins(.horizontal, 8, for: .scrollContent).scrollContentBackground(.hidden)
              .refreshable { await store.refresh() }
          }
        }
        .background(campusCanvas).navigationTitle("Prüfungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(campusCanvas, for: .navigationBar, .tabBar)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbar {
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
    private func moveWeek(_ offset: Int) {
      store.selectedDate = store.calendar.date(
        byAdding: .day, value: offset * 7, to: store.selectedDate)!
    }
  }

  private struct StudentDayGrid: View {
    let events: [StudentEvent]
    let day: Date
    let calendar: Calendar
    @Binding var selectedEvent: StudentEvent?
    let focusRequest: Int
    let refresh: () async -> Void
    @ScaledMetric(relativeTo: .body) private var hourHeight: CGFloat = 96
    @ScaledMetric(relativeTo: .caption) private var timeWidth: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var laneWidth: CGFloat = 180

    var body: some View {
      TimelineView(.periodic(from: .now, by: 60)) { clock in
        grid(now: clock.date)
      }
    }
    private func grid(now: Date) -> some View {
      let placements = schedulePlacements(events, day: day, calendar: calendar)
      let range = scheduleTimeRange(placements, day: day, now: now, calendar: calendar)
      let start = range.start
      let end = range.end
      let hours = Int(end.timeIntervalSince(start) / 3600)
      // Keep short events tappable without changing their duration or covering the next event.
      let shortest = placements.map { $0.end.timeIntervalSince($0.start) / 60 }.min() ?? 60
      let scale = max(hourHeight / 60, 48 / CGFloat(shortest))
      let height = CGFloat(end.timeIntervalSince(start) / 60) * scale
      let lanes = placements.map(\.lanes).max() ?? 1
      return GeometryReader { viewport in
        let width = max(viewport.size.width - 32, timeWidth + CGFloat(lanes) * laneWidth)
        ScrollViewReader { scroll in
          ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
              ForEach(0...hours, id: \.self) { hour in
                let tick = start.addingTimeInterval(Double(hour * 3600))
                HStack(spacing: 8) {
                  Text(displayDate(tick, template: "HH:mm", zone: calendar.timeZone))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .opacity(
                      calendar.isDate(now, inSameDayAs: day)
                        && abs(now.timeIntervalSince(tick)) < 600 ? 0 : 1
                    )
                    .frame(width: timeWidth - 8, alignment: .leading)
                  Rectangle().fill(campusBlue.opacity(0.12)).frame(height: 0.5)
                }.frame(width: width, height: 20)
                  .frame(height: hour == hours ? 24 : 60 * scale, alignment: .top)
                  .overlay(alignment: .topLeading) {
                    if hour < hours {
                      Rectangle().fill(campusBlue.opacity(0.05))
                        .frame(width: width - timeWidth, height: 0.5)
                        .offset(x: timeWidth, y: 30 * scale + 10)
                    }
                  }.id(tick).accessibilityHidden(true)
              }
            }.overlay(alignment: .topLeading) {
              ZStack(alignment: .topLeading) {
                ForEach(placements) { item in
                  let column = (width - timeWidth) / CGFloat(item.lanes)
                  let eventHeight = CGFloat(item.end.timeIntervalSince(item.start) / 60) * scale - 4
                  let tint =
                    item.event.cancelled
                    ? Color(red: 0.7, green: 0.13, blue: 0.17)
                    : item.event.kind == "exam"
                      ? Color(red: 0.18, green: 0.43, blue: 0.33) : campusBlue
                  Button {
                    selectedEvent = item.event
                  } label: {
                    VStack(alignment: .leading, spacing: 6) {
                      if eventHeight > 100 {
                        Text(
                          "\(displayDate(item.event.start, template: "HH:mm", zone: calendar.timeZone)) – \(displayDate(item.event.end, template: "HH:mm", zone: calendar.timeZone))"
                        )
                        .font(.caption.monospacedDigit())
                      }
                      Text((item.event.cancelled ? "Abgesagt · " : "") + item.event.name)
                        .font(.subheadline.weight(.semibold)).strikethrough(item.event.cancelled)
                        .lineLimit(
                          eventHeight > 160 ? 4 : eventHeight > 125 ? 3 : eventHeight > 85 ? 2 : 1)
                      if eventHeight > 70, let rooms = item.event.roomNames, !rooms.isEmpty {
                        Label(rooms.joined(separator: ", "), systemImage: "door.left.hand.open")
                          .font(.caption).lineLimit(1)
                      }
                      Spacer(minLength: 0)
                    }.padding(10).frame(
                      width: column - 6, height: eventHeight, alignment: .topLeading
                    )
                    .foregroundStyle(tint).background(tint.opacity(0.08))
                    .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 3) }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                  }.buttonStyle(.plain)
                    .offset(
                      x: timeWidth + CGFloat(item.lane) * column,
                      y: CGFloat(item.start.timeIntervalSince(start) / 60) * scale + 10
                    )
                    .accessibilityLabel(
                      "\(item.event.cancelled ? "Abgesagt. " : "")\(item.event.kind == "exam" ? "Prüfung. " : "")\(item.event.name), \(displayDate(item.event.start, template: "EEEE, HH:mm", zone: calendar.timeZone)) bis \(displayDate(item.event.end, template: "HH:mm", zone: calendar.timeZone)), \(item.event.roomNames?.joined(separator: ", ") ?? "")"
                    )
                    .accessibilityHint("Termindetails öffnen")
                }
                if placements.isEmpty {
                  Text("Keine Veranstaltungen an diesem Tag").font(.subheadline).foregroundStyle(
                    .secondary
                  )
                  .frame(width: width - timeWidth - 16, alignment: .leading)
                  .offset(x: timeWidth + 8, y: 24)
                }
                if calendar.isDate(now, inSameDayAs: day), now >= start, now < end {
                  HStack(spacing: 0) {
                    Text(displayDate(now, template: "HH:mm", zone: calendar.timeZone))
                      .font(.caption.weight(.semibold).monospacedDigit())
                      .foregroundStyle(Color(red: 0.7, green: 0.13, blue: 0.17))
                      .frame(width: timeWidth, alignment: .leading).background(campusCanvas)
                    Rectangle().fill(.red).frame(height: 1)
                  }.frame(width: width, height: 20)
                    .offset(y: CGFloat(now.timeIntervalSince(start) / 60) * scale)
                    .allowsHitTesting(false)
                    .accessibilityLabel(
                      "Aktuelle Uhrzeit \(displayDate(now, template: "HH:mm", zone: calendar.timeZone))"
                    )
                }
              }.frame(width: width, height: height + 24, alignment: .topLeading)
            }.padding(.horizontal, 16).padding(.top, 8)
          }.refreshable { await refresh() }
            .task(id: calendar.startOfDay(for: day)) {
              await Task.yield()
              guard !Task.isCancelled else { return }
              let focus =
                calendar.isDate(now, inSameDayAs: day)
                ? now : placements.first?.start ?? start
              scroll.scrollTo(calendar.dateInterval(of: .hour, for: focus)!.start, anchor: .center)
            }
            .onChange(of: focusRequest) { _, _ in
              scroll.scrollTo(calendar.dateInterval(of: .hour, for: now)!.start, anchor: .center)
            }
        }
      }
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
