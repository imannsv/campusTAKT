# CampusZeit: Infrastruktur- und Startplan

Stand: 13.10.2026. Grober Plan, keine ausgeführte Infrastrukturänderung.

## Der Weg zum ersten Pilot

ENTSCHEIDUNG UND AUSGANGSLAGE

> Empfehlung: mit vorhandener Hardware starten, einen überschaubaren Pilot betreiben und den späteren Umzug in ein Rechenzentrum von Anfang an vorbereiten.

Du möchtest CampusZeit öffentlich vorführen und anschließend mit einer ersten Hochschule erproben. Die virtuellen Umgebungen sollen getrennte Aufgaben haben und kontrolliert miteinander kommunizieren. Dieser Plan beschreibt Einrichtung und Reihenfolge; er installiert noch nichts und enthält keine Buchung oder Kontaktaufnahme.

| Rechner | Bekannter Stand | Vorgesehene Aufgabe |
| --- | --- | --- |
| Dell Precision 3440 | Intel Core i5, 10. Generation; RAM und Speicher erweitert | Proxmox und getrennte VMs für Anwendung, Datenbank und Tests |
| HP Pro Mini | Intel Core i3; Speicher erweitert | Eigener Sicherungsrechner; später Wiederherstellung prüfen |

### Was bereits im Projekt vorhanden ist

React/TypeScript-Oberfläche, Django-Backend, PostgreSQL-Konfiguration, Redis, Celery-Planungsworker, Dockerfile und Compose-Datei. Es gibt eine Betriebsanleitung, Kundenanlage und einen lokalen Backupdienst. Die neue iPhone-App und automatische Ausfallmitteilungen liegen noch auf dem offenen App-Branch; sie sind vor einer Pilotbereitstellung als geprüfte Version zusammenzuführen. [R1, R2]

### Die Reihenfolge

1. Hardware und Internetanschluss prüfen; vollständige Sicherung vorhandener Rechnerdaten erstellen.
2. Privaten Betriebsaufbau einrichten und Wiederherstellung testen.
3. Domain, HTTPS und eine öffentliche Demo mit fiktiven Daten bereitstellen.
4. Pilotgespräche führen; erst nach Freigabe echte Hochschuldaten übernehmen.

Offen: tatsächliche RAM-Größen, Laufwerke und freie Kapazitäten, genauer i3, Router/Internetanbieter, öffentlicher Zugang oder DS-Lite, verfügbare Uploadrate. Hardware wurde hier nicht vermessen. Die unten genannten Größen sind Startannahmen, kein Kapazitätsnachweis.

## So kommunizieren die Umgebungen

ZIELARCHITEKTUR FÜR EINEN PILOT

```text
Browser / iPhone -> HTTPS-Gateway (Hetzner / Caddy)
                             | WireGuard
                  Dell Precision 3440 / Proxmox
                  App-VM -> Daten-VM (PostgreSQL, Redis)
                             | Backup
                  HP Pro Mini -> verschlüsselte externe Kopie

Website/Landingpage separat, z.B. Vercel
```

Die Website kann unabhängig auf Vercel bleiben. Der Pilot verwendet für Oberfläche und API dieselbe Hochschuladresse; dadurch bleiben Anmeldung, Cookies und QR-Serveradresse übersichtlich. Der Gateway ist ein Vorschlag und noch nicht bestellt.

| Verbindung | Erlaubter Zweck | Begrenzung |
| --- | --- | --- |
| Browser / iPhone > Gateway | HTTPS auf 443; 80 für Umleitung/Zertifikat | Nur vorgesehene Domain |
| Gateway > Anwendungs-VM | Webzugriff über WireGuard | Nur interne App-Adresse/Port |
| Anwendungs-VM > Daten-VM | PostgreSQL 5432, Redis 6379 | Nur App/Worker und passende Konten |
| Betrieb > Serververwaltung | SSH, Proxmox 8006, Backupverwaltung | Nur privates Admin-VPN |
| Server > HP Mini / extern | Abgeschlossene Sicherungen | Eigene Sicherungskonten und Schlüssel |

Proxmox stellt die VM-Umgebungen bereit; Docker Compose organisiert die Dienste innerhalb der Linux-VMs. Firewall-Regeln trennen Anwendung, Daten und Administration. Eine zweite VM alleine schützt nicht vor einem offenen Datenbankport. [1, 3, 4]

