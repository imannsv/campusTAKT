# CampusZeit: Push-Mitteilungen

Stand: 15.10.2026. Die technische Anbindung ist implementiert. Für die Aktivierung fehlen noch die Apple-Developer-Mitgliedschaft, Push-Signierung und der APNs-Schlüssel. `APNS_ENABLED=0` bleibt Standard; Gruppenanmeldungen, Offline-Daten und lokale Mitteilungsbanner funktionieren weiterhin.

## Verhalten

- Die App fragt nach der Benachrichtigungsfreigabe und registriert das aktuelle Apple-Gerätetoken automatisch für ihre eigene Gerätesitzung. Kein zusätzlicher Knopf ist nötig. Das Profil zeigt den Push-Status.
- Neue Verwaltungsmitteilungen und neue automatische Ausfallmitteilungen erzeugen innerhalb derselben Datenbanktransaktion Zustellaufträge für die passenden Gruppen-, Jahrgangs- und Einrichtungssitzungen. Wiederholte Absagen erzeugen keine doppelten Aufträge. Alte Mitteilungen werden beim Anmelden nicht nachträglich gepusht.
- Ein eigener Dienst prüft die dauerhafte Warteschlange alle fünf Sekunden. Er sendet über TLS/HTTP/2 mit ES256-signierter APNs-Anmeldung und prüft vor jedem Versand erneut Sitzung, Ablauf, Zielgruppe, Rücknahme und Gerätebindung.
- Vorübergehende Fehler erhalten bis zu acht Versuche mit wachsendem Abstand. Ungültige Gerätetoken werden entfernt. Aufträge über 24 Stunden werden verworfen; abgeschlossene Zustellprotokolle werden nach 30 Tagen gelöscht.
- Der Sperrbildschirm zeigt nur „Eine neue Mitteilung deiner Einrichtung ist verfügbar.“ Vollständige Inhalte werden nicht an Apple gesendet. Antippen öffnet den Posteingang und aktualisiert die App. Fremde beziehungsweise veraltete Sitzungsbindungen werden im Vordergrund unterdrückt und öffnen keinen fremden Posteingang.
- Registrierte Sitzungen erhalten keine zusätzlichen lokalen Abrufbanner. Ohne eingerichteten Push-Dienst bleibt die bisherige lokale Benachrichtigung erhalten.

Apples Annahme bestätigt noch keine Anzeige auf dem Gerät. Verbindung, Fokus und iOS-Einstellungen beeinflussen die Zustellung. Bereits an Apple übergebene Hinweise können nach Abmeldung oder Rücknahme noch eintreffen; deshalb enthalten sie keine Mitteilungsinhalte. Eine Offline-Abmeldung meldet die App lokal bei APNs ab, kann aber die Server-Sitzung erst bei erreichbarem Server beziehungsweise durch die Verwaltung widerrufen.

## Aktivierung nach Apple-Developer-Anmeldung

1. Eine explizite App-ID mit **Push Notifications** im Apple-Konto aktivieren und ein passendes Entwicklungs- oder Verteilungsprofil erstellen. Ein vorhandenes Personal-Team-Profil erhält nicht automatisch Push-Rechte.
2. Einen APNs-Signierschlüssel erstellen und die `.p8`-Datei außerhalb des Repositories sicher ablegen. Team-ID und Key-ID notieren. Keine Schlüssel oder Apple-Zugangsdaten in Chat oder Git kopieren.
3. In `mobile/ios/CampusZeitStudents/xtool.yml` die vorbereitete Zeile `entitlementsPath: Support/Push.entitlements` aktivieren. Das Entitlement verwendet `aps-environment=development`, die App-Info `CampusZeitPushEnvironment=sandbox`. Für TestFlight/App Store beide Werte auf **production** ändern. Die tatsächliche Signierung muss zum Profil passen.
4. Die **tatsächlich signierte** Bundle-ID als `APNS_TOPIC` setzen. Der bisherige lokale Xtool-Testbuild kann etwa `XTL-53TYDK3367.de.campuszeit.students` verwenden. Nicht ungeprüft die Basis-ID übernehmen. App und Server prüfen Bundle-ID und Umgebung auf Übereinstimmung.
5. Migration ausführen, Server und Push-Dienst mit denselben Einstellungen starten und die App mit passendem Profil neu bauen/installieren. Danach einmal öffnen und den Profilstatus kontrollieren.

