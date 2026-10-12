# Studierenden-App

Native iPhone-App unter `mobile/ios/CampusZeitStudents`, angelegt mit Xtool 1.21.0. Mindestversion iOS 17. Die App ist ausschließlich lesend; Stundenplan, Prüfungstermine und Mitteilungen kommen aus der eigenen CampusZeit-Instanz. Android folgt nach dem iPhone-Gerätetest und kann dieselbe API verwenden.

Stand 12.10.2026: Der native Release-Build mit dem iPhoneOS-27.1-SDK aus `Xcode_27.1_Release_Candidate.xip` besteht ohne Compilerwarnungen. Xtool erzeugt die IPA unter `mobile/ios/CampusZeitStudents/xtool/CampusZeitStudents.ipa`. Paketintegrität, arm64-Executable, Mindestversion iOS 17, Kamera-Hinweis und unverändertes Logo wurden geprüft. Die lokale Testfassung ist inzwischen signiert; Signaturdateien, passendes eingebettetes Profil und dessen Gültigkeit wurden geprüft. Das Testprofil gilt bis 19.10.2026. Die Installation über Apples Windows-Geräteverbindung bestand einschließlich iOS-Verifizierung; der Anmeldebildschirm wurde auf dem iPhone geöffnet. Gruppenzugang und Wiederherstellung der Keychain-Sitzung wurden am Gerät bestätigt; der vollständige Gerätetest steht noch aus. Die direkte USB-Weiterleitung unter WSL scheitert weiterhin am unten beschriebenen Paketgrößenfehler.

## Verwaltung und Backend

Die Anmeldung verwendet einen hellen Campus-Hintergrund und eine weiße Karte mit dem unveränderten Logo. Die angemeldeten Ansichten haben einen weißen Grund mit dunklem Text und dezenten Campusfarben. „QR-Code scannen“ öffnet die Kamera, „Mit Zugangsdaten anmelden“ das getrennte Formular. Einrichtung und Gruppe stehen kompakt im Navigationskopf; der Aktualisierungsstand ist unter „Mein Zugang“ zu finden. Im Stundenplan entfällt die zusätzliche Seitenüberschrift. Links im Kopf steht das unveränderte Logosymbol. Die kompakte Datumszeile öffnet den Kalender; „Tag/Woche“ wechselt die Darstellung. Im Tagesmodus sind sieben Wochentage gleichmäßig verteilt, bei großer Schrift umbrechend. Ein Wisch nach links öffnet den nächsten Tag, nach rechts den vorherigen; vertikales Scrollen löst keinen Tageswechsel aus. Auch der Wechsel über eine Wochengrenze lädt die passende Woche. „Heute“ steuert den aktuellen Tag und die Uhrzeit an. Die Wochenansicht zeigt sieben nebeneinanderliegende Tagesraster mit eigenen Uhrzeitachsen und vertikalem Scrollen je Tag; horizontal durch die Woche wischen. „Diese Woche“ führt zur aktuellen Woche und zum heutigen Tag. Der Kalender erlaubt die Auswahl anderer Zeiträume. Das Zeitraster zeigt Termine an ihrer tatsächlichen Uhrzeit und Dauer, mit sichtbaren Pausen. Echte Überschneidungen erscheinen in getrennten Spalten; bei Platzmangel scrollt das Raster horizontal. Kurze Termine vergrößern den vertikalen Maßstab, damit sie antippbar bleiben. Ein Antippen öffnet die vollständigen Termindetails. Eine dünne rote Linie markiert die aktuelle Uhrzeit am heutigen Tag. Prüfungen zeigen neben dem festen Datum „Heute“, „Morgen“ oder „In X Tagen“, berechnet nach Kalendertagen der Hochschule. Lange Titel umbrechen, abgesagte Termine bleiben rot und durchgestrichen. Der Kamerabereich zeigt einen Scanrahmen und einen kurzen Hinweis; die Serverbestätigung bleibt vor der QR-Anmeldung erhalten. Beim App-Start wird der Inhalt kurz eingeblendet, ohne zusätzliche Wartezeit. Mit aktivierter iPhone-Einstellung „Bewegung reduzieren“ entfällt die Animation.

1. Python-Abhängigkeiten installieren: `.venv/Scripts/python.exe -m pip install -r requirements.txt`.
2. Additive Migration anwenden: `.venv/Scripts/python.exe backend/manage.py migrate`.
3. Verwaltung öffnen und unter **Veröffentlichung → Studierenden-App** einen Zugang für eine Gruppe oder einen Jahrgang erstellen.
4. Die von Geräten erreichbare Serveradresse angeben. QR-Code speichern oder Zugangsdaten kopieren; sie werden nur bei Erstellung ausgegeben. Für einen Ersatz alten Zugang sperren und neuen erstellen.
5. Erst veröffentlichte Pläne werden ausgeliefert. Mitteilungen werden hier gesondert erstellt und veröffentlicht.