## Die Rechner einrichten

VIRTUALISIERUNG UND GETRENNTE INSTANZEN

### 1. Bestand aufnehmen, bevor etwas installiert wird

In BIOS/UEFI Virtualisierung prüfen. RAM, SSD/HDD-Modell, Gesundheitszustand, freien Speicher und bestehende Projekte erfassen. Vorhandene Daten extern sichern. Proxmox-Installation kann den gewählten Datenträger überschreiben: erst nach geprüftem Backup und bewusst gewähltem Ziellaufwerk installieren. Proxmox benötigt neben seinem eigenen Speicher zusätzliche Ressourcen für die VMs. [1]

| Umgebung auf dem Precision | Startannahme | Inhalt |
| --- | --- | --- |
| app-pilot | 4 vCPU / 4 GB RAM / 60 GB | Django, Oberfläche, Celery, Medienvolume |
| data-pilot | 2 vCPU / 4 GB RAM / 80 GB | PostgreSQL 17 und privates Redis |
| test-campuszeit | 2 vCPU / 4 GB RAM / 60 GB | Getrennter Teststack mit eigener Datenbank |
| Proxmox / Reserve | Mindestens 4 GB RAM frei | Host, Dateisystem und Puffer |

Für diese Zuordnung mindestens 16 GB nutzbaren RAM prüfen; 32 GB geben mehr Spielraum. vCPUs sind Zuteilungen, keine zusätzlichen physischen Kerne. Bei knappen Ressourcen die Test-VM nur bei Bedarf starten. Solver-CPU und RAM zuerst messen; Parallelität anfangs auf einen Planungsauftrag begrenzen.

### 2. Linux-VMs und privates Netz

Auf jeder VM eine unterstützte Debian- oder Ubuntu-LTS-Version installieren. Feste interne Adressen, SSH-Schlüssel, Firewall, Sicherheitsupdates und Zeitsynchronisation einrichten. Startadresse und internes Netz erst nach Abgleich mit deinem Heimnetz festlegen. Die Daten-VM erhält keinen öffentlichen Webzugang.

### 3. HP Mini als eigener Backuprechner

Wenn RAM und Laufwerke passen: Proxmox Backup Server direkt auf dem HP Mini einrichten, mit eigenem Systemlaufwerk und ausreichend Sicherungsspeicher. Als Planwert 8 GB RAM plus Speicherbedarf prüfen; der Hersteller empfiehlt mindestens 4 GiB plus zusätzlichen RAM pro TiB. Auf diesem Rechner keine produktive Datenbank unterbringen, von der die Anwendung ständig abhängt. [2]

### 4. Später eine Instanz je Hochschule

Für den ersten Pilot ein eigenes App-/Daten-Paar. Eine weitere Hochschule erhält eigene Laufzeit, Datenbank, Datenbankkonto, Redis, Medien, Geheimnisse, Domain und Sicherungen. Gleicher freigegebener Code, getrennte Konfiguration. Eine Subdomain oder ein Git-Branch allein trennt keine Kundendaten. Vor jeder neuen Instanz Ressourcenbudget und Zugriffstrennung prüfen; kein Zwei-Rechner-HA-Cluster zum Start.

## CampusZeit in den VMs betreiben

VOM VORHANDENEN PROJEKT ZUM BETRIEB

> Die aktuelle Compose-Datei startet alle Dienste auf einem gemeinsamen Host. Für zwei VMs muss sie gezielt aufgeteilt werden; diese Konfiguration ist noch nicht umgesetzt.

| Vorhanden | Für diesen Aufbau anzupassen |
| --- | --- |
| Dockerfile: regulärer Build, Gunicorn; Compose: web und worker | App/Worker auf app-pilot; Start nach Abnahme einer festen Codeversion |
| Compose-Datenbankname db; Redisname redis | Für VM-übergreifende Verbindungen private Adressen und DB-/Redis-Authentifizierung konfigurieren |
| Webport nur 127.0.0.1:8000 | Gateway-Zugang ausschließlich auf der WireGuard-/privaten Adresse binden und per Firewall begrenzen |
| Medienvolume und backup.sh | Medien auf app-pilot sichern; Backupdienst auf neue DB-Adresse und externes Ziel abstimmen |

