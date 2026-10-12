import { Icon } from "./Icon";

export function PracticeCase() {
  return (
    <section
      id="praxis"
      className="section container practice-section"
      aria-labelledby="practice-title"
    >
      <div className="section-intro">
        <div>
          <p className="section-label">Ein Beispiel aus der Hochschulplanung</p>
          <h2 id="practice-title">
            Ein Raum fällt aus.
            <br />
            Ihr Semesterplan bleibt im Blick.
          </h2>
        </div>
        <p>
          Der Seminarraum ist gesperrt, die Veranstaltung soll stattfinden. In
          CampusZeit prüfen Sie Raum, Lehrende und Gruppen im Zusammenhang und
          geben die Änderung gezielt frei.
        </p>
      </div>
      <div className="practice-example">
        <div className="practice-situation">
          <Icon name="room" />
          <span>Fiktives Planungsszenario</span>
          <h3>Projektmanagement</h3>
          <p>
            Montag, 08:30–10:00
            <br />
            WI26 · Gruppe A
          </p>
          <div className="practice-blocked">Raum A.204 ist gesperrt</div>
          <p>Die bisherige Raumzuordnung muss überprüft werden.</p>
        </div>
        <ol className="practice-actions">
          <li>
            <strong>Belegung und Anforderungen prüfen</strong>
            <p>
              Kapazität und Ausstattung des Ersatzraums berücksichtigen.
              Raumbelegung sowie Überschneidungen von Lehrenden und Gruppen
              prüfen.
            </p>
          </li>
          <li>
            <strong>Den Termin im Entwurf ändern</strong>
            <p>
              Einen passenden Raum zuordnen. Den Plan erneut prüfen; eine
              gespeicherte Änderung ist noch keine neue Freigabe.
            </p>
          </li>
          <li>
            <strong>Den geprüften Stand veröffentlichen</strong>
            <p>
              Nach der Freigabe zeigen Studierendenübersicht und öffentliche
              Anzeigen die neue Planversion. Sperrhinweise für betroffene
              Termine bleiben nachvollziehbar.
            </p>
          </li>
        </ol>
      </div>
      <p className="marketing-caption">
        Illustrativer Ablauf mit fiktiven Daten. Ein gesperrter Raum kann
        bereits im veröffentlichten Plan als Hinweis sichtbar werden. Eine
        Ersatzzuordnung benötigt eine erneute Freigabe.
      </p>
    </section>
  );
}

