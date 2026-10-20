import { useEffect, useId, useRef, useState } from "react";
import { Icon, Logo, type IconName } from "./Icon";
import { ThemeToggle, useTheme } from "./Theme";
import {
  PreviewDashboard,
  PreviewGroupSelection,
  type PreviewView,
  type PreviewScope,
} from "./PreviewOverview";

const days = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"];
const events = [
  {
    day: 0,
    row: 1,
    title: "Projektmanagement",
    room: "A.204",
    group: "WI26 · Gruppe A",
    time: "08:30–10:00",
    tone: "mint",
  },
  {
    day: 1,
    row: 2,
    title: "Mathematik",
    room: "B.101",
    group: "WI26 · Gruppe A",
    time: "10:15–11:45",
    tone: "blue",
  },
  {
    day: 2,
    row: 1,
    title: "Datenbanken",
    room: "PC-Labor",
    group: "WI26 · Gruppe A",
    time: "08:30–10:00",
    tone: "lavender",
  },
  {
    day: 2,
    row: 3,
    title: "Wirtschaftsrecht",
    room: "A.202",
    group: "WI26 · Gruppe B",
    time: "12:15–13:45",
    tone: "sand",
  },
  {
    day: 3,
    row: 2,
    title: "Projektmanagement",
    room: "A.204",
    group: "WI26 · Gruppe B",
    time: "10:15–11:45",
    tone: "mint",
  },
  {
    day: 4,
    row: 1,
    title: "Statistik",
    room: "B.101",
    group: "WI26 · Gruppe B",
    time: "08:30–10:00",
    tone: "blue",
  },
];

type PreviewEvent = (typeof events)[number];
function Event({
  event,
  selected,
  onSelect,
  detailsId,
  enhanced,
}: {
  event: PreviewEvent;
  selected: boolean;
  onSelect: () => void;
  detailsId: string;
  enhanced: boolean;
}) {
  return (
    <button
      type="button"
      disabled={!enhanced}
      className={`schedule-event ${event.tone}`}
      aria-label={`${days[event.day]}: ${event.title}, ${event.time}`}
      aria-pressed={selected}
      aria-haspopup="dialog"
      aria-controls={selected ? detailsId : undefined}
      onClick={onSelect}
    >
      <span className="event-time">{event.time}</span>
      <strong>{event.title}</strong>
      <span>
        {event.room} · {event.group}
      </span>
    </button>
  );
}

function TermDialog({
  event,
  id,
  onClose,
}: {
  event: PreviewEvent;
  id: string;
  onClose: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current!;
    const overflow = document.body.style.overflow;
    dialog.showModal();
    document.body.style.overflow = "hidden";
    return () => {
      dialog.close();
      document.body.style.overflow = overflow;
    };
  }, []);
  return (
    <dialog
      ref={ref}
      id={id}
      className="term-dialog term-details"
      aria-label="Termindetails"
      onClose={onClose}
      onClick={(event) => {
        if (event.target === event.currentTarget) ref.current?.close();
      }}
    >
      <div className="term-details-heading">
        <span>Termindetails</span>
        <button
          type="button"
          autoFocus
          aria-label="Termindetails schließen"
          onClick={() => ref.current?.close()}
        >
          <Icon name="close" />
        </button>
      </div>
      <div className="term-details-body">
        <span className={`term-color ${event.tone}`} />
        <h3>{event.title}</h3>
        <p>
          {days[event.day]}, {event.day + 19}. Oktober 2026
        </p>
        <dl>
          <div>
            <dt>Zeit</dt>
            <dd>{event.time}</dd>
          </div>
          <div>
            <dt>Raum</dt>
            <dd>{event.room}</dd>
          </div>
          <div>
            <dt>Jahrgang / Gruppe</dt>
            <dd>{event.group}</dd>
          </div>
        </dl>
        <div className="term-details-state">
          <Icon name="check" />
          <span>Im Beispielplan freigegeben</span>
        </div>
        <p className="term-details-note">
          Fiktiver Beispieltermin. Bearbeiten können Sie Termine in der
          vollständigen Anwendung.
        </p>
      </div>
    </dialog>
  );
}

