import { useEffect, useState } from "react";
import { DateTime } from "luxon";
import {
  ArrowUpRight,
  CalendarDays,
  CheckCircle2,
  Clock3,
  GraduationCap,
  Users,
  Building2,
  ClipboardList,
  RefreshCw,
  AlertTriangle,
  Smartphone,
} from "lucide-react";
import { api, Row } from "./api";
import "./dashboard.css";

const shortcuts = [
  {
    page: "schedule",
    label: "Stundenplanung öffnen",
    title: "Stundenplanung",
    detail: "Jahrgänge, Gruppen und Termine",
    icon: CalendarDays,
  },
  {
    page: "exams",
    label: "Prüfungen öffnen",
    title: "Prüfungen",
    detail: "Prüfungstermine und Anforderungen",
    icon: GraduationCap,
  },
  {
    page: "learners",
    label: "Personen verwalten",
    title: "Schüler & Studierende",
    detail: "Personen und Gruppenzuordnungen",
    icon: Users,
  },
  {
    page: "map",
    label: "Räume öffnen",
    title: "Räume",
    detail: "Belegung und Raumverwaltung",
    icon: Building2,
  },
  {
    page: "student-app",
    label: "App-Zugänge öffnen",
    title: "Studierenden-App",
    detail: "Gruppen-QR und Mitteilungen",
    icon: Smartphone,
  },
  {
    page: "setup",
    label: "Einrichtung öffnen",
    title: "Einrichtung",
    detail: "Studienstruktur und Jahrgänge",
    icon: ClipboardList,
  },
];