export function PlanningComparison() {
  const rows = [
    [
      "Raumwechsel abstimmen",
      "Raumliste, Stundenplan und Verfügbarkeiten miteinander abgleichen.",
      "Raumkapazität, Ausstattung und Belegung zusammen mit dem Termin prüfen.",
    ],
    [
      "Gemeinsame Lehrveranstaltungen planen",
      "Zuordnungen in den jeweiligen Gruppen- und Semesterlisten nachhalten.",
      "Mehrere Gruppen, Teilnehmer und Lehrende einer Veranstaltung zuordnen.",
    ],
    [
      "Änderungen weitergeben",
      "Die geänderten Listen und ihren aktuellen Stand abstimmen.",
      "Im Entwurf bearbeiten und den geprüften Stand separat veröffentlichen.",
    ],
  ];
  return (
    <section
      id="zielgruppen"
      className="section container comparison-section"
      aria-labelledby="audience-title"
    >
      <div className="section-intro">
        <div>
          <p className="section-label">Ein gemeinsamer Arbeitsbereich</p>
          <h2 id="audience-title">
            Die Zusammenhänge
            <br />
            planen Sie gleich mit.
          </h2>
        </div>
        <p>
          Tabellen helfen beim Erfassen. CampusZeit verbindet diese Grundlagen
          mit Ihren Terminen und den Prüfungen vor der Freigabe.
        </p>
      </div>
      <div className="comparison-table">
        <table>
          <caption className="sr-only">
            Planungsaufgaben in getrennten Listen und in CampusZeit
          </caption>
          <thead>
            <tr>
              <th scope="col">Ihre Aufgabe</th>
              <th scope="col">In getrennten Listen</th>
              <th scope="col">Mit CampusZeit</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(([task, before, after]) => (
              <tr key={task}>
                <th scope="row">{task}</th>
                <td>
                  <span className="comparison-mobile-label" aria-hidden="true">
                    In getrennten Listen
                  </span>
                  {before}
                </td>
                <td>
                  <span className="comparison-mobile-label" aria-hidden="true">
                    Mit CampusZeit
                  </span>
                  {after}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="marketing-caption">
        Der Vergleich beschreibt typische Arbeitsabläufe. Welche Aufgaben
        CampusZeit in Ihrer Hochschule übernimmt, wird im Pilotbetrieb geprüft.
      </p>
    </section>
  );
}

export function PilotInfo() {
  return (
    <section id="pilot" className="pilot-section" aria-labelledby="pilot-title">
      <div className="container">
        <div className="section-intro">
          <div>
            <p className="section-label">Ein überschaubarer Einstieg</p>
            <h2 id="pilot-title">
              Mit einem Studiengang beginnen.
              <br />
              Am echten Alltag prüfen.
            </h2>
          </div>
          <p>
            Als Einstieg bietet sich ein abgegrenzter Planbereich mit einem
            Semester an. Umfang, Laufzeit, Kosten und Begleitung werden vor dem
            Start individuell vereinbart.
          </p>
        </div>
        <ol className="pilot-steps">
          <li>
            <span>01</span>
            <h3>Ziel und Umfang festlegen</h3>
            <p>
              Studiengang oder Fachbereich auswählen. Gemeinsam festhalten,
              welche Abläufe geprüft werden und wer die Abnahme verantwortet.
            </p>
          </li>
          <li>
            <span>02</span>
            <h3>Grundlagen vorbereiten</h3>
            <p>
              Räume, Lehrende, Verfügbarkeiten, Gruppen und Lehrveranstaltungen
              abstimmen. Datenübernahme und Zugriffsberechtigungen klären.
            </p>
          </li>
          <li>
            <span>03</span>
            <h3>Repräsentative Fälle durchspielen</h3>
            <p>
              Ein Semester planen, einen Raumwechsel bearbeiten und den
              freigegebenen Stand prüfen. Ergebnisse und offene Punkte
              dokumentieren.
            </p>
          </li>
          <li>
            <span>04</span>
            <h3>Den nächsten Schritt entscheiden</h3>
            <p>
              Die Ergebnisse mit den vereinbarten Kriterien vergleichen. Danach
              entscheiden Sie über Anpassungen oder einen größeren Einsatz.
            </p>
          </li>
        </ol>
        <div className="pilot-details">
          <article>
            <h3>Woran Sie den Pilot bewerten können</h3>
            <ul>
              <li>
                Repräsentative Termine und Planungsregeln lassen sich abbilden.
              </li>
              <li>
                Konflikte werden erkannt und lassen sich nachvollziehbar
                bearbeiten.
              </li>
              <li>
                Änderungen erscheinen nach Freigabe in den vorgesehenen
                Ansichten.
              </li>
              <li>
                Ihre Verwaltung kann die vereinbarten Aufgaben selbst
                durchführen.
              </li>
            </ul>
          </article>
          <article>
            <h3>Was in Ihr individuelles Angebot gehört</h3>
            <ul>
              <li>Nutzungsumfang und ausgewählte Planbereiche</li>
              <li>Einrichtung und Datenübernahme</li>
              <li>Betriebsumgebung und Verantwortlichkeiten</li>
              <li>Einführung, Begleitung und Supportumfang</li>
            </ul>
            <p>
              Preis und Leistungsumfang werden passend zu Ihrem Vorhaben
              vereinbart. Es gibt derzeit keine veröffentlichten Standardpreise.
            </p>
          </article>
        </div>
        <div className="pilot-next">
          <p>
            Für das erste Gespräch genügt ein Überblick über Ihren Studiengang,
            die bisherigen Planungsabläufe und die Aufgaben, die Sie erproben
            möchten.
          </p>
          <a className="button primary" href="#kontakt">
            Pilotumfang besprechen
            <Icon name="arrow" />
          </a>
        </div>
      </div>
    </section>
  );
}
