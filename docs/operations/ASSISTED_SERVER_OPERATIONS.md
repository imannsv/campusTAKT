# CampusZeit mit Codex verwalten

Stand: 13.10.2026. Betriebsanforderung und vorbereitete Beispiele; die Server bei Jakob und ihre Zugänge sind noch nicht eingerichtet.

## Arbeitsweise

Iman verwaltet CampusZeit mit Hilfe von Codex aus einem freigegebenen Arbeitsrechner. In der jeweiligen Sitzung müssen Netzwerkzugang, Werkzeuge und Berechtigungen vorhanden sein. Dann kann Codex den lokalen SSH-Client für angefragte Betriebsaufgaben nutzen. Eine eigenständige dauerhafte Serververbindung oder Hintergrundüberwachung ist damit nicht eingerichtet.

Das Ziel ist: Iman nennt Einrichtung und Aufgabe, etwa „Prüfe die Instanz pilot-a“ oder „Spiele die freigegebene Version bei pilot-a ein“. Der Server und die Einrichtung werden anhand des lokalen Betriebsinventars eindeutig bestimmt. Die Bereitstellungsvorlage soll dieses Inventar bei einer Neuanlage mitführen.

## Einmal vorbereiten

1. Tailscale auf dem freigegebenen Arbeitsrechner und den vorgesehenen Servern einrichten. Getrennte Benutzerkonten, MFA und beschränkte Zugriffsregeln verwenden. Gateway und Kundendienste erhalten keine pauschalen Verwaltungsrechte.
2. Einen widerrufbaren Zugang für das Betriebskonto `campuszeit-ops` festlegen. Standard-OpenSSH über das Tailscale-Netz ist der vorgesehene Anfang. Tailscale SSH ist eine mögliche spätere Alternative mit eigenen Netzwerk- und SSH-Regeln, kein zusätzlich benötigter Loginweg.
3. Den privaten, passphrasengeschützten Schlüssel ausschließlich lokal erzeugen und schützen. Nur den öffentlichen Schlüssel auf Servern hinterlegen. Wenn nötig lädt Iman den privaten Schlüssel lokal in den SSH-Agenten. Keine Schlüsseldatei, Passphrase oder Serverpasswörter in Chat oder GitHub kopieren.
4. Server-Hostschlüssel über einen vertrauenswürdigen Weg prüfen und lokal in `known_hosts` eintragen. Für automatisierte Befehle bleiben `BatchMode yes`, `StrictHostKeyChecking yes` und `ForwardAgent no` aktiv. Eine fehlende Freigabe wird behoben; die Hostprüfung wird nicht abgeschaltet.
5. Die Einträge aus `ssh-config.example` mit den echten, geprüften Tailscale-Namen und Benutzern in die lokale SSH-Konfiguration übernehmen. `server-inventory.example.json` lokal ausfüllen, Zielrollen und Instanzen kontrollieren und erst dann `configured` aktivieren. Die Vorlage selbst enthält bewusst nur nicht erreichbare `.invalid`-Adressen.
6. Normale Diagnosen mit dem Betriebskonto ermöglichen. Privilegierte Aufgaben brauchen bewusst eingerichtete Rechte, zum Beispiel eng begrenzte Wartungswerkzeuge. Mitgliedschaft in der Docker-Gruppe beziehungsweise Zugriff auf den Docker-Socket ist umfassende Hostmacht und kein eingeschränkter Betriebszugang. Ein bloßer Inventareintrag setzt weder SSH- noch Betriebssystemrechte durch.

## Vor dem ersten echten Auftrag prüfen

- Im gleichen Ausführungskontext, aus dem Codex arbeitet: Tailscale und Namensauflösung funktionieren; der lokale SSH-Client findet Schlüssel/Agent und die geprüften Hostschlüssel.
- Eine reine SSH-Abfrage des Zielhosts funktioniert ohne Passwort- oder Hostschlüsselrückfrage. Tests führen noch keine Änderung aus.
- Hostname, Serverrolle, Einrichtungskennung und Compose-Projekt stimmen mit dem Inventar überein. Datenserver, Release-Digest und Backupziel sind vollständig zugeordnet.
- Lesen von Status, relevanten Logs und Sicherungszeitpunkt funktioniert. Nicht benötigte Kundeninhalte und Geheimnisse werden nicht ausgelesen oder ausgegeben.
- Ein Neustart und Schlüsselwiderruf wurden getestet. Jakob hat die Notfallanleitung für Strom, Router und Hardware vor Ort.

Die SSH-Beispiele lassen sich ohne Verbindung auf Syntax prüfen:

```powershell
ssh -G -F docs/operations/ssh-config.example campuszeit-pilot-a
```

Dieser Befehl baut keine Serververbindung auf und prüft keine echten Zugangsrechte.

## Wiederkehrende Aufgaben

| Auftrag | Vorgehen |
| --- | --- |
| Zustand prüfen | Ziel abgleichen, Dienste, Version, Worker und letzten Sicherungsstand lesen |
| Fehler untersuchen | Relevante Logs begrenzt lesen, Geheimnisse und personenbezogene Inhalte aussparen |
| Neue Einrichtung | Den vorgesehenen Instanzassistenten nutzen; eigene Daten und Dienste prüfen |
| Update | Freigegebenen Digest auswählen, Sicherung erstellen, Wartung und Migration ausführen, Ergebnis prüfen |
| Restore | Geprüfte Sicherung zunächst in getrennte Testumgebung einspielen und fachlich kontrollieren |

Arbeiten erfolgen im Umfang des jeweiligen Auftrags. Datenlöschung, Überschreiben einer Instanz und ungeklärte Zielzuordnung brauchen eine konkrete Entscheidung. Bestehende Freigaben werden weiterverwendet. Nach Änderungen werden Ergebnis und installierte Version dokumentiert; neue Geheimnisse werden nicht protokolliert. Die Erreichbarkeit eines Servers ist keine pauschale Berechtigung für alle Kundendaten oder andere Geräte bei Jakob.

## Aktueller Stand

Auf Imans Entwicklungsrechner ist ein OpenSSH-Client vorhanden. Die Beispielkonfiguration wurde mit `ssh -G` für alle vier Aliasse syntaktisch geprüft. Es wurden weder private Schlüssel angelegt noch lokale SSH-Einstellungen verändert oder Serververbindungen getestet. Inventar und Vorlagen enthalten keine Zugangsdaten. Produktive Rechte, Wartungswerkzeuge und der Instanzassistent werden erst mit dem Betriebsaufbau implementiert.

## Quellen

- [OpenSSH-Clientkonfiguration: BatchMode, Hostprüfung, Schlüssel und Agentweitergabe](https://man.openbsd.org/ssh_config)
- [OpenSSH-Serverkonfiguration](https://man.openbsd.org/sshd_config)
- [Tailscale-Zugriffsregeln](https://tailscale.com/docs/features/access-control)
- [Tailscale SSH als Alternative](https://tailscale.com/docs/features/tailscale-ssh)
- [Docker Engine: Rechte und Angriffsfläche](https://docs.docker.com/engine/security/)
