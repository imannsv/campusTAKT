import { FormEvent, useCallback, useEffect, useState } from "react";
import { Plus, Smartphone, Download, QrCode } from "lucide-react";
import { api, DEMO_MODE, Row } from "./api";
import { Modal } from "./components";
import "./student-app.css";

export default function StudentAppAdmin({
  data,
}: {
  data: Record<string, Row[]>;
}) {
  const [accesses, setAccesses] = useState<Row[]>([]);
  const [notices, setNotices] = useState<Row[]>([]);
  const [dialog, setDialog] = useState<"access" | "notice" | null>(null);
  const [scope, setScope] = useState("");
  const [server, setServer] = useState(window.location.origin);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [created, setCreated] = useState<Row | null>(null);
  const [existing, setExisting] = useState<Row | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const reload = useCallback(async () => {
    if (DEMO_MODE) return;
    const [accesses, notices] = await Promise.all([
      api("student-app/accesses/"),
      api("student-app/notices/"),
    ]);
    setAccesses(accesses);
    setNotices(notices);
  }, []);
  useEffect(() => {
    reload().catch((e) => setError(e.message));
  }, [reload]);
  const close = useCallback(() => {
    if (busy) return;
    if (
      created ||
      (!scope && !title && !body) ||
      window.confirm("Ungespeicherte Eingaben verwerfen?")
    )
      setDialog(null);
  }, [busy, created, scope, title, body]);
  function open(next: "access" | "notice") {
    setExisting(null);
    setScope("");
    setTitle("");
    setBody("");
    setCreated(null);
    setError("");
    setDialog(next);
  }
  async function showAccess(row: Row) {
    open("access");
    setExisting(row);
    setScope(row.group ? `group:${row.group}` : `cohort:${row.cohort}`);
    setServer(row.server || window.location.origin);
    if (!row.server) return;
    setBusy(true);
    try {
      setCreated(await api(`student-app/accesses/${row.id}/credentials/`));
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  function selection() {
    if (!scope) return {};
    const [kind, id] = scope.split(":");
    return { [kind]: Number(id) };
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      if (dialog === "access") {
        setCreated(
          await api(
            existing
              ? `student-app/accesses/${existing.id}/credentials/`
              : "student-app/accesses/",
            "POST",
            {
              ...(!existing ? selection() : {}),
              server,
            },
          ),
        );
      } else {
        await api("student-app/notices/", "POST", {
          ...selection(),
          title,
          body,
        });
        setDialog(null);
      }
      await reload();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  async function revoke(path: string, question: string) {
    if (!window.confirm(question)) return;
    setBusy(true);
    setError("");
    try {
      await api(path, "POST", {});
      await reload();
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  const options = (
    <>
      <option value="">
        {dialog === "access"
          ? "Gruppe oder Jahrgang auswählen"
          : "Alle Studierenden"}
      </option>
      <optgroup label="Gruppen">
        {(data.groups || []).map((row) => (
          <option key={row.id} value={`group:${row.id}`}>
            {row.name}
          </option>
        ))}
      </optgroup>
      <optgroup label="Jahrgänge">
        {(data.cohorts || []).map((row) => (
          <option key={row.id} value={`cohort:${row.id}`}>
            {row.name}
          </option>
        ))}
      </optgroup>
    </>
  );
  return (
    <section className="student-app-admin">
      <div className="page-actions">
        <h1>Studierenden-App</h1>
        <Smartphone aria-hidden="true" />
      </div>
      <p className="resource-description">
        Gemeinsame Zugänge für Gruppen und Jahrgänge. Die App zeigt freigegebene
        Termine, Prüfungen und Mitteilungen.
      </p>
      {DEMO_MODE && (
        <p className="notice">
          App-Zugänge werden in der Verwaltungsinstanz eingerichtet. In dieser
          Browser-Demo sind sie nicht verfügbar.
        </p>
      )}
      {error && (
        <p role="alert" className="error">
          {error}
        </p>
      )}
      <section className="student-admin-section">
        <div className="page-actions">
          <h2>Gruppenzugänge</h2>
          <button
            className="button primary"
            disabled={DEMO_MODE || busy}
            onClick={() => open("access")}
          >
            <Plus size={18} />
            Zugang erstellen
          </button>
        </div>
        <p>
          Ein Zugang gilt für alle Geräte der Gruppe. Sperren meldet alle
          verbundenen Geräte ab.
        </p>
        {!accesses.length && (
          <p className="empty-state">
            Noch keine Zugänge. Erstelle den ersten Gruppenzugang.
          </p>
        )}
        {accesses.map((row) => (
          <div className="student-admin-row" key={row.id}>
            <div>
              <strong>{row.scope}</strong>
              <p>
                Zugangscode: <code>{row.code}</code> ·{" "}
                {row.active ? "Aktiv" : "Gesperrt"}
              </p>
            </div>
            <div className="student-admin-row-actions">
              <button
                className="button secondary"
                disabled={!row.active || busy}
                onClick={() => showAccess(row)}
              >
                <QrCode size={16} /> Zugang anzeigen
              </button>
              <button
                className="button secondary"
                disabled={!row.active || busy}
                onClick={() =>
                  revoke(
                    `student-app/accesses/${row.id}/disable/`,
                    "Zugang sperren und alle verbundenen Geräte abmelden?",
                  )
                }
              >
                Sperren
              </button>
            </div>
          </div>
        ))}
      </section>
      <section className="student-admin-section">
        <div className="page-actions">
          <h2>Mitteilungen</h2>
          <button
            className="button secondary"
            disabled={DEMO_MODE || busy}
            onClick={() => open("notice")}
          >
            <Plus size={18} />
            Mitteilung erstellen
          </button>
        </div>
        {!notices.length && (
          <p className="empty-state">Noch keine Mitteilungen veröffentlicht.</p>
        )}
        {notices.map((row) => (
          <article className="student-admin-row" key={row.id}>
            <div>
              <strong>{row.title}</strong>
              <p>
                {row.scope} · {row.active ? "Veröffentlicht" : "Zurückgezogen"}
              </p>
              <p className="student-notice-body">{row.body}</p>
            </div>
            <button
              className="button secondary"
              disabled={!row.active || busy}
              onClick={() =>
                revoke(
                  `student-app/notices/${row.id}/withdraw/`,
                  "Mitteilung aus der App zurückziehen?",
                )
              }
            >
              Zurückziehen
            </button>
          </article>
        ))}
      </section>
      {dialog && (
        <Modal
          title={
            created
              ? "Zugang bereitstellen"
              : existing
                ? "Zugang anzeigen"
                : dialog === "access"
                  ? "Gruppenzugang erstellen"
                  : "Mitteilung veröffentlichen"
          }
          onClose={close}
          busy={busy}
        >
          {created ? (
            <div className="student-app-form">
              <p>
                Diesen QR-Code kannst du später über „Zugang anzeigen“ erneut
                öffnen und speichern. Gib ihn ausschließlich an die zugehörige
                Gruppe weiter.
              </p>
              <img
                className="student-access-qr"
                alt={`Anmelde-QR-Code für ${created.scope}`}
                src={`data:image/svg+xml;charset=utf-8,${encodeURIComponent(created.qr_svg)}`}
              />
              <dl>
                <dt>Gruppe / Jahrgang</dt>
                <dd>{created.scope}</dd>
                <dt>Serveradresse</dt>
                <dd>{created.server}</dd>
                <dt>Zugangscode</dt>
                <dd>
                  <code>{created.code}</code>
                </dd>
                <dt>Passwort</dt>
                <dd>
                  {created.password ? (
                    <code>{created.password}</code>
                  ) : (
                    "Wird nur bei der Erstellung angezeigt. Nutze zur Anmeldung den QR-Code."
                  )}
                </dd>
              </dl>
              <div className="student-app-actions">
                <a
                  className="button secondary"
                  download={`campuszeit-${created.code}.svg`}
                  href={`data:image/svg+xml;charset=utf-8,${encodeURIComponent(created.qr_svg)}`}
                >
                  <Download size={18} />
                  QR-Code speichern
                </a>
                <button
                  className="button secondary"
                  onClick={() =>
                    navigator.clipboard
                      .writeText(
                        `CampusZeit · ${created.scope}\nServer: ${created.server}\nZugangscode: ${created.code}${created.password ? `\nPasswort: ${created.password}` : ""}`,
                      )
                      .catch(() =>
                        setError(
                          "Kopieren fehlgeschlagen. Bitte die Angaben auswählen und kopieren.",
                        ),
                      )
                  }
                >
                  {created.password
                    ? "Zugangsdaten kopieren"
                    : "Zugangscode kopieren"}
                </button>
                <button className="button primary" onClick={close}>
                  Fertig
                </button>
              </div>
            </div>
          ) : (
            <form className="student-app-form" onSubmit={submit}>
              <label>
                Zielgruppe
                <select
                  disabled={!!existing || busy}
                  required={dialog === "access"}
                  value={scope}
                  onChange={(e) => setScope(e.target.value)}
                >
                  {options}
                </select>
              </label>
              {dialog === "access" ? (
                <>
                  {existing && (
                    <p>
                      Ergänze einmalig die erreichbare Serveradresse für diesen
                      bestehenden Zugang. Passwort und angemeldete Geräte
                      bleiben erhalten.
                    </p>
                  )}
                  <label>
                    Serveradresse
                    <input
                      type="url"
                      required
                      value={server}
                      onChange={(e) => setServer(e.target.value)}
                    />
                  </label>
                  <p>
                    Verwende die von den iPhones erreichbare CampusZeit-Adresse.
                    „localhost“ und „127.0.0.1“ zeigen auf das jeweilige Gerät.
                    Im produktiven Betrieb ist HTTPS erforderlich.
                  </p>
                </>
              ) : (
                <>
                  <label>
                    Titel
                    <input
                      required
                      maxLength={160}
                      value={title}
                      onChange={(e) => setTitle(e.target.value)}
                    />
                  </label>
                  <label>
                    Mitteilung
                    <textarea
                      required
                      rows={5}
                      maxLength={5000}
                      value={body}
                      onChange={(e) => setBody(e.target.value)}
                    />
                  </label>
                </>
              )}
              <div className="student-app-actions">
                <button
                  type="button"
                  className="button secondary"
                  onClick={close}
                  disabled={busy}
                >
                  Abbrechen
                </button>
                <button className="button primary" disabled={busy}>
                  {busy
                    ? "Wird gespeichert …"
                    : dialog === "access"
                      ? existing
                        ? "QR-Code anzeigen"
                        : "Zugang erstellen"
                      : "Veröffentlichen"}
                </button>
              </div>
            </form>
          )}
          {error && (
            <p role="alert" className="error">
              {error}
            </p>
          )}
        </Modal>
      )}
    </section>
  );
}
