Die Studierenden-App bietet ausschließlich Lesezugriff: Stundenplan, Prüfungen und wichtige Mitteilungen. Es gibt keine Einzelkonten für Lernende. Die Verwaltung stellt einen gemeinsamen Zugang für eine Gruppe oder einen Jahrgang bereit.

![Verwaltung von App-Zugängen und Mitteilungen in der fiktiven Beispieleinrichtung](/api/wiki/assets/student-app.png)

## Zugang bereitstellen

1. Öffne **Studierenden-App** unter **Veröffentlichung**.
2. Klicke auf **Zugang erstellen** und wähle eine Gruppe oder einen Jahrgang. Ein Jahrgangszugang umfasst dessen Gruppen.
3. Trage die vom iPhone erreichbare CampusZeit-Serveradresse ein, zum Beispiel die HTTPS-Adresse der eigenen Einrichtung. Die Adresse benötigt keinen zusätzlichen Pfad.
4. Erstelle den Zugang. Speichere den angezeigten QR-Code oder kopiere die Zugangsdaten. Das Passwort wird ausschließlich bei der Erstellung angezeigt. Den QR-Code, die Serveradresse und den Zugangscode kannst du später in der Zugangsliste über **Zugang anzeigen** erneut öffnen und speichern – auch nach einem Neuladen.
5. Teile diese Angaben mit der Zielgruppe. Verwende dafür kein Verwaltungskonto.

Bei älteren Zugängen ergänze beim ersten erneuten Öffnen einmalig die erreichbare Serveradresse. Der neu angezeigte QR-Code funktioniert zusätzlich zu bereits verteilten Codes. Passwort und angemeldete Geräte bleiben erhalten. Ein vergessenes Passwort lässt sich aus seiner gespeicherten Prüfsumme nicht wiederherstellen; nutze dann den QR-Code. Gesperrte Zugänge können nicht erneut bereitgestellt werden.

Für einen lokalen Test müssen Server und iPhone im selben Netzwerk sein. **localhost** und **127.0.0.1** bezeichnen auf dem iPhone das iPhone selbst. Der lokale Server muss unter seiner Netzwerkadresse erreichbar und dafür konfiguriert sein. Verwende im öffentlichen Betrieb HTTPS.

## Auf dem iPhone anmelden

Öffne die installierte CampusZeit-App und wähle **QR-Code scannen**. Erlaube den Kamerazugriff, scanne den bereitgestellten Code und bestätige die angezeigte Serveradresse. Alternativ gib Serveradresse, Zugangscode und Passwort ein. Ein QR-Code ist ein Zugangsschlüssel; veröffentliche ihn nicht außerhalb der Zielgruppe.

Die erste Version ist als native iPhone-App mit Xtool gebaut. Release-Build, lokale Testsignierung und Installation bestehen; die Anmeldung wurde auf dem iPhone geöffnet. Der vollständige Gerätetest steht noch aus. Eine Testsignierung läuft ab und ersetzt keine spätere App-Store-Veröffentlichung. Android ist der anschließende Schritt. Die Browser-Demo kann keine echten App-Zugänge bereitstellen.

## Was Studierende sehen

**Stundenplan** zeigt die ausgewählte Woche als Zeitraster mit Montag bis Freitag; Samstag erscheint nur bei vorhandenen Terminen. Beim Öffnen ist die aktuelle Woche ausgewählt. Im Kalender lässt sich eine andere Woche auswählen; **Diese Woche** führt zurück. Ein Termin öffnet seine Details.

**Prüfungen** zeigt freigegebene zeitgebundene Prüfungen im heruntergeladenen Zeitraum der aktuellen und nächsten 17 Wochen. Änderungen an Entwürfen erscheinen erst nach [Veröffentlichung](/wiki/publication). Abgesagte Termine bleiben sichtbar, rot markiert und durchgestrichen. Persönliche Noten, Teilnehmerlisten und unveröffentlichte Prüfungsanforderungen werden nicht übertragen.

**Mitteilungen** zeigt die veröffentlichten Hinweise für die Einrichtung und die zugehörige Gruppe beziehungsweise den Jahrgang. Die App aktualisiert bei erneuter Aktivierung, per Herunterziehen und im Vordergrund regelmäßig. Bei Verbindungsproblemen bleiben die gespeicherten Inhalte samt Datenstand sichtbar, auch nach einem vollständigen Neustart der App.

## Automatisch offline nutzen