function PreviewHeading({
  title,
  description,
  count,
}: {
  title: string;
  description: string;
  count?: string;
}) {
  return (
    <div className="planning-preview-heading">
      <div>
        <h3>{title}</h3>
        <span>{description}</span>
      </div>
      {count && <span className="planning-count">{count}</span>}
    </div>
  );
}

export function Schedule({
  compact = false,
  scope = "all",
}: {
  compact?: boolean;
  scope?: PreviewScope;
}) {
  const visibleEvents = events
    .map((event, index) => ({ event, index }))
    .filter(({ event }) => scope === "all" || event.group.endsWith(scope));
  const [selected, setSelected] = useState<number | null>(null);
  const [enhanced, setEnhanced] = useState(false);
  useEffect(() => setEnhanced(true), []);
  const detailsId = useId();
  const renderEvent = (event: PreviewEvent, index: number) => (
    <Event
      event={event}
      selected={selected === index}
      onSelect={() => setSelected(index)}
      detailsId={detailsId}
      enhanced={enhanced}
    />
  );
  return (
    <div className={compact ? "schedule compact" : "schedule"}>
      <PreviewHeading
        title="Stundenplanung"
        description="Termine im Wochenplan auswählen und ansehen."
        count={`${visibleEvents.length} Termine diese Woche`}
      />
      <div className="planning-preview-calendar">
        <div className="schedule-toolbar">
          <div>
            <strong>Wirtschaftsinformatik · WS 2026/27</strong>
            <span>Wochenplanung</span>
          </div>
          <span className="status-label">
            <Icon name="check" />
            Freigegeben
          </span>
        </div>
        <div className="week-bar">
          <strong>19. Okt. – 23. Okt. 2026</strong>
          <span className="week-selection">
            {scope === "all" ? "Alle Gruppen" : `Gruppe ${scope}`} · Alle Räume
          </span>
        </div>
        <div className="week-calendar">
          <div className="calendar-corner">Zeit</div>
          {days.map((day, index) => (
            <div
              className="day-label"
              key={day}
              style={{ gridColumn: index + 2 }}
            >
              <span>{compact ? day.slice(0, 2) : day}</span>
              <strong>{index + 19}</strong>
            </div>
          ))}
          {["08:30", "10:15", "12:15", "14:00"].map((hour, index) => (
            <span
              className="hour-label"
              key={hour}
              style={{ gridRow: index + 2 }}
            >
              {hour}
            </span>
          ))}
          {days.flatMap((day, column) =>
            [1, 2, 3, 4].map((row) => (
              <div
                className="calendar-cell"
                key={`${day}-${row}`}
                style={{ gridColumn: column + 2, gridRow: row + 1 }}
              />
            )),
          )}
          {visibleEvents.map(({ event, index }) => (
            <div
              className="event-position"
              key={index}
              style={{ gridColumn: event.day + 2, gridRow: event.row + 1 }}
            >
              {renderEvent(event, index)}
            </div>
          ))}
        </div>
        <div className="mobile-calendar">
          {visibleEvents.map(({ event, index }) => (
            <div className="mobile-day" key={index}>
              <span>
                {days[event.day]}
                <strong>{event.day + 19}. Oktober</strong>
              </span>
              {renderEvent(event, index)}
            </div>
          ))}
        </div>
        <div className="calendar-preview-footer">
          <span>
            <Icon name="check" />
            Freigegebener Beispielplan
          </span>
          <span>
            {enhanced
              ? "Termine auswählen und Details ansehen"
              : "Statische Vorschau. In der Browser-Demo können Sie die Oberfläche ausprobieren."}
          </span>
        </div>
      </div>
      {selected !== null && (
        <TermDialog
          event={events[selected]}
          id={detailsId}
          onClose={() => setSelected(null)}
        />
      )}
    </div>
  );
}

