import { useEffect, useRef, useState } from "react";
import { DateTime } from "luxon";
import { FileText, GraduationCap, Info } from "lucide-react";
import { all, api, fmt, type Row } from "./api";
import { assessmentSummary, timedAssessment } from "./assessment";

export default function AssessmentBoard({
  plan,
  view,
  query,
  hasStructure,
  zone,
  refresh,
  onChanged,
  onEdit,
}: {
  plan?: Row;
  view: "requirements" | "deadlines";
  query: string;
  hasStructure: boolean;
  zone: string;
  refresh: number;
  onChanged: () => void;
  onEdit: (resource: string, record?: Row, defaults?: Row) => void;
}) {
  const [rows, setRows] = useState<Row[]>([]),
    [exams, setExams] = useState<Row[]>([]);
  const [error, setError] = useState(""),
    [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false),
    [loading, setLoading] = useState(true);
  const tab = view === "requirements" ? "timed" : "deadlines";
  const activePlan = useRef(plan?.id);
  activePlan.current = plan?.id;
  useEffect(() => {
    setMessage("");
  }, [plan?.id]);
  useEffect(() => {
    let active = true;
    setRows([]);
    setExams([]);
    setError("");
    setLoading(true);
    if (!plan) {
      setLoading(false);
      return;
    }
    Promise.all([
      all("assessments", `plan=${plan.id}`),
      all("exams", `plan=${plan.id}`),
    ])
      .then(([requirements, actual]) => {
        if (active) {
          setRows(requirements);
          setExams(actual);
        }
      })
      .catch((err) => {
        if (active) setError(err.message);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [plan?.id, refresh]);
  async function prepare() {
    const planId = plan!.id;
    setBusy(true);
    setError("");
    try {
      const result = await api(
        `plans/${planId}/prepare-assessments/`,
        "POST",
        {},
      );
      onChanged();
      const [requirements, actual] = await Promise.all([
        all("assessments", `plan=${planId}`),
        all("exams", `plan=${planId}`),
      ]);
      if (activePlan.current !== planId) return;
      setRows(requirements);
      setExams(actual);
      setMessage(
        `${result.created} Vorlagen übernommen; ${result.existing} vorhandene erhalten.${result.warnings.length ? " " + result.warnings.join(" ") : ""}`,
      );
    } catch (err) {
      if (activePlan.current === planId) setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }
  async function draft(row: Row) {
    setBusy(true);
    setError("");
    try {
      const result = await api(`assessments/${row.id}/exam_draft/`);
      if (activePlan.current !== row.plan) return;
      onEdit("exams", undefined, {
        ...result.defaults,
        _draft_warnings: result.warnings,
      });
    } catch (err) {
      if (activePlan.current === row.plan) setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }
  const timed = rows.filter((row) => timedAssessment(row.assessment_type));
  const deadlines = rows.filter((row) => !timedAssessment(row.assessment_type));
  const visible = (tab === "timed" ? timed : deadlines)
    .filter((row) =>
      `${row.name} ${row.assessment_notes || ""}`
        .toLocaleLowerCase("de")
        .includes(query.trim().toLocaleLowerCase("de")),
    )
    .sort(
      (a, b) =>
        (a.due_at || "9999").localeCompare(b.due_at || "9999") ||
        a.name.localeCompare(b.name, "de"),
    );
  return (
    <section
      className="assessment-board"
      aria-label="Prüfungsanforderungen des Semesterplans"
    >
      <div className="assessment-heading">
        <div>
          <h2>
            {tab === "timed" ? "Prüfungsanforderungen" : "Abgaben & Fristen"}
          </h2>
          <p className="assessment-intro">
            {tab === "timed"
              ? "Vorgaben aus dem Lehrplan. Daraus lassen sich Prüfungen anlegen."
              : "Hausarbeiten, Projekte und weitere Leistungen mit Abgabefrist."}
          </p>
        </div>
        <button
          className="button secondary"
          disabled={!plan || !hasStructure || busy || loading}
          onClick={prepare}
          aria-label="Prüfungsanforderungen übernehmen"
        >
          Lehrplan übernehmen
        </button>
      </div>
      {(!plan || !hasStructure) && (
        <p className="assessment-structure-note">
          <Info size={16} aria-hidden="true" />
          <span>
            {plan
              ? "Kein freigegebener Lehrplan zugeordnet. Prüfungen lassen sich im Bereich „Prüfungen“ manuell hinzufügen."
              : "Lege zuerst einen Semesterplan in der Studienstruktur an."}
          </span>
        </p>
      )}
      {error && (
        <div className="error-box" role="alert">
          {error}
        </div>
      )}
      {message && (
        <p className="info-note" role="status">
          {message}
        </p>
      )}
      {loading ? (
        <p role="status">Prüfungsanforderungen laden …</p>
      ) : !visible.length ? (
        <div className="assessment-empty" role="status">
          {tab === "timed" ? (
            <GraduationCap size={20} aria-hidden="true" />
          ) : (
            <FileText size={20} aria-hidden="true" />
          )}
          <p>
            {query.trim()
              ? "Keine passenden Leistungen gefunden."
              : tab === "timed"
                ? hasStructure
                  ? "Keine Anforderungen vorhanden. Übernimm sie aus dem Lehrplan."
                  : "Noch keine Prüfungsanforderungen zugeordnet."
                : hasStructure
                  ? "Keine Abgaben vorhanden. Übernimm die Vorgaben aus dem Lehrplan."
                  : "Noch keine Abgaben oder Fristen zugeordnet."}
          </p>
        </div>
      ) : (
        <div className="assessment-cards">
          {visible.map((row) => {
            const exam = exams.find(
              (item) => item.assessment_template === row.id,
            );
            const waived = row.status === "waived";
            const due = row.due_at
              ? DateTime.fromISO(row.due_at, { zone })
              : null;
            const overdue =
              !!due && due < DateTime.now().setZone(zone) && !waived;
            return (
              <article key={row.id} aria-label={row.name}>
                <div className="assessment-card-body">
                  <div className="assessment-card-heading">
                    <h3>{row.name}</h3>
                    <span
                      className={
                        "badge " +
                        (overdue
                          ? "assessment-overdue"
                          : exam || due
                            ? "success"
                            : "")
                      }
                    >
                      {waived
                        ? "Entfällt"
                        : exam
                          ? "Prüfung angelegt"
                          : overdue
                            ? "Frist verstrichen"
                            : due
                              ? "Frist gesetzt"
                              : tab === "timed"
                                ? "Vorlage offen"
                                : "Frist offen"}
                    </span>
                  </div>
                  <p>{assessmentSummary(row)}</p>
                  {row.assessment_notes && (
                    <details className="assessment-notes">
                      <summary>Hinweise</summary>
                      <p className="study-assessment-notes">
                        {row.assessment_notes}
                      </p>
                    </details>
                  )}
                  {exam && (
                    <p>
                      Prüfungszeitraum:{" "}
                      {DateTime.fromISO(exam.window_start).toFormat(
                        "dd.MM.yyyy",
                      )}{" "}
                      –{" "}
                      {DateTime.fromISO(exam.window_end).toFormat("dd.MM.yyyy")}{" "}
                      · {exam.duration_minutes} Minuten · {exam.learners.length}{" "}
                      Teilnehmer
                    </p>
                  )}
                  {due && (
                    <p className="assessment-due">
                      Abgabe:{" "}
                      <strong>
                        {fmt(row.due_at, zone, "dd.MM.yyyy · HH:mm")}
                      </strong>
                    </p>
                  )}
                </div>
                <div className="study-inline-actions">
                  <button
                    className="button secondary"
                    onClick={() => onEdit("assessments", row)}
                  >
                    {tab === "timed"
                      ? "Vorlage bearbeiten"
                      : "Abgabefrist bearbeiten"}
                  </button>
                  {timedAssessment(row.assessment_type) &&
                    (exam ? (
                      <button
                        className="button secondary"
                        onClick={() => onEdit("exams", exam)}
                      >
                        Prüfung bearbeiten
                      </button>
                    ) : (
                      <button
                        className="button primary"
                        disabled={busy || waived}
                        onClick={() => draft(row)}
                      >
                        Prüfung anlegen
                      </button>
                    ))}
                </div>
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}
