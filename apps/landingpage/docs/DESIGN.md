# CampusZeit Landingpage

## Auftrag und Grenzen

Die Seite erklärt Hochschulverwaltungen das aktuelle Produkt und führt zur Browser-Demo oder zum Gespräch über einen Pilotbetrieb. Der am 09.10.2026 bestätigte Entwurf überträgt die Planungszentrale der Anwendung auf die Landingpage. Umsetzung auf dem vorgegebenen Branch `landingpage`, ausschließlich unter `apps/landingpage`.

## Gestaltung

Farben: Campusblau `#214b76`, Text `#24374c`, Mintflächen `#e4f2ed`, heller Hintergrund `#f4f7fa`, Weiß `#ffffff`, Nebeninformation `#52677b`. DM Sans für Überschriften, Fließtext und die unveränderte Wortmarke, lokal ausgelieferte Schriftdateien. Links ausgerichtete Texte, klare Linien und großzügige Abstände. Heller Ablaufbereich; blaues Kontaktfeld und dunkler Footer mit weißer Fläche für das Original-Logo.

Die Wochenplanung ist das zentrale visuelle Motiv. Eine große, ausdrücklich fiktive Produktvorschau zeigt die Navigation links, den Wochenplan mittig und die ausgewählten Termindetails rechts. Beispieltermine sind mit Maus und Tastatur auswählbar; Raum- und Prüfungsansichten ergänzen die Vorschau. Auf Mobilgeräten erscheinen Termine als Liste und Details darunter. Ohne JavaScript bleiben Inhalt und FAQ lesbar; Terminwahl ist deaktiviert und als statische Vorschau erklärt. Keine erfundenen Kundenreferenzen, Erfolgskennzahlen oder dekorativen Stockbilder.

```text
Logo                  Produkt | Ablauf | Für Hochschulen | Fragen      Demo
Die Planungszentrale für Ihren Hochschulalltag
Demo ausprobieren / Pilotbetrieb besprechen
Große Produktansicht: Navigation | Wochenplanung | Termindetails
Produktansichten: Stundenplan / Räume / Prüfungen
Vier tatsächliche Schritte von Einrichtung bis Veröffentlichung
Studienstruktur                     Planung abstimmen
Freddy und seine nachvollziehbaren Grenzen
Individuelles Angebot / Kontakt
FAQ                                 Footer / Rechtliche Seiten
```

## Technik und Inhalte

Eigenständiges React-/TypeScript-/Vite-Projekt mit eigenem Lockfile. React-Rendering beim Build erzeugt vollständige HTML-Dateien für `/`, `/impressum/`, `/datenschutz/` und `/404.html`; der Client hydriert nur für Interaktionen. Keine Produkt-API, Tracker, Fremdeinbettungen oder Formulardienste. Schriften, Logo, Favicon und Vorschaugrafik gehören zum eigenen Projekt.

Demo-Link: `https://campustime-flame.vercel.app`, am 06.10.2026 per HTTP geprüft. Der Text nennt Testdaten, Browser-Speicherung und fehlende automatische Backendplanung. Freddy wird als Hilfe und Navigation beschrieben; das lokale Sprachmodell ist optional.

Kontakt erfolgt nach Bereitstellung einer Adresse per `mailto:`. Ohne Adresse wird kein funktionierender Versand behauptet; stattdessen steht ein klarer Hinweis neben dem Demo-Link. Impressum und Datenschutz zeigen zunächst einen ausdrücklich unfertigen Entwurfsstand. Freigegebene Inhalte werden in `content/legal.json` eingetragen. `SITE_URL`, `CONTACT_EMAIL` und `PUBLIC_RELEASE` steuern Metadaten und Freigabe. Ein öffentlicher Build setzt vollständige, freigegebene Angaben voraus. Vorher: `noindex`, gesperrte robots.txt und keine erfundene Canonical-Domain.

## Prüfung und Übergabe

Node-Tests prüfen Freigabevalidierung, Domain-/E-Mail-Eingaben und Branch-Buildfilter. Playwright prüft Navigation, Vorschau, FAQ, Rechtsseiten, JavaScript-freie Inhalte, mobile Breiten und Barrierefreiheit mit axe. Zusätzlich echte Browser- und Screenshotprüfung. Separates Vercel-Projekt: Root `apps/landingpage`, Production Branch `landingpage`, Ignored Build Step nur für diesen Branch. Veröffentlichung und Projektzugriff hängen von vorhandener Authentifizierung und bestätigten Anbieterangaben ab.