1. Getrennte Betriebsdateien für App-VM und Daten-VM erstellen. Produktionsdaten nicht aus der lokalen SQLite-Testdatenbank ungeprüft übernehmen.
2. PostgreSQL und Redis privat starten. Datenbankrolle nur für diese Instanz; PostgreSQL-Zugriff auf App-IP begrenzen, TLS für TCP-Verbindungen vorsehen. Redis mit Authentifizierung und geschütztem Netz betreiben. [4]
3. Geheimnisse außerhalb von Git hinterlegen. DEBUG=0, LOCAL_WORKER=0, SECRET_KEY, POSTGRES_HOST und REDIS_URL setzen. Docker-Secrets benötigen beim jetzigen Django-Setup zusätzlich eine passende Datei-Leseintegration; _FILE wird nicht automatisch verarbeitet. [3]
4. Image bauen, Migrationen einmal vor Web/Worker-Start ausführen und ein gesondertes Betriebskonto anlegen. Keine seed_demo- oder seed_showcase-Daten im Kundenbetrieb.
5. Einrichtung über den vorhandenen provision-Befehl anlegen; Kundenkonto ohne staff-/Superuserrechte. Lizenzende und verantwortliche Person festhalten. [R1]
6. Django-Hosts und CSRF-Ursprünge auf die echte HTTPS-Domain setzen. Bei TRUST_PROXY=1 darf nur der vertrauenswürdige Proxy zugreifen; er überschreibt X-Forwarded-Proto. [R1]
7. Anmeldung, Planung/Worker, Veröffentlichung, öffentliche Anzeigen, QR-Zugang, Ausfallmitteilung und Backup-Wiederherstellung mit getrennten Testdaten prüfen.

Updateweg: freigegebener Commit > Test-VM > Abnahme > zusätzliches Backup > angekündigtes Wartungsfenster > Migration > neue Container > Funktionstest. Bei Datenbankmigrationen keine parallelen Schreibvorgänge; Rückkehr zur alten Version nur mit geprüftem Schema-/Restoreplan.

## Domain und öffentlicher Zugang

WEBSITE, PILOTADRESSE UND E-MAIL

Erst Namen und Verfügbarkeit prüfen, dann eine Hauptdomain registrieren. Verlängerungskosten prüfen, Anbieterzugang mit MFA schützen und automatische Verlängerung aktivieren. Alle folgenden Adressen mit .example sind unverbindliche Beispiele; es wurde keine Domain reserviert.

| Adresse als Beispiel | Ziel / Umsetzung |
| --- | --- |
| www.campuszeit.example | Jakobs Landingpage; eigenes Hostingprojekt und Landingpage-Branch |
| demo.campuszeit.example | Demo mit ausschließlich fiktiven Daten; getrennt vom Kundenbetrieb |
| pilot-a.campuszeit.example | Erste Hochschulinstanz: Oberfläche, /api und /wiki über Gateway |
| kontakt@campuszeit.example | Eigenes geschäftliches Postfach beim Mailanbieter |

### Empfohlener Zugang: kleiner Gateway in Deutschland

Ein kleiner Hetzner-VPS erhält die öffentliche Adresse. Der Homeserver baut eine ausgehende WireGuard-Verbindung dorthin auf; Caddy nimmt HTTPS an und reicht Anfragen durch den Tunnel zur App-VM weiter. Das ist ein Entwurf, den wir mit deinem Anschluss testen. Er funktioniert grundsätzlich auch ohne eingehend erreichbare Heim-IP, solange die nötigen ausgehenden Verbindungen erlaubt sind. [5, 6, 7]

Alternative A: Cloudflare Tunnel für eine schnelle Demo, mit ausgehender Verbindung ohne offene Heimports. Vor echten Hochschuldaten zusätzlich Anbieter, Vertragslage und Datenfluss freigeben. Alternative B: öffentliche Heim-IP plus DNS-Aktualisierung und Portweiterleitung nur zum Proxy; zuerst Anschluss und Router prüfen. Keine Datenbank-, SSH- oder Proxmox-Freigabe am Heimrouter. [8]

### Einrichtung in dieser Reihenfolge