Umgebungseinstellungen (Platzhalter, keine Zugangsdaten):

```dotenv
APNS_ENABLED=1
APNS_TEAM_ID=<Apple-Team-ID>
APNS_KEY_ID=<APNs-Key-ID>
APNS_KEY_PATH=<absoluter-Pfad-zum-geschützten-p8-Schlüssel>
APNS_TOPIC=<tatsächlich-signierte-Bundle-ID>
APNS_ENVIRONMENT=sandbox
```

Django lädt `.env` nicht selbst. Beim lokalen Start müssen die Werte in der Prozessumgebung stehen. `npm run dev:local` startet bei `APNS_ENABLED=1` den Push-Dienst zusätzlich. Für einen separat gestarteten WLAN-Server läuft der Dienst in einem eigenen Terminal mit derselben Umgebung:

```powershell
.venv/Scripts/python.exe backend/manage.py migrate
.venv/Scripts/python.exe backend/manage.py student_push --watch
```

Der lokale Starter bindet weiterhin an Loopback; für iPhone/iPad im WLAN gilt der bestehende WLAN-Start. Push benötigt ausgehend TCP 443 zu Apple, keinen neuen eingehenden Port. Der Feed benötigt weiterhin eine erreichbare Serveradresse; APNs macht einen LAN-Server nicht öffentlich erreichbar.

Docker Compose nach Setzen der Werte in `.env`:

```sh
docker compose run --rm web python manage.py migrate
docker compose --profile push up -d --build web worker push
```

Das optionale Profil `push` mountet nur die konfigurierte Schlüsseldatei schreibgeschützt in den Push-Container. Sie muss existieren und für dessen Benutzer lesbar sein. Ohne aktiviertes Profil wird sie nicht gemountet. Bei fehlender Konfiguration oder ungültigem Schlüssel startet der Push-Dienst mit einer verständlichen Fehlermeldung nicht. Private Schlüssel gehören nicht in ein Docker-Image.

## API und Prüfung

`POST /api/student-app/v1/push/` mit Bearer-Gerätesitzung und `{token, environment, topic}` registriert das APNs-Token. Antwort: `{binding}` als nicht geheime UUID. Zielgruppe und Apple-Adresse sind serverseitig festgelegt. `DELETE` entfernt die Push-Bindung. Abmelden oder Sperren des Gruppenzugangs löscht die Sitzung und zugehörige Aufträge. Antworten sind nicht cachebar. APNs-Gerätetoken müssen für den Versand gespeichert werden; sie sind keine Verwaltungs- oder Login-Zugangsdaten und werden nicht in Listen oder Logs ausgegeben.

```powershell
.venv/Scripts/python.exe backend/manage.py test planner.test_student_push planner.test_student_app --noinput
```

Die Tests prüfen Anmeldung, Eingaben, Umgebung/Bundle-ID, Einrichtungs- und Gruppengrenzen, Tokenwechsel, Abmeldung, Rollback, Ausfallaufträge, Wiederholungsversuche und signierte Anfragen an einen simulierten Apple-Endpunkt. Swift-Coretests prüfen Tokenkodierung und Sitzungsbindung. Der echte Sperrbildschirmtest steht aus: nach Apple-Freischaltung und Neuinstallation einmal öffnen, Profilstatus prüfen, App schließen und eine neue Testmitteilung sowie einen Ausfalltest an die Testgruppe senden.

Quellen: [Apple: Registrierung](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns), [Apple: Versand](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns), [Apple: tokenbasierte Anmeldung](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns), [Apple: unterstützte Fähigkeiten](https://developer.apple.com/help/account/reference/supported-capabilities-ios/).
