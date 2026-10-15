#if canImport(UIKit)
  import SwiftUI

  enum StudentRelease {
    static let id = "2026-10-13-calendar-views"
    static let summary = "Neue Stundenplanansichten und Hilfe direkt in der App."
  }

  struct StudentNewsView: View {
    var body: some View {
      List {
        Section("Neue Gestaltung") {
          Text(StudentRelease.summary)
          Text("Im Stundenplan-Menü kannst du jetzt Tag, 2 Tage, 3 Tage oder Woche wählen.")
          Text("Im Profil kannst du System, Hell oder Dunkel auswählen.")
          Text(
            "Der Startbildschirm zeigt deinen nächsten Termin und direkte Zugriffe auf Stundenplan, Prüfungen und Mitteilungen."
          )
          Text(
            "Bei der Leibniz-FH erscheint das Campusfoto neben der Begrüßung. Die kurzen Sprüche wechseln beim erneuten Öffnen."
          )
        }.listRowBackground(campusSurface)
        Section("Automatisch verfügbar") {
          Text(
            "Geladene Termine, Prüfungen und Mitteilungen bleiben auch ohne Verbindung sichtbar.")
          Text(
            "Neue Daten werden beim Öffnen und während der Nutzung automatisch geladen. Hintergrundabrufe werden von iOS gesteuert."
          )
        }.listRowBackground(campusSurface)
      }.scrollContentBackground(.hidden).background { CampusBackdrop() }
        .foregroundStyle(campusInk).navigationTitle("Was gibt es Neues")
        .navigationBarTitleDisplayMode(.inline)
    }
  }

  struct StudentHelpView: View {
    var body: some View {
      List {
        Section("Stundenplan") {
          Text(
            "Im Menü oben rechts wählst du Tag, 2 Tage, 3 Tage oder Woche. Wische nach links oder rechts, um den angezeigten Zeitraum zu wechseln. Über das Menü springst du zu heute beziehungsweise zur aktuellen Woche oder wählst ein Datum aus."
          )
          Text(
            "Tippe einen Termin an, um den vollständigen Titel, Raum und Lehrende zu sehen. Über die Tagesüberschrift oder „Termine & Details“ erreichst du die Tagesliste."
          )
          Text(
            "Samstag erscheint in der Wochenübersicht nur bei Belegung. Das Raster beginnt beim frühesten Termin der Woche. Die rote Linie zeigt die aktuelle Uhrzeit; außerhalb des Zeitbereichs steht ein kurzer Zeithinweis unter dem Raster."
          )
        }.listRowBackground(campusSurface)
        Section("Absagen und Prüfungen") {
          Text(
            "Abgesagte Termine bleiben erhalten und erscheinen rot und durchgestrichen. In den Prüfungsdetails findest du Datum, Zeit und Raum; der Countdown zählt die Tage bis zum Termin."
          )
        }.listRowBackground(campusSurface)
        Section("Offline und Mitteilungen") {
          Text(
            "Die App speichert automatisch die aktuelle und die nächsten 17 Wochen. Ein Offline-Hinweis nennt den Stand. Wochen, die noch nie geladen wurden, sind ohne Verbindung nicht verfügbar."
          )
          Text(
            "Mitteilungen kannst du durchsuchen und vollständig öffnen. Benachrichtigungen benötigen die iPhone-Freigabe und einen erfolgreichen Abruf. Sofortige Push-Zustellung bei geschlossener App ist noch nicht eingerichtet."
          )
        }.listRowBackground(campusSurface)
        Section("Zugang und Freigaben") {
          Text(
            "Deine Verwaltung stellt den QR-Code oder die gemeinsamen Zugangsdaten bereit. Im Profil findest du die Serveradresse, den Datenstand, die Darstellung und die App-Freigaben."
          )
          Text(
            "Dieser Gruppenzugang zeigt keine persönlichen Noten oder Teilnehmerlisten. Bei einem gesperrten oder abgelaufenen Zugang wende dich an deine Verwaltung."
          )
        }.listRowBackground(campusSurface)
      }.scrollContentBackground(.hidden).background { CampusBackdrop() }
        .foregroundStyle(campusInk).navigationTitle("Hilfe")
        .navigationBarTitleDisplayMode(.inline)
    }
  }

  struct StudentLicensesView: View {
    var body: some View {
      List {
        Section("Open-Source-Komponenten") {
          Text("Diese Version enthält keine zusätzlich eingebundenen Open-Source-Bibliotheken.")
        }.listRowBackground(campusSurface)
        Section("CampusZeit") {
          LabeledContent(
            "Version",
            value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
              ?? "–")
          LabeledContent(
            "Build",
            value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–")
          Text("Die App verwendet die von iOS bereitgestellten Systemkomponenten.")
            .foregroundStyle(campusMuted)
        }.listRowBackground(campusSurface)
      }.scrollContentBackground(.hidden).background { CampusBackdrop() }
        .foregroundStyle(campusInk).navigationTitle("Open-Source-Lizenzen")
        .navigationBarTitleDisplayMode(.inline)
    }
  }
#endif