const roomBooking = { start: 10 * 60 + 15, duration: 90 };
const roomDayStart = 8 * 60;
const roomDayDuration = 6 * 60;
const rooms = [
  {
    name: "Seminarraum A.204",
    capacity: "32 Plätze",
    equipment: "Beamer · Whiteboard",
  },
  { name: "PC-Labor A.206", capacity: "24 Plätze", equipment: "PCs · Beamer" },
  {
    name: "Seminarraum A.202",
    capacity: "28 Plätze",
    equipment: "Beamer · Whiteboard",
  },
];
function ViewButtons<T extends string>({
  label,
  options,
  selected,
  onSelect,
}: {
  label: string;
  options: readonly (readonly [T, string])[];
  selected: T;
  onSelect: (value: T) => void;
}) {
  return (
    <div className="cz-tabs enhanced-only" role="group" aria-label={label}>
      {options.map(([id, name]) => (
        <button
          key={id}
          type="button"
          aria-pressed={selected === id}
          onClick={() => onSelect(id)}
        >
          {name}
        </button>
      ))}
    </div>
  );
}
function Rooms() {
  const [view, setView] = useState<"occupancy" | "catalog">("occupancy");
  return (
    <div className="room-demo">
      <PreviewHeading
        title="Räume"
        description="Belegung und Rauminformationen in einem Arbeitsbereich."
      />
      <ViewButtons
        label="Raumansicht"
        selected={view}
        onSelect={setView}
        options={[
          ["occupancy", "Raumbelegung"],
          ["catalog", "Raumverwaltung"],
        ]}
      />
      {view === "occupancy" ? (
        <div className="cz-panel">
          <div className="schedule-toolbar">
            <strong>22. Okt. 2026</strong>
            <span>Bereich A · 2. Stockwerk</span>
          </div>
          <div className="cz-occupancy-legend">
            <span>3 Räume</span>
            <span>
              <i />
              Freigegeben
            </span>
          </div>
          <div
            className="cz-table-scroll"
            tabIndex={0}
            role="region"
            aria-label="Raumbelegung, horizontal scrollbar"
          >
            <table
              className="cz-occupancy"
              aria-label="Raumbelegung am 22. Oktober"
            >
              <thead>
                <tr>
                  <th>Räume</th>
                  <th colSpan={4}>
                    Do, 22. Okt.
                    <div className="cz-time-axis">
                      <span>08:00</span>
                      <span>10:00</span>
                      <span>12:00</span>
                      <span>14:00</span>
                    </div>
                  </th>
                </tr>
              </thead>
              <tbody>
                {rooms.map((room, index) => (
                  <tr key={room.name}>
                    <th scope="row">
                      {room.name}
                      <small>2. Stockwerk · {room.capacity}</small>
                    </th>
                    <td colSpan={4}>
                      <div className="cz-timeline">
                        {index === 0 ? (
                          <div
                            className="cz-booking mint"
                            style={{
                              marginLeft: `${((roomBooking.start - roomDayStart) / roomDayDuration) * 100}%`,
                              width: `${(roomBooking.duration / roomDayDuration) * 100}%`,
                            }}
                          >
                            <span>10:15–11:45</span>
                            <strong>Projektmanagement</strong>
                            <span>WI26 · Gruppe B</span>
                          </div>
                        ) : (
                          <span className="cz-free">Keine Belegung</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="cz-room-catalog">
          {rooms.map((room) => (
            <article key={room.name}>
              <Icon name="room" />
              <h4>{room.name}</h4>
              <p>{room.capacity}</p>
              <span>{room.equipment}</span>
              <small>Bereich A · 2. Stockwerk</small>
            </article>
          ))}
        </div>
      )}
      <p className="preview-note">
        Fiktive Raumdaten. In der Anwendung lassen sich Belegungen,
        Raumkapazitäten und Ausstattung gemeinsam einsehen.
      </p>
    </div>
  );
}

function Exams() {
  const [view, setView] = useState<"planned" | "deadlines" | "requirements">(
    "planned",
  );
  return (
    <div className="exam-demo">
      <PreviewHeading
        title="Prüfungen"
        description="Wirtschaftsinformatik · WS 2026/27"
      />
      <ViewButtons
        label="Prüfungsbereich wählen"
        selected={view}
        onSelect={setView}
        options={[
          ["planned", "Prüfungen"],
          ["deadlines", "Abgaben & Fristen"],
          ["requirements", "Anforderungen"],
        ]}
      />
      <div className="cz-panel">
        <div className="schedule-toolbar">
          <strong>
            {view === "planned"
              ? "Prüfungen im Semester"
              : view === "deadlines"
                ? "Interne Abgaben & Fristen"
                : "Prüfungsanforderungen"}
          </strong>
          <span>WI26 · 1. Semester</span>
        </div>
        {view === "planned" ? (
          <div className="exam-row">
            <div className="exam-date">
              <strong>26</strong>
              <span>Oktober</span>
            </div>
            <div>
              <h4>Statistik · Klausur</h4>
              <p>09:00–11:00 · 120 Minuten</p>
              <span>B.101 und B.102 · je eine Aufsicht</span>
            </div>
            <span className="exam-tag">Geplant</span>
          </div>
        ) : view === "deadlines" ? (
          <div className="exam-row">
            <div className="exam-date">
              <strong>2</strong>
              <span>November</span>
            </div>
            <div>
              <h4>Projektmanagement · Hausarbeit</h4>
              <p>Interne Abgabefrist · 23:59</p>
              <span>Anforderung aus dem Modul übernommen</span>
            </div>
            <span className="exam-tag muted-tag">Abgabe</span>
          </div>
        ) : (
          <div className="cz-requirement">
            <Icon name="exam" />
            <div>
              <h4>Statistik</h4>
              <p>Klausur · 120 Minuten</p>
              <span>Prüfungsanforderung aus dem Lehrplan</span>
            </div>
            <span className="exam-tag">1. Semester</span>
          </div>
        )}
      </div>
      <p className="preview-note">
        Fiktive Prüfungsdaten. Konkrete Prüfungstermine, interne Fristen und
        Anforderungen aus dem Lehrplan getrennt verwalten.
      </p>
    </div>
  );
}

type View = PreviewView;
const views = {
  dashboard: "Dashboard",
  schedule: "Stundenplanung",
  rooms: "Räume",
  exams: "Prüfungen",
};
export function ApplicationPreview({ compact = false }: { compact?: boolean }) {
  const theme = useTheme();
  const [view, setView] = useState<View>(compact ? "dashboard" : "schedule");
  const [scope, setScope] = useState<PreviewScope | null>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const pendingFocus = useRef(false);
  const selectScope = (next: PreviewScope | null) => {
    pendingFocus.current = true;
    setScope(next);
  };
  useEffect(() => {
    if (!pendingFocus.current) return;
    pendingFocus.current = false;
    const heading = contentRef.current?.querySelector("h3");
    if (heading) {
      heading.tabIndex = -1;
      heading.focus({ preventScroll: true });
    }
  }, [view, scope]);
  const navigate = (next: View) => {
    pendingFocus.current = true;
    setView(next);
    setScope(null);
  };
  const [collapsed, setCollapsed] = useState(false);
  const sidebarId = useId();
  const [enhanced, setEnhanced] = useState(false);
  useEffect(() => setEnhanced(true), []);
  const navButton = (id: View, icon: IconName) => (
    <button
      key={id}
      type="button"
      className="cz-nav-item"
      disabled={!enhanced}
      title={views[id]}
      aria-label={views[id]}
      aria-pressed={view === id}
      onClick={() => navigate(id)}
    >
      <Icon name={icon} />
      <span>{views[id]}</span>
    </button>
  );
  return (
    <div
      className={`product-window application-preview ${collapsed ? "cz-collapsed" : ""}`}
      data-theme={theme.ready ? theme.preview : undefined}
    >
      <aside
        id={sidebarId}
        className="cz-sidebar"
        aria-label={
          compact ? "Beispielnavigation" : "Navigation der Produktvorschau"
        }
      >
        <div className="cz-brand">
          <Logo />
        </div>
        <div className="cz-institution">
          <Icon name="book" />
          <div>
            <strong>Campus Nord</strong>
            <small>Hochschulverwaltung</small>
          </div>
        </div>
        <div
          className="cz-navigation"
          role="group"
          aria-label="Produktansicht auswählen"
        >
          <span className="cz-nav-label">Überblick</span>
          {navButton("dashboard", "dashboard")}
          <span className="cz-nav-label">Planung</span>
          {navButton("schedule", "calendar")}
          {navButton("exams", "exam")}
          <span className="cz-nav-item cz-static">
            <Icon name="people" />
            <span>Lehrendenübersicht</span>
          </span>
          <span className="cz-nav-label">Verwaltung</span>
          {navButton("rooms", "room")}
          <span className="cz-nav-item cz-static">
            <Icon name="layers" />
            <span>Gruppen & Jahrgänge</span>
          </span>
          <span className="cz-nav-item cz-static">
            <Icon name="people" />
            <span>Schüler & Studierende</span>
          </span>
          <span className="cz-nav-item cz-static">
            <Icon name="book" />
            <span>Einrichtung & Studienstruktur</span>
          </span>
          <span className="cz-nav-item cz-static">
            <Icon name="layers" />
            <span>Stammdaten</span>
          </span>
          <span className="cz-nav-label">Veröffentlichung</span>
          <span className="cz-nav-item cz-static">
            <Icon name="screen" />
            <span>Öffentliche Anzeige</span>
          </span>
          <span className="cz-nav-item cz-static">
            <Icon name="people" />
            <span>Studierendenübersicht</span>
          </span>
          <span className="cz-nav-item cz-static">
            <Icon name="phone" />
            <span>Studierenden-App</span>
          </span>
        </div>
        <div className="cz-profile">
          <span className="window-avatar">D</span>
          <div>
            <strong>Demo-Verwaltung</strong>
            <small>Verwaltung</small>
          </div>
        </div>
      </aside>
      <div className="cz-main">
        <div className="cz-topbar">
          <button
            className="cz-collapse enhanced-only"
            type="button"
            aria-label={`Seitenleiste ${collapsed ? "ausklappen" : "einklappen"}`}
            aria-controls={sidebarId}
            aria-expanded={!collapsed}
            onClick={() => setCollapsed(!collapsed)}
          >
            <Icon name="sidebar" />
          </button>
          <div className="cz-mobile-brand">
            <Logo />
          </div>
          <div className="cz-breadcrumb">
            <span>Arbeitsbereich</span>
            <Icon name="chevron" />
            <strong>{views[view]}</strong>
          </div>
          <span className="cz-example">Fiktive Produktansicht</span>
          <ThemeToggle target="preview" />
          <span className="window-avatar" aria-hidden="true">
            D
          </span>
        </div>
        <div
          className="cz-mobile-nav enhanced-only"
          role="group"
          aria-label="Produktansicht auswählen"
        >
          {navButton("dashboard", "dashboard")}
          {navButton("schedule", "calendar")}
          {navButton("exams", "exam")}
          {navButton("rooms", "room")}
        </div>
        <div className="product-content" ref={contentRef}>
          <div className="cz-demo-note">
            <strong>Produktvorschau</strong>
            <span>Fiktive Daten · Auswahl ohne Speicherung</span>
          </div>
          {view === "dashboard" ? (
            <PreviewDashboard enhanced={enhanced} onNavigate={navigate} />
          ) : view === "rooms" ? (
            <Rooms />
          ) : scope === null ? (
            <PreviewGroupSelection
              title={views[view]}
              enhanced={enhanced}
              onSelect={selectScope}
            />
          ) : (
            <>
              <div className="cz-scope-bar">
                <button type="button" onClick={() => selectScope(null)}>
                  <Icon name="chevron" />
                  Gruppe wechseln
                </button>
                <span>
                  WI26
                  {scope !== "all"
                    ? ` · Gruppe ${scope}`
                    : " · Ganzer Jahrgang"}
                </span>
              </div>
              {view === "schedule" ? (
                <Schedule key={scope} compact={compact} scope={scope} />
              ) : (
                <Exams />
              )}
            </>
          )}
          <p className="cz-selection-note cz-static-preview-note">
            Statische Vorschau. In der Browser-Demo können Sie die Oberfläche
            ausprobieren.
          </p>
        </div>
      </div>
    </div>
  );
}
export function ProductPreview() {
  return (
    <figure
      className="product-preview"
      role="region"
      aria-label="Produktvorschau"
    >
      <ApplicationPreview />
      <figcaption>
        Vereinfachte UI-Beispiele mit fiktiven Daten. Die vollständige
        Oberfläche können Sie in der Browser-Demo ausprobieren.
      </figcaption>
    </figure>
  );
}