export default function Dashboard({
  institution,
  boot,
  zone,
  revision,
  query,
  onNavigate,
  onAction,
}: {
  institution: Row;
  boot: Row;
  zone: string;
  revision: number;
  query: string;
  onNavigate: (page: string) => void;
  onAction: (id: string) => void;
}) {
  const [clock, setClock] = useState(() => DateTime.now().setZone(zone));
  const [reload, setReload] = useState(0);
  const [agenda, setAgenda] = useState<Row | null>(null);
  const [context, setContext] = useState<Row | null>(null);
  const [errors, setErrors] = useState<Row>({});
  const [busy, setBusy] = useState(true);
  const today = clock.setZone(zone).toISODate()!;
  useEffect(() => {
    const refresh = () => {
      setClock(DateTime.now().setZone(zone));
      setReload((value) => value + 1);
    };
    setClock(DateTime.now().setZone(zone));
    const timer = window.setInterval(refresh, 30000);
    window.addEventListener("focus", refresh);
    return () => {
      clearInterval(timer);
      window.removeEventListener("focus", refresh);
    };
  }, [zone]);
  useEffect(() => {
    const controller = new AbortController();
    setBusy(true);
    const end = DateTime.fromISO(today, { zone }).plus({ days: 6 }).toISODate();
    Promise.allSettled([
      api(
        `resource-occupancy/?start=${today}&end=${end}&source=planning`,
        "GET",
        undefined,
        { signal: controller.signal },
      ),
      api("campusai/context/?page=dashboard", "GET", undefined, {
        signal: controller.signal,
      }),
    ]).then(([schedule, planning]) => {
      if (controller.signal.aborted) return;
      if (schedule.status === "fulfilled")
        setAgenda({
          ...schedule.value,
          day: today,
          updated: DateTime.now().toISO(),
        });
      if (planning.status === "fulfilled") setContext(planning.value);
      setErrors({
        agenda: schedule.status === "rejected",
        context: planning.status === "rejected",
      });
      setBusy(false);
    });
    return () => controller.abort();
  }, [today, zone, revision, reload]);
  const ready = agenda?.day === today;
  const events: Row[] = ready
    ? agenda.rows.filter((row: Row) => ["teaching", "exam"].includes(row.kind))
    : [];
  const start = DateTime.fromISO(today, { zone }).startOf("day");
  const dayEvents = events.filter(
    (row) =>
      DateTime.fromISO(row.start).toMillis() <
        start.plus({ days: 1 }).toMillis() &&
      DateTime.fromISO(row.end).toMillis() > start.toMillis(),
  );
  const active = dayEvents.filter((row) => !row.cancelled);
  const running = active.filter(
    (row) =>
      DateTime.fromISO(row.start).toMillis() <= clock.toMillis() &&
      DateTime.fromISO(row.end).toMillis() > clock.toMillis(),
  );
  const cancelled = dayEvents.filter((row) => row.cancelled);
  const search = query.trim().toLocaleLowerCase("de");
  const visible = dayEvents.filter((row) =>
    `${row.name} ${row.group_names?.join(" ")} ${row.room_names?.join(" ")} ${row.plan_name}`
      .toLocaleLowerCase("de")
      .includes(search),
  );
  const upcoming = events.find(
    (row) =>
      row.kind === "exam" &&
      !row.cancelled &&
      DateTime.fromISO(row.start).toMillis() >= clock.toMillis(),
  );
  const remaining = visible.filter(
    (row) => DateTime.fromISO(row.end).toMillis() > clock.toMillis(),
  );
  const preview = remaining.length ? remaining.slice(0, 6) : visible.slice(-6);
  const greeting =
    clock.hour < 11
      ? "Guten Morgen"
      : clock.hour < 18
        ? "Guten Tag"
        : "Guten Abend";
  const notices: Row[] = context?.notices || [];
  const counts = boot.counts || {};
  return (
    <section className="dashboard" aria-label="Dashboard">
      <header className="dashboard-welcome">
        <div>
          <span className="dashboard-institution">{institution.name}</span>
          <h1>{greeting}</h1>
          <p>
            Dein Campus im Überblick.{" "}
            {clock.setLocale("de").toFormat("cccc, d. LLLL yyyy")}
          </p>
          <button
            className="button primary"
            onClick={() => onNavigate("schedule")}
          >
            <CalendarDays size={17} />
            Zur Stundenplanung
          </button>
        </div>
        <div className="dashboard-date" aria-label="Heutiges Datum">
          <span>{clock.setLocale("de").toFormat("LLLL yyyy")}</span>
          <strong>{clock.day}</strong>
          <span>
            {clock.setLocale("de").toFormat("cccc")} · KW {clock.weekNumber}
          </span>
        </div>
      </header>
      <div className="dashboard-metrics" aria-label="Einrichtung im Überblick">
        {[
          { label: "Stundenpläne", value: counts.plans, icon: CalendarDays },
          { label: "Jahrgänge", value: counts.cohorts, icon: GraduationCap },
          { label: "Erfasste Personen", value: counts.people, icon: Users },
          { label: "Räume", value: counts.rooms, icon: Building2 },
        ].map(({ label, value, icon: Icon }) => (
          <div key={label} aria-label={label}>
            <Icon size={19} aria-hidden="true" />
            <strong>{value == null ? "—" : value.toLocaleString("de")}</strong>
            <span>{label}</span>
          </div>
        ))}
      </div>
      <div className="dashboard-columns">
        <section className="dashboard-panel dashboard-agenda">
          <header>
            <div>
              <h2>Heute auf dem Campus</h2>
              <p>Aktuelle Planung · Entwürfe und freigegebene Termine</p>
            </div>
            <button
              className="icon-button"
              aria-label="Dashboard aktualisieren"
              disabled={busy}
              onClick={() => setReload((value) => value + 1)}
            >
              <RefreshCw size={18} className={busy ? "spin" : ""} />
            </button>
          </header>
          {errors.agenda && (
            <div className="error-box" role="alert">
              Termine konnten nicht aktualisiert werden.
              {ready
                ? " Der zuletzt geladene Stand bleibt sichtbar."
                : " Bitte versuche es erneut."}
            </div>
          )}
          {ready && (
            <div className="dashboard-day-summary">
              <span>
                <strong>{active.length}</strong>{" "}
                {active.length === 1 ? "Termin" : "Termine"}
              </span>
              <span>
                <strong>{running.length}</strong>{" "}
                {running.length === 1 ? "läuft gerade" : "laufen gerade"}
              </span>
              <span
                className={cancelled.length ? "dashboard-cancellation" : ""}
              >
                <strong>{cancelled.length}</strong>{" "}
                {cancelled.length === 1 ? "Ausfall" : "Ausfälle"}
              </span>
            </div>
          )}
          {!ready && !errors.agenda ? (
            <p className="dashboard-empty" role="status">
              Tagesübersicht wird geladen …
            </p>
          ) : ready && !visible.length ? (
            <div className="dashboard-empty">
              <CalendarDays size={28} />
              <h3>
                {search ? "Keine passenden Termine" : "Heute keine Termine"}
              </h3>
              <p>
                {search
                  ? "Versuche einen anderen Suchbegriff."
                  : "Für heute sind keine Unterrichts- oder Prüfungstermine eingetragen."}
              </p>
              <button
                className="button secondary"
                onClick={() => onNavigate("schedule")}
              >
                Stundenplanung öffnen
              </button>
            </div>
          ) : (
            preview.map((row) => {
              const isRunning = !row.cancelled && running.includes(row);
              return (
                <article
                  className={`dashboard-agenda-item${row.cancelled ? " cancelled" : ""}${isRunning ? " running" : ""}`}
                  key={`${row.plan_id}-${row.id}`}
                >
                  <div className="dashboard-time">
                    <strong>
                      {DateTime.fromISO(row.start)
                        .setZone(zone)
                        .toFormat("HH:mm")}
                    </strong>
                    <span>
                      {DateTime.fromISO(row.end)
                        .setZone(zone)
                        .toFormat("HH:mm")}
                    </span>
                  </div>
                  <div>
                    <div className="dashboard-event-title">
                      <h3>{row.name}</h3>
                      <span
                        className={`badge ${row.cancelled ? "" : isRunning ? "success" : ""}`}
                      >
                        {row.cancelled
                          ? "Entfällt"
                          : isRunning
                            ? "Läuft gerade"
                            : row.status === "published"
                              ? "Freigegeben"
                              : "Entwurf"}
                      </span>
                    </div>
                    <p>
                      {[
                        row.group_names?.join(", "),
                        row.room_names?.join(", ") || "Raum offen",
                      ]
                        .filter(Boolean)
                        .join(" · ")}
                    </p>
                    <small>{row.plan_name}</small>
                  </div>
                </article>
              );
            })
          )}
          {ready && (
            <footer>
              {visible.length > preview.length && (
                <div className="dashboard-agenda-more">
                  <span>
                    {preview.length} von {visible.length} Terminen ·{" "}
                    {remaining.length
                      ? "laufend und als Nächstes"
                      : "zuletzt beendet"}
                  </span>
                  <button
                    className="text-link"
                    onClick={() => onNavigate("schedule")}
                  >
                    Stundenplanung öffnen <ArrowUpRight size={14} />
                  </button>
                </div>
              )}
              Stand{" "}
              {DateTime.fromISO(agenda.updated).setZone(zone).toFormat("HH:mm")}{" "}
              · Aktualisierung alle 30 Sekunden
            </footer>
          )}
        </section>
        <aside className="dashboard-side">
          <section className="dashboard-panel">
            <header>
              <div>
                <h2>Das braucht Aufmerksamkeit</h2>
                <p>Hinweise aus deiner aktuellen Planung</p>
              </div>
              <ClipboardList size={20} />
            </header>
            {errors.context ? (
              <div className="error-box" role="alert">
                Planungshinweise konnten nicht aktualisiert werden.
              </div>
            ) : !context ? (
              <p className="dashboard-empty" role="status">
                Planung wird geprüft …
              </p>
            ) : notices.length ? (
              <>
                <div className="dashboard-notices">
                  {notices.slice(0, 5).map((notice, index) => (
                    <div key={index}>
                      <AlertTriangle
                        size={17}
                        className={
                          notice.severity === "error"
                            ? "dashboard-cancellation"
                            : ""
                        }
                      />
                      <div>
                        <p>{notice.text}</p>
                        <button
                          className="text-link"
                          onClick={() =>
                            notice.action
                              ? onAction(notice.action)
                              : onNavigate(notice.page || "setup")
                          }
                        >
                          Bereich öffnen <ArrowUpRight size={14} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
                {notices.length > 5 && (
                  <p className="dashboard-more">
                    {notices.length - 5} weitere Hinweise in der Planung
                  </p>
                )}
              </>
            ) : (
              <div className="dashboard-empty">
                <CheckCircle2 size={28} />
                <h3>Keine offenen Hinweise</h3>
                <p>Die aktuelle Strukturprüfung meldet keine Hinweise.</p>
              </div>
            )}
          </section>
          <section className="dashboard-exam">
            <div className="dashboard-section-label">
              <GraduationCap size={20} />
              Ausblick · nächste 7 Tage
            </div>
            <h2>
              {errors.agenda && !ready
                ? "Prüfungsausblick nicht verfügbar"
                : upcoming
                  ? upcoming.name
                  : ready
                    ? "Keine anstehende Prüfung"
                    : "Prüfungsausblick"}
            </h2>
            <p>
              {errors.agenda
                ? ready
                  ? "Der Ausblick zeigt den zuletzt geladenen Stand."
                  : "Die Termindaten sind momentan nicht erreichbar."
                : upcoming
                  ? DateTime.fromISO(upcoming.start)
                      .setZone(zone)
                      .setLocale("de")
                      .toFormat("ccc, dd. LLL · HH:mm")
                  : ready
                    ? "In diesem Zeitraum sind keine weiteren Prüfungen geplant."
                    : "Wird mit der Tagesübersicht geladen."}
            </p>
            <button className="text-link" onClick={() => onNavigate("exams")}>
              Prüfungsplanung öffnen <ArrowUpRight size={15} />
            </button>
          </section>
        </aside>
      </div>
      <section className="dashboard-shortcuts">
        <h2>Direkt weiterarbeiten</h2>
        <div>
          {shortcuts
            .filter((item) =>
              `${item.title} ${item.detail}`
                .toLocaleLowerCase("de")
                .includes(search),
            )
            .map((item) => (
              <button
                key={item.page}
                aria-label={item.label}
                onClick={() => onNavigate(item.page)}
              >
                <span className="dashboard-shortcut-icon">
                  <item.icon size={21} />
                </span>
                <span>
                  <strong>{item.title}</strong>
                  <small>{item.detail}</small>
                </span>
                <ArrowUpRight size={17} />
              </button>
            ))}
        </div>
      </section>
      <section className="dashboard-activity">
        <h2>Zuletzt in CampusZeit</h2>
        {boot.audit?.length ? (
          boot.audit.slice(0, 4).map((entry: Row, index: number) => (
            <div key={index}>
              <Clock3 size={16} />
              <p>{entry.action}</p>
              <time dateTime={entry.created}>
                {DateTime.fromISO(entry.created)
                  .setZone(zone)
                  .toFormat("dd.MM. · HH:mm")}
              </time>
            </div>
          ))
        ) : (
          <p>
            Hier erscheinen die nächsten gespeicherten Änderungen deiner
            Einrichtung.
          </p>
        )}
      </section>
    </section>
  );
}