1. Domain registrieren; einen verantwortlichen Inhaber und DNS-Anbieter festlegen.
2. Landingpage-Domain im Hostingprojekt hinzufügen. Die dort angezeigten A/CNAME/TXT-Werte exakt übernehmen; keine IP-Werte aus alten Beispielen kopieren. [9]
3. Pilot-Subdomain per A, gegebenenfalls AAAA, auf den Gateway legen. AAAA nur bei funktionierendem IPv6. Gateway, WireGuard und Caddy einrichten; Zertifikat und Umleitung auf HTTPS prüfen. [5, 10]
4. Geschäftliches Postfach anlegen; MX, SPF, DKIM und DMARC nach Mailanbieter einrichten. Versand und Antwort aus einem anderen Netzwerk testen.

Vercel bleibt für die Website möglich. Hobby ist laut Anbieter nur für persönliche, nichtkommerzielle Nutzung vorgesehen; für die geplante kommerzielle Landingpage geeigneten Tarif einplanen. Das vollständige Backend mit dauerhaftem Solver läuft auf dem Server. [11]

## Sichern, überwachen, wiederherstellen

WAS DER MINI-PC LEISTET UND WAS OFFEN BLEIBT

### Drei Kopien und ein Standort außerhalb des Hauses

Produktivdaten liegen auf dem Precision. Der HP Mini erhält unabhängige Sicherungen. Eine weitere verschlüsselte Kopie wird an einem anderen Standort oder in vertraglich passendem EU-Speicher aufbewahrt. Zwei Rechner im selben Haus verlieren bei Brand, Diebstahl oder gemeinsamem Stromausfall gleichzeitig ihre Verfügbarkeit.

| Sicherung | Vorgeschlagener Start | Erfolgskriterium |
| --- | --- | --- |
| Datenbank und Medien | Täglich und vor jedem Update; RPO-Ziel 24 Stunden | Passender DB-/Medienstand mit manifestierter Codeversion |
| VMs > HP Mini | Nächtlich; z.B. 7 tägliche / 4 wöchentliche / 3 monatliche Stände | Prüfung/Verifikation erfolgreich, Speicherbedarf gemessen |
| Verschlüsselte externe Kopie | Täglich; eigener Zugang und separate Schlüsselaufbewahrung | Nicht nur dieselbe Platte oder ungeschützter Dateisync |
| Wiederherstellung | Vor Pilotbeginn und dann monatlich | Leere Testumgebung startet; Anmeldung/Pläne/Dateien geprüft |

Der heutige Backupdienst sichert täglich Datenbank und Medien nacheinander und bewahrt lokale Archive 14 Tage auf. Neue VM-Aufteilung, Ziele, Aufbewahrung und Backup-Überwachung müssen angepasst werden. Ein VM-Snapshot ersetzt kein Datenbank-/Dateibackup. Für konsistente DB- und Medienstände Schreibvorgänge im Sicherungsfenster pausieren oder einen abgestimmten Snapshot-Ablauf verwenden. [R1]

### Ausfall erkennen, statt nur Dateien abzulegen

Von außerhalb des Heimnetzes HTTPS und /api/health/ überwachen. Zusätzlich Worker-Warteschlange, Testplanungsjob, letzte erfolgreiche Sicherung, freien Speicher und Zertifikat kontrollieren. Alarm an eine tatsächlich betreute Adresse senden. Monitoring nur auf dem HP Mini erkennt einen Ausfall des gesamten Hauses nicht zuverlässig.

### Wartung und Ausfallziel

Als internes Pilotziel: höchstens 24 Stunden Datenverlust aus den täglichen Sicherungen und Wiederherstellung innerhalb eines Arbeitstags. Diese RPO-/RTO-Ziele sind erst nach einem echten Restoretest belastbar und noch kein SLA. UPS für Server, Router und Netzwerk prüfen. Der HP Mini ist kein automatisch umschaltender Ersatzserver; dortiges Wiederanlaufen nur nach gemessenem RAM-/Speicherbedarf planen.

Die Studierenden-App hält zuvor geladene Pläne und Mitteilungen offline vor. Neue Änderungen erreichen sie erst mit Verbindung. Ein Gateway hält die Adresse stabil, verhindert aber keinen Homeserver- oder Heimanschlussausfall. Vor verbindlichen Verfügbarkeitszusagen die produktive Instanz auf geeignetes Hosting umziehen.

## Vom Aufbau zu Hochschulgesprächen

ABLAUF MIT ERGEBNISSEN STATT FESTEN VERSPRECHEN

