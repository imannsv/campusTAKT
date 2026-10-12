Die Studierenden-App bietet ausschließlich Lesezugriff: Stundenplan, Prüfungen und wichtige Mitteilungen. Es gibt keine Einzelkonten für Lernende. Die Verwaltung stellt einen gemeinsamen Zugang für eine Gruppe oder einen Jahrgang bereit.

![Verwaltung von App-Zugängen und Mitteilungen in der fiktiven Beispieleinrichtung](/api/wiki/assets/student-app.png)

## Zugang bereitstellen

1. Öffne **Studierenden-App** unter **Veröffentlichung**.
2. Klicke auf **Zugang erstellen** und wähle eine Gruppe oder einen Jahrgang. Ein Jahrgangszugang umfasst dessen Gruppen.
3. Trage die vom iPhone erreichbare CampusZeit-Serveradresse ein, zum Beispiel die HTTPS-Adresse der eigenen Einrichtung. Die Adresse benötigt keinen zusätzlichen Pfad.
4. Erstelle den Zugang. Speichere den angezeigten QR-Code oder kopiere die Zugangsdaten. Passwort und QR-Code werden ausschließlich jetzt angezeigt.
5. Teile diese Angaben mit der Zielgruppe. Verwende dafür kein Verwaltungskonto.

Für einen lokalen Test müssen Server und iPhone im selben Netzwerk sein. **localhost** und **127.0.0.1** bezeichnen auf dem iPhone das iPhone selbst. Der lokale Server muss unter seiner Netzwerkadresse erreichbar und dafür konfiguriert sein. Verwende im öffentlichen Betrieb HTTPS.

## Auf dem iPhone anmelden

Öffne die installierte CampusZeit-App und wähle **QR-Code scannen**. Erlaube den Kamerazugriff, scanne den bereitgestellten Code und bestätige die angezeigte Serveradresse. Alternativ gib Serveradresse, Zugangscode und Passwort ein. Ein QR-Code ist ein Zugangsschlüssel; veröffentliche ihn nicht außerhalb der Zielgruppe.

Die erste Version ist als native iPhone-App mit Xtool gebaut. Release-Build und lokale Testsignierung bestehen; Installation und Gerätetest stehen noch aus. Eine Testsignierung läuft ab und ersetzt keine spätere App-Store-Veröffentlichung. Android ist der anschließende Schritt. Die Browser-Demo kann keine echten App-Zugänge bereitstellen.

## Was Studierende sehen

**Stundenplan** zeigt die ausgewählte Woche mit chronologischen Tageslisten. Beim Öffnen ist die aktuelle Woche ausgewählt. Im Kalender lässt sich eine andere Woche auswählen; **Diese Woche** führt zurück. Ein Termin öffnet seine Details.

**Prüfungen** zeigt freigegebene zeitgebundene Prüfungen für heute und die nächsten 120 Tage. Änderungen an Entwürfen erscheinen erst nach [Veröffentlichung](/wiki/publication). Abgesagte Termine bleiben sichtbar, rot markiert und durchgestrichen. Persönliche Noten, Teilnehmerlisten und unveröffentlichte Prüfungsanforderungen werden nicht übertragen.

**Mitteilungen** zeigt die veröffentlichten Hinweise für die Einrichtung und die zugehörige Gruppe beziehungsweise den Jahrgang. Die App aktualisiert bei erneuter Aktivierung, per Herunterziehen und im Vordergrund regelmäßig. Bei Verbindungsproblemen bleiben die zuletzt geladenen Inhalte der geöffneten App mit ihrem Datenstand sichtbar. Nach einem Neustart ist eine Verbindung zum Laden erforderlich.

## Mitteilung veröffentlichen oder zurückziehen

Klicke in der Verwaltung auf **Mitteilung erstellen**. Wähle eine Zielgruppe oder **Alle Studierenden**, erfasse Titel und Text und klicke **Veröffentlichen**. Mit **Zurückziehen** entfernst du die Mitteilung aus der App. Es werden noch keine Push-Nachrichten auf den Sperrbildschirm versendet.

## Zugang sperren oder ersetzen

**Sperren** beendet alle Gerätesitzungen dieses Gruppenzugangs. Für neue Zugangsdaten sperre den bisherigen Zugang und erstelle einen neuen. Auf einem iPhone beendet **Mein Zugang → Auf diesem Gerät abmelden** nur die eigene Sitzung. Gerätesitzungen laufen nach 90 Tagen ab und erfordern dann eine erneute Anmeldung.

Ein geteilter Zugang kann von Empfängern weitergegeben werden. Ohne Einzelkonten kann die App keine individuelle Wahlpflichtbelegung oder persönliche Prüfungszulassung nachweisen; sie zeigt die freigegebenen Termine der gesamten zugeordneten Gruppe beziehungsweise des Jahrgangs.