1. Öffne CampusZeit mit Verbindung zu deinem Server und melde dich an.
2. Die App lädt und speichert die Daten selbst beim Öffnen und während der Nutzung. Auch im Hintergrund werden Aktualisierungen angefragt; iOS bestimmt, wann sie laufen. Du musst keinen Download anstoßen.
3. Unter **Profil → Offline verfügbar** kannst du den Speicherzeitpunkt nachsehen. Der Download umfasst die aktuelle Woche und die nächsten 17 Wochen, Prüfungen und veröffentlichte Mitteilungen. Zusätzlich besuchte Wochen bleiben bis zur Grenze von 30 gespeicherten Wochen erhalten; dazwischen können nicht geladene Wochen liegen.
4. Ohne Verbindung kannst du diese Wochen, Details, Prüfungen und Mitteilungstexte weiterhin öffnen. Die App zeigt den letzten geladenen Stand. Noch nicht heruntergeladene Wochen werden als solche gekennzeichnet.
5. Sobald der Server wieder erreichbar ist, aktualisiert sich die geöffnete App automatisch. Erst dann werden neue Mitteilungen, Änderungen, Absagen oder zurückgezogene Inhalte übernommen.

Abmelden entfernt den Offline-Stand. Das Ablaufdatum des Zugangs gilt auch ohne Verbindung; eine zwischenzeitliche Sperre wird beim nächsten Serverkontakt erkannt. Bei Serverwartung bleiben die zuvor heruntergeladenen Daten nutzbar.

Hintergrundabrufe haben keine feste Uhrzeit und können durch iOS-Einstellungen oder Energiesparregeln verzögert werden. Beim Öffnen wird der Abruf immer automatisch versucht. Der gespeicherte Stand bleibt verfügbar, wenn der Server nicht erreichbar ist.

## Mitteilung veröffentlichen oder zurückziehen

Klicke in der Verwaltung auf **Mitteilung erstellen**. Wähle eine Zielgruppe oder **Alle Studierenden**, erfasse Titel und Text und klicke **Veröffentlichen**. Mit **Zurückziehen** entfernst du die Mitteilung aus der App. Neu abgerufene Mitteilungen können nach erteilter Freigabe lokale Banner auslösen, auch nach einem von iOS erlaubten Hintergrundabruf. Sofortige Push-Zustellung ist noch nicht eingerichtet.

## Automatische Ausfallmitteilungen

Wenn die Verwaltung einen bereits veröffentlichten Termin absagt, erstellt CampusZeit automatisch eine Mitteilung für jede betroffene Gruppe. Das gilt auch für Absagen durch eine Lehrenden-Blockzeit oder eine gespeicherte Verfügbarkeit mit Blockzeiten. Jahrgangszugänge erhalten die Mitteilungen ihrer Gruppen ebenfalls.

Die Nachricht enthält den veröffentlichten Titel, Datum, Uhrzeit und Raum. Unveröffentlichte Änderungen und persönliche Gründe für Blockzeiten werden nicht übertragen. Der abgesagte Termin bleibt rot und durchgestrichen im Plan erhalten. Wiederholtes Speichern und die Blockzeit-Vorschau erzeugen keine weiteren Nachrichten.

Die Mitteilung erscheint auch in der Verwaltung unter **Studierenden-App** und kann dort zurückgezogen werden. Wird die Absage am Termin aufgehoben und erfolgreich gespeichert, zieht CampusZeit die zugehörige Ausfallmitteilung zurück. Eine spätere erneute Absage erzeugt eine neue Nachricht. Für unveröffentlichte Termine oder Termine ohne zugeordnete Gruppe wird keine Nachricht verschickt; alte Absagen werden beim Update nicht nachträglich gemeldet.

Die App übernimmt die neue Mitteilung beim nächsten erfolgreichen automatischen Abruf. Ohne Verbindung bleibt ihr gespeicherter Stand erhalten. Ein sofortiger Push bei geschlossener App ist weiterhin nicht eingerichtet; Hintergrundabrufe werden von iOS bestimmt.

## Zugang sperren oder ersetzen

**Sperren** beendet alle Gerätesitzungen dieses Gruppenzugangs. Für neue Zugangsdaten sperre den bisherigen Zugang und erstelle einen neuen. Auf einem iPhone beendet **Mein Zugang → Auf diesem Gerät abmelden** nur die eigene Sitzung. Gerätesitzungen laufen nach 90 Tagen ab und erfordern dann eine erneute Anmeldung.

Ein geteilter Zugang kann von Empfängern weitergegeben werden. Ohne Einzelkonten kann die App keine individuelle Wahlpflichtbelegung oder persönliche Prüfungszulassung nachweisen; sie zeigt die freigegebenen Termine der gesamten zugeordneten Gruppe beziehungsweise des Jahrgangs.