Die Migration fügt ausschließlich Tabellen für Zugänge, Gerätesitzungen und Mitteilungen hinzu. Vorhandene Planungsdaten werden nicht verändert. Der neue Menüpunkt ist in der statischen Browser-Demo sichtbar, aber die Zugangsverwaltung dort deaktiviert.

## Xtool unter WSL

Grundlage: [offizielle Installation](https://xtool.sh/documentation/xtool/installation-linux/) und [erstes Projekt](https://xtool.sh/tutorials/xtool/first-app/). Apple-Zugangsdaten ausschließlich interaktiv in Xtool eingeben, niemals ins Repository oder in den Chat.

```bash
cd /mnt/c/Users/imann/Documents/Codex/2026-10-03/wir-planen-jetzt-gemeinsam-eine-plattform/mobile/ios/CampusZeitStudents
. /home/imann/.local/share/swiftly/env.sh
swift --version
xtool sdk status
xtool sdk install /vollstaendiger/pfad/Xcode.xip
xtool dev build -c release --ipa
```

Ein Linux-Swift-Compiler ersetzt das Apple-SDK nicht. Die aktuell eingerichtete Ubuntu-26.04-Umgebung nutzt Swift 6.4.0 für Ubuntu 24.04; für lokale Swift-Tests wurden kompatible Bibliotheken separat unter `/home/imann/.local/share/campuszeit-swift-libs` extrahiert. Dort zusätzlich:

```bash
export LD_LIBRARY_PATH=/home/imann/.local/share/campuszeit-swift-libs/usr/lib/x86_64-linux-gnu
swift test
```

Für andere Rechner eine von Swift unterstützte Linux-Version gemäß offizieller Anleitung verwenden. `swift test` prüft den plattformunabhängigen API-Client, QR-Parser und Datumslogik. UIKit-/SwiftUI-Dateien werden ausschließlich im iOS-Build kompiliert.

Für Installation auf einem iPhone sind die interaktive Xtool-Anmeldung/Signierung und die Geräteverbindung erforderlich. Danach aus dem Projektverzeichnis `xtool dev run` ausführen. Die Bundle-ID ist `de.campuszeit.students`; ihre Verfügbarkeit muss bei der Apple-Provisionierung bestätigt werden. Es wurde noch keine App-Store-Veröffentlichung eingerichtet.

```bash
xtool auth login
xtool devices --usb --no-wait
xtool dev run
```

Die Apple-Anmeldung erfolgt interaktiv im Terminal. Kein Apple-Passwort in den Chat eingeben. Xtool ist auf diesem Entwicklungsrechner angemeldet, und das Test-iPhone ist bei Apple registriert. Die erste Profilerstellung meldete noch keine passenden Geräte; nach Übernahme der Registrierung bestand derselbe Ablauf. Falls Xtool den Widerruf eines bestehenden Entwicklerzertifikats verlangt, ist dafür eine gesonderte Zustimmung erforderlich: Andere damit signierte Test-Apps können betroffen sein.

### Windows-Geräteverbindung

Unter Windows benötigt Xtool eine Verbindung zwischen WSL und dem iPhone. `usbipd-win` plus Linux-`usbmuxd` kann das Gerät erkennen, aber bei bestimmten Kombinationen scheitert die Übertragung mit `asyncReadComplete, message was too large (65536 bytes, max = 65535)`. Dieser Fehler wurde auf dem Entwicklungsrechner reproduziert. Der [im Xtool-Projekt dokumentierte Ersatzweg](https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718) verwendet Apples Windows-Geräteverbindung.

1. [Apple Devices aus dem Microsoft Store](https://apps.microsoft.com/detail/9NP83LWLPZ9K) installieren und öffnen. Den Begrüßungsdialog abschließen; das iPhone muss in der App erkannt werden.
2. Das iPhone von direkter WSL-USB-Weiterleitung trennen, sodass Windows es wieder verwaltet.
3. Apples lokalen Geräteanschluss auf Port 27015 ausschließlich für die WSL-Adresse weiterleiten. Dafür sind Windows-Administratorrechte nötig. Keine allgemeine Firewallfreigabe für alle Netzwerke einrichten.
4. In WSL `USBMUXD_SOCKET_ADDRESS` auf die Windows-Hostadresse mit Port 27015 setzen und zunächst `ideviceinfo -k DeviceName` prüfen. Erst nach erfolgreicher Geräteabfrage Xtool installieren lassen.

Die auf die lokale Ubuntu-Adresse begrenzte Weiterleitung ist eingerichtet und wurde durch Geräteabfrage und erfolgreiche Installation geprüft. Das automatische Starten über Xtool meldet noch einen Debugserver-Fehler; die App lässt sich auf dem iPhone manuell öffnen. Zertifikate, private Schlüssel, Geräteseriennummern und signierte Pakete bleiben außerhalb des Git-Repositories.

Die überarbeitete Anmeldung mit Startanimation wurde am 12.10.2026 ebenfalls installiert und von iOS verifiziert. Für eine bereits signierte IPA `ideviceinstaller install xtool/CampusZeitStudents.ipa` verwenden, mit derselben `USBMUXD_SOCKET_ADDRESS` wie oben. `xtool install` signiert erneut und hat bei der ersten signierten IPA die Bundle-ID nochmals präfixiert. Die dadurch entstandene ältere Testfassung wurde nach erfolgreicher Installation der neuen Fassung entfernt; auf dem iPhone bleibt eine CampusZeit-App. Die zwischenzeitlichen Schreibfehler im Übertragungsbereich traten beim späteren Versuch nicht mehr auf. Die neue Darstellung, QR-Anmeldung und Keychain-Sitzung sind noch auf dem Gerät zu prüfen.

Beim ersten Gerätetest suchte `Image("Logo", bundle: .module)` einen Asset-Katalog und fand das als PNG kopierte Logo nicht. Ohne feste Höhe reservierte das fehlende Bild einen großen leeren Bereich. Die Anmeldung lädt `Logo.png` jetzt über `UIImage(contentsOfFile:)` aus dem Ressourcenbundle und begrenzt den Bildbereich auf 46 Punkte. Die Originaldatei bleibt unverändert. Der folgende Gerätescreenshot bestätigte sichtbares Logo und Anmeldeaktionen; die anschließend gewählte helle Kartenansicht wurde ebenfalls nativ gebaut, signiert und installiert.

Der Gerätetest am 12.10.2026 bestätigte die Verbindung zum lokalen WLAN-Server, die Anmeldung mit einem Gruppenzugang sowie das Laden des Stundenplans und kommender Prüfungen; der Mitteilungsbereich zeigte den korrekten Leerzustand. Nach dem folgenden Update wurde die helle Darstellung aller drei Tabs und der weiter bestehende Gruppenzugang ausdrücklich bestätigt. Neue Mitteilungen, Absagefälle, Sperren/Abmelden sowie VoiceOver und große Schrift sind noch auf dem iPhone zu prüfen.

Die anschließend gewählte ruhigere Gestaltung mit Tagesüberschriften und feinen Trennlinien wurde am 12.10.2026 nativ gebaut, signiert und erfolgreich als Update installiert. Sie ist noch visuell am Gerät abzunehmen. Frisch bestanden: sieben Backendtests für Gruppenabgrenzung, veröffentlichte Daten/Absagen, Mitteilungszielgruppen und Rücknahme, Abmelden/Ablauf/Sperren sowie Zugriffsgrenzen; der Verwaltungstest im Browser für QR-Bereitstellung, Mitteilungen und Sperren; zwei Swift-Coretests einschließlich Mitteilungsdekodierung, erhaltenem abgesagtem Termin und Zeitumstellung. Diese Prüfungen nutzen getrennte Testdatenbanken und verändern den LFH-Bestand nicht.

Die Tagesraster-Version wurde am 12.10.2026 nativ gebaut, signiert, als Update installiert und um einen getesteten Überlappungs- und Countdown-Helfer ergänzt. Vier Swift-Coretests prüfen zusätzlich aufeinanderfolgende Termine, parallele Termincluster, Tagesgrenzen und Countdown-Werte über die Zeitumstellung. Die visuelle Abnahme des Rasters, der Wochentagsauswahl und der neuen Prüfungsdarstellung am iPhone steht noch aus.

Am 12.10.2026 zeigten Gerätefotos zeitweise Leerraum über dem Raster und die Meldung „Abgebrochen“. Scrollanker liegen jetzt in echten Stundenzeilen statt in verschobenen Überlagerungen. Der heutige Zeitbereich schließt die aktuelle Stunde auch vor 08:00 und nach 18:00 ein; die rote Linie trägt eine Uhrzeitbeschriftung. Beim Öffnen des Tages und über „Heute“ wird die aktuelle Stunde angesteuert. URLSession-Abbrüche werden als normale Task-Abbrüche behandelt, ohne eine Fehlermeldung in Anmeldung oder Stundenplan zu erzeugen; andere Netzwerkfehler bleiben sichtbar. Regressionstests reproduzierten zunächst beide Fehler (Netzwerkabbruch und fehlende Uhrzeit außerhalb 08–18 Uhr). Alle sechs ausgewählten Swift-Coretests bestehen, einschließlich der zuvor fehlgeschlagenen Regressionen. Der native Release-Build, Signierung, Paketprüfung und Update-Installation bestanden. Die visuelle Bestätigung der Scrollkorrektur am iPhone steht noch aus.

Die folgende Kopf- und Ansichtsüberarbeitung ergänzt ein unverändertes Symbolasset (identisch mit dem vorhandenen App-Icon), dezente blaue, mintfarbene und goldene Termintöne sowie Tageswischen und Tag-/Wochenwahl. Sieben Swift-Coretests bestehen einschließlich Wischrichtung, vertikaler Abgrenzung und Wochenwechsel über eine Zeitumstellung. Logo-/Icon-Originaldateien, API, Datenbestände und Anmeldung bleiben erhalten. Der native Release-Build, Signierung, Paketprüfung einschließlich beider originalgetreuer Logoassets und Update-Installation bestanden. Wochenansicht, Kalenderdialog, Wischgesten und Kopf benötigen noch die visuelle Bestätigung am Gerät.

## Lokaler Gerätetest

- Server und iPhone ins gleiche Netzwerk bringen. `127.0.0.1` im QR-Code zeigt auf das iPhone, nicht auf diesen PC.
- Django für die Netzwerkadresse starten und diese in `ALLOWED_HOSTS` aufnehmen. Verwaltung und API müssen unter der eingetragenen Adresse erreichbar sein.
- HTTP ist in der App nur für private IPv4-Adressen, `localhost` oder `.local` zugelassen; öffentlich HTTPS nutzen. Keine globale Abschaltung von App Transport Security.
- Kamerazugriff, QR-Anmeldung, manuelle Anmeldung, Neustart mit Keychain-Sitzung, Abmeldung, Serverausfall und Sperren des Zugangs auf einem echten iPhone prüfen.
- Für den Ersttest eine fiktive Einrichtung verwenden. Die Beispielbilder stammen aus einer separaten Testdatenbank.

## API v1

| Endpunkt | Zugriff | Zweck |
|---|---|---|
| `POST /api/student-app/v1/login/` | Ohne Verwaltungskonto | `{code,password}` oder `{access,key}` aus dem QR-Code; liefert Gerätesitzung und Einrichtung/Zielgruppe |
| `GET /api/student-app/v1/feed/?start=2026-10-01&end=2026-11-01` | `Authorization: Bearer <token>` | Freigegebene Termine, Absagen und aktive Mitteilungen; `end` exklusiv, maximal 180 Tage |
| `POST /api/student-app/v1/logout/` | Bearer | Eigene Gerätesitzung beenden |
| `GET/POST /api/student-app/accesses/` | Verwaltungssitzung + CSRF beim POST | Zugänge auflisten/anlegen; POST mit `server` und genau einer `group` oder `cohort` |
| `POST /api/student-app/accesses/<uuid>/disable/` | Verwaltung + CSRF | Zugang sperren, alle Gerätesitzungen widerrufen |
| `GET/POST /api/student-app/notices/` | Verwaltung + CSRF beim POST | Mitteilungen verwalten; POST `{title,body,group?}` oder `{title,body,cohort?}`, ohne Zielgruppe für alle |
| `POST /api/student-app/notices/<id>/withdraw/` | Verwaltung + CSRF | Veröffentlichung zurückziehen |

Der QR-Code enthält JSON `{version:1,server,access,key}`. Die App bestätigt die Serveradresse vor Verbindung. QR-Schlüssel und Gerätetoken sind zufällig und nur als SHA-256-Hash gespeichert; Passwörter mit Djangos Passwort-Hasher. Gerätezugänge erlauben keine Verwaltungs-API und laufen nach 90 Tagen ab. Institution, Gruppe und Jahrgang werden serverseitig bestimmt; Clientfilter können den Zugriff nicht erweitern. Drittanbieter-Weiterleitungen erhalten keine Zugangsdaten.

Die App aktualisiert im Vordergrund alle 60 Sekunden, bei Aktivierung und per Herunterziehen. Ein vorhandener Datenstand bleibt bei Verbindungsfehlern sichtbar; kein dauerhafter Offline-Cache. Mitteilungen sind In-App-Mitteilungen, keine Push-Nachrichten. Ohne Einzelkonten ist keine individuelle Wahlpflichtbelegung oder persönliche Prüfungszulassung möglich.

## Prüfungen

```powershell
.venv/Scripts/python.exe backend/manage.py test planner.test_student_app planner.test_overview --noinput
npm run test:wiki -- tests/student-app.spec.ts
```

Optional kann `STUDENT_APP_FIXTURE` für den Swift-Integrationstest auf eine ausschließlich lokale JSON-Datei mit `server`, `code` und `password` aus der wegwerfbaren Testeinrichtung zeigen. Keine echten Kundenzugänge dafür verwenden und die Datei nicht committen.
