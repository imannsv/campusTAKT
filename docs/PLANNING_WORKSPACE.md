# Stundenplanung und Termin-Popup

Der Wochenplan nutzt die gesamte Arbeitsbreite. Es gibt keinen permanenten
rechten Detailbereich. Logo, Produktfarben, die aktuelle Woche, rote Zeitlinie
und die einklappbare Navigation bleiben erhalten.

## Jahrgang und Gruppe auswählen

Stundenplanung und Prüfungen beginnen mit derselben Gruppenauswahl. Die
Aufnahmejahre stehen absteigend und lassen sich auf- und zuklappen. Darunter
stehen die Studiengänge mit ihren Gruppen; „Ganzer Jahrgang“ öffnet alle
Gruppen dieses Jahrgangs. Die Suche im Kopf findet Jahrgänge, Studiengänge
und Gruppen. Fehlende Aufnahmejahre werden als „Ohne Aufnahmejahr“ geführt.

Ein Klick auf eine Gruppe öffnet einen passenden Semesterplan und dessen
gefilterte Termine bzw. Prüfungen. Die Semesterwahl zeigt nur zugeordnete
Pläne, einschließlich gemeinsamer Veranstaltungen. Ohne passenden Plan
erscheint ein leerer Zustand. „Gruppe wechseln“ führt zur Auswahl zurück;
„Gesamtübersicht öffnen“ erhält den Zugriff auf alle Pläne. Direkte Links aus
der Studienstruktur öffnen weiterhin den gewählten Plan. Abgaben und
Prüfungsanforderungen bleiben Vorgaben des ganzen Semesterplans.

## Terminbearbeitung

- Ein Klick auf einen Kalendertermin öffnet das Formular als modales Popup.
  „Termin“ öffnet dasselbe Popup zum Anlegen. Der Kalender bleibt im Hintergrund.
- Schemafelder, häufig verwendete Felder zuerst, Speichern, Löschen und
  Validierung nutzen weiterhin dieselbe API.
- Escape, Abbrechen, Schließen und Hintergrundklick fragen vor dem Verwerfen
  ungespeicherter Eingaben nach. Ein abgelehntes Verwerfen erhält das Formular.
  Während des Speicherns bleiben die Felder und das Schließen gesperrt.
- Die automatische Zeitnavigation pausiert während der Bearbeitung.
  Nach dem Schließen gilt wieder die zuvor gewählte Navigation. Tastaturfokus
  bleibt im Popup und kehrt anschließend zum auslösenden Element zurück.
- Kopf und Speicheraktionen bleiben sichtbar; lange Formulare scrollen intern.
  Auf kleinen Bildschirmen stehen die Felder untereinander.
- Tagesbreiten verwenden wieder die normalen Kalenderbreiten. Bei Platzmangel
  scrollt der Kalender horizontal.

## Prüfung

Die Demo-Browsertests prüfen Popup, Speichern, Validierung, ungespeicherte
Eingaben, Fokus und Mobilansicht. Die API-Tests verwenden ausschließlich
abgefangene HTTP-Anfragen mit Testdaten und prüfen auch verzögertes Speichern.
