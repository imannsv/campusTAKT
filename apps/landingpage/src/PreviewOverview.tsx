import { Icon } from "./Icon";
export type PreviewView = "dashboard" | "schedule" | "rooms" | "exams";
export type PreviewScope = "all" | "A" | "B";

export function PreviewDashboard({
  enhanced,
  onNavigate,
}: {
  enhanced: boolean;
  onNavigate: (view: PreviewView) => void;
}) {
  return (
    <div className="cz-dashboard">
      <div className="cz-welcome">
        <div>
          <span>Campus Nord · Hochschule & Akademie</span>
          <h3>Guten Morgen</h3>
          <p>Ihr Campus im Überblick. Dienstag, 20. Oktober 2026</p>
          <button
            className="cz-action"
            type="button"
            disabled={!enhanced}
            onClick={() => onNavigate("schedule")}
          >
            <Icon name="calendar" />
            Zur Stundenplanung
          </button>
        </div>
        <div className="cz-date">
          <span>Oktober 2026</span>
          <strong>20</strong>
          <span>Dienstag · KW 43</span>
        </div>
      </div>
      <div className="cz-metrics" aria-label="Fiktive Einrichtung im Überblick">
        {(
          [
            ["1", "Stundenplan", "calendar"],
            ["1", "Jahrgang", "book"],
            ["54", "Erfasste Personen", "people"],
            ["3", "Räume", "room"],
          ] as const
        ).map(([value, label, icon]) => (
          <div key={label}>
            <Icon name={icon} />
            <strong>{value}</strong>
            <span>{label}</span>
          </div>
        ))}
      </div>
      <div className="cz-overview-columns">
        <section className="cz-overview-panel">
          <header>
            <h4>Heute auf dem Campus</h4>
            <p>Aktuelle Planung · Entwürfe und freigegebene Termine</p>
          </header>
          <div className="cz-day-summary">
            <span>
              <strong>1</strong> Termin
            </span>
            <span>
              <strong>0</strong> Ausfälle
            </span>
          </div>
          <article className="cz-agenda-item">
            <div>
              <strong>10:15</strong>
              <span>11:45</span>
            </div>
            <div>
              <h4>Mathematik</h4>
              <p>WI26 · Gruppe A · B.101</p>
              <span className="status-label">Freigegeben</span>
            </div>
          </article>
          <footer>
            <button
              className="cz-inline-action"
              type="button"
              disabled={!enhanced}
              onClick={() => onNavigate("schedule")}
            >
              Stundenplanung öffnen
              <Icon name="arrow" />
            </button>
          </footer>
        </section>
        <div className="cz-overview-side">
          <section className="cz-overview-panel">
            <header>
              <h4>Das braucht Aufmerksamkeit</h4>
              <p>Hinweise aus Ihrer aktuellen Planung</p>
            </header>
            <div className="cz-clear-notices">
              <Icon name="check" />
              <div>
                <strong>Keine offenen Hinweise</strong>
                <p>In diesem Beispiel sind keine Hinweise markiert.</p>
              </div>
            </div>
          </section>
          <section className="cz-upcoming">
            <span>
              <Icon name="exam" />
              Ausblick · nächste 7 Tage
            </span>
            <h4>Statistik · Klausur</h4>
            <p>Mo, 26. Okt. · 09:00</p>
            <button
              type="button"
              className="cz-inline-action"
              disabled={!enhanced}
              onClick={() => onNavigate("exams")}
            >
              Prüfungsplanung öffnen
              <Icon name="arrow" />
            </button>
          </section>
        </div>
      </div>
      <section className="cz-shortcuts">
        <h4>Direkt weiterarbeiten</h4>
        <div>
          {(
            [
              [
                "schedule",
                "Stundenplanung",
                "Jahrgänge, Gruppen und Termine",
                "calendar",
              ],
              ["exams", "Prüfungen", "Termine und Anforderungen", "exam"],
              ["rooms", "Räume", "Belegung und Raumverwaltung", "room"],
            ] as const
          ).map(([view, title, text, icon]) => (
            <button
              key={view}
              type="button"
              disabled={!enhanced}
              onClick={() => onNavigate(view)}
            >
              <Icon name={icon} />
              <strong>{title}</strong>
              <span>{text}</span>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}

export function PreviewGroupSelection({
  title,
  enhanced,
  onSelect,
}: {
  title: string;
  enhanced: boolean;
  onSelect: (scope: PreviewScope) => void;
}) {
  return (
    <div className="cz-group-selection">
      <div className="cz-selection-heading">
        <div>
          <span>
            <Icon name="calendar" />
            Planung
          </span>
          <h3>{title}</h3>
          <p>Wählen Sie Ihren Jahrgang und Ihre Gruppe.</p>
        </div>
        <button
          type="button"
          className="cz-selection-all"
          disabled={!enhanced}
          onClick={() => onSelect("all")}
        >
          Gesamtübersicht öffnen
          <Icon name="arrow" />
        </button>
      </div>
      <details className="cz-selection-year" open>
        <summary>
          <strong>2026</strong>
          <span>2 Gruppen</span>
          <i />
          <Icon name="chevron" />
        </summary>
        <div className="cz-selection-programs">
          <article className="cz-selection-program">
            <h4>
              <Icon name="book" />
              B.Sc. Wirtschaftsinformatik
            </h4>
            <div className="cz-selection-cohort">
              <span>WI26</span>
              <button
                type="button"
                aria-label="Jahrgang WI26 öffnen"
                disabled={!enhanced}
                onClick={() => onSelect("all")}
              >
                Ganzer Jahrgang
                <Icon name="arrow" />
              </button>
            </div>
            <div className="cz-selection-groups">
              {(["A", "B"] as const).map((group) => (
                <button
                  key={group}
                  type="button"
                  aria-label={`Gruppe WI26 ${group} öffnen`}
                  disabled={!enhanced}
                  onClick={() => onSelect(group)}
                >
                  <strong>WI26 {group}</strong>
                  <span>
                    <Icon name="people" />
                    {group === "A" ? "28" : "26"}
                    <Icon name="arrow" />
                  </span>
                </button>
              ))}
            </div>
          </article>
        </div>
      </details>
      <p className="cz-selection-note">
        Ein fiktiver Beispieljahrgang. In der Browser-Demo können Sie weitere
        Studiengänge, Jahrgänge und Gruppen kennenlernen.
      </p>
    </div>
  );
}