| Phase ab Start | Arbeit | Ergebnis |
| --- | --- | --- |
| Woche 1 | Hardware/Netz prüfen, Domain wählen, Sicherungen und VM-Grundaufbau | Private Umgebung und gesicherter Bestand |
| Woche 2 | Compose aufteilen, Testinstanz, HTTPS, Domain-Mail, Restoretest | Öffentliche Demo und dokumentierter Betriebsnachweis |
| Woche 2-3 parallel | 5-10 passende Hochschulen recherchieren; warme Kontakte/Einführungen | 2-3 Bedarfsgespräche als Arbeitsziel |
| Woche 3-4 | Pilotumfang, Verantwortliche, Datenbedarf und Vertragsunterlagen klären | Ein vereinbarter, begrenzter Pilot |
| Danach 4-6 Wochen | Pilot begleiten, Fehler priorisieren, Aufwand/Last messen | Gemeinsame Entscheidung über nächsten Betriebsschritt |

Zeitangaben sind grobe Planwerte, keine Lieferzusagen. Hardware, Rechte und Hochschulbeschaffung können länger dauern. Gespräche können bereits mit einer sauberen Demo beginnen; echte personenbezogene Daten folgen erst nach Freigabe.

### Was wir vor dem ersten Gespräch bereitstellen

1. Eine Seite zum Nutzen: Stunden- und Prüfungsplanung, Raum-/Lehrendenbelegung, öffentliche Anzeigen, Studierenden-App. Zielgruppe und aktueller Funktionsumfang klar benennen.
2. Eine 15-minütige Demo mit erfundenen Personen, sichtbarem Veröffentlichungsablauf und Absagefall vorbereiten. Website mit Kontaktweg und vollständigen Betreiberangaben bereitstellen.
3. Für Studienorganisation/Stundenplanung und IT je einen passenden Kontakt ermitteln. Bestehende Kontakte um eine Einführung bitten oder vorgesehene Pilot-/Innovationswege nutzen.
4. Pilot begrenzen: ein Studiengang/Jahrgang, wenige planende Konten, feste Dauer und drei messbare Ziele, etwa Planerstellungszeit, Konflikte und Supportaufwand.

### Vor Übernahme echter Daten

Mit der Hochschule Rollen, Auftragsverarbeitung, technische/organisatorische Maßnahmen, Unterauftragnehmer, Speicherorte, Lösch-/Exportweg und Notfallkontakt klären. Datenschutz- und IT-Verantwortliche müssen den konkreten Betrieb freigeben. Separate Instanzen ersetzen diese Prüfung nicht. Unaufgeforderte Werbe-E-Mails auch an Einrichtungen grundsätzlich nicht ohne passende Einwilligung senden; veröffentlichte Kontaktadressen alleine genügen nicht. [12, 13]

iPhone: derzeit lokale Testsignierung, keine reguläre Store-Verteilung; belastbaren Verteilungsweg für den Pilot festlegen. Sofortiger Push bei geschlossener App/APNs und Android bleiben offene Produktarbeiten. Im Gespräch nur geprüfte Eigenschaften zusagen. Lizenzmodell zunächst betreut je Einrichtung, mit Laufzeit, Leistungsumfang, Support und vereinbartem Ausstiegs-/Datenexportweg.

## Budget und erste Aufgaben

ENTSCHEIDUNGEN VOR DEM KAUF

| Posten | Grobe Planreserve | Annahme |
| --- | --- | --- |
| Domain | 10-30 EUR / Jahr | Endung und Verlängerung vor Kauf prüfen |
| Gateway-VPS | 5-15 EUR / Monat | Kleine Instanz; IPv4/Steuern mitrechnen |
| Externes Backup | 5-15 EUR / Monat | Abhängig von Kapazität und Aufbewahrung |
| E-Mail | 0-10 EUR / Monat | Ein Geschäftspostfach; Anbieter prüfen |
| Strom beider Rechner | ca. 10-20 EUR / Monat | 40-80 W gesamt, 720 h, 0,35 EUR/kWh |

Rechnerisch etwa 21-63 EUR monatlich einschließlich anteiliger Domain, ohne Website-Tarif, Hardwarekauf, UPS, Arbeitszeit und professionelle Unterstützung. Das sind eigene Budgetannahmen, keine aktuellen Anbieterangebote. Für die Landingpage kommt gegebenenfalls ein kommerzieller Hostingtarif hinzu; Vercel nennt derzeit 20 USD monatliche Pro-Plattformgebühr zuzüglich möglicher Nutzung, Zusatzplätze und Steuern. Preise vor Bestellung prüfen. [6, 11]

### Die drei nächsten konkreten Aufgaben

1. Du: RAM, Laufwerke, freier Speicher und Anschlussart beider Rechner dokumentieren; vorhandene Daten sichern. Dann entscheiden wir die endgültigen VM-Größen.
2. Gemeinsam: Hauptdomain und monatliches Budget festlegen; anschließend Gateway oder Tunnel auswählen. Erst danach kaufen und DNS ändern.
3. Umsetzung: eigene Betriebsdateien für App-/Daten-VM, Backupplan und Restore-Protokoll erstellen; danach die öffentliche Demo und erste Pilotgespräche vorbereiten.

> Vor dem Datenpilot abhaken: HTTPS und Anmeldung extern getestet; keine offenen Datenports; Kunde ohne Superuserrechte; Geheimnisse geschützt; Wiederherstellung bestanden; Monitoring alarmiert; Hochschulfreigabe und Pilotumfang dokumentiert.

Ungeprüft: tatsächliche Hardwareleistung, Zugang durch den Heimanschluss, Domainverfügbarkeit, laufende Anbieterpreise und Anforderungen einer konkreten Hochschule. Keine Serverinstallation, Domainbestellung, DNS-Änderung oder E-Mail-Versendung wurde durch diesen Plan ausgeführt.

Arbeitsfassung vom 13.10.2026. Der folgende Quellenanhang macht Herstellerangaben, Projektstand und Planannahmen nachvollziehbar.

## Quellen und Projektbezug

GEPRÜFT AM 13.10.2026

Hersteller- und Rechtsquellen belegen die jeweils markierten Aussagen. Auslegung, VM-Aufteilung, Zeitplan und Budget sind Vorschläge für CampusZeit. Diese Planung ersetzt keine konkrete Hardwaremessung oder vertragliche Betriebsfreigabe.

[1] Proxmox VE: Hardwareanforderungen: [Quelle](https://www.proxmox.com/en/products/proxmox-virtual-environment/requirements)

[2] Proxmox Backup Server: Installation und Anforderungen: [Quelle](https://pbs.proxmox.com/docs/installation.html)

[3] Docker: Compose-Secrets und Dateiübergabe: [Quelle](https://docs.docker.com/compose/how-tos/use-secrets/)

[4] PostgreSQL: Hostzugriff und hostssl: [Quelle](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)

[5] Caddy: Automatisches HTTPS: [Quelle](https://caddyserver.com/docs/automatic-https)

[6] Hetzner Cloud: verfügbare Ressourcen und Preisprüfung: [Quelle](https://www.hetzner.com/cloud/)

[7] WireGuard: Einrichtung und NAT-Keepalive: [Quelle](https://www.wireguard.com/quickstart/)

[8] Cloudflare Tunnel: ausgehende Verbindungen: [Quelle](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)

[9] Vercel: Eigene Domain hinzufügen: [Quelle](https://vercel.com/docs/domains/working-with-domains/add-a-domain)

[10] DNS: A-, AAAA-, CNAME- und TXT-Einträge: [Quelle](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/)

[11] Vercel: Hobby-Nutzungsgrenze / Pro-Kosten: [Quelle](https://vercel.com/docs/plans/hobby), [Quelle](https://vercel.com/docs/plans/pro-plan)

[12] DSGVO: insbesondere Artikel 28 und 32: [Quelle](https://eur-lex.europa.eu/legal-content/EN-DE/TXT/?from=EN&uri=CELEX%3A32016R0679)

[13] UWG § 7: elektronische Werbung und Einwilligung: [Quelle](https://www.gesetze-im-internet.de/uwg_2004/__7.html)

[R1] Projekt: compose.yaml, Dockerfile, Backupskript und Betriebsanleitung: [Quelle](https://github.com/imannsv/campusTIME/blob/main/docs/OPERATIONS.md), [Quelle](https://github.com/imannsv/campusTIME/blob/main/compose.yaml)

[R2] Aktuelle App-Entwicklung: PR #16, Stand 7bf29b5: [Quelle](https://github.com/imannsv/campusTIME/pull/16), [Quelle](https://github.com/imannsv/campusTIME/blob/codex/student-ios-app/docs/STUDENT_APP.md)
