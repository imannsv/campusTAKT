import { useEffect, useId, useState, type FormEvent } from "react";
import { Icon } from "./Icon";
import { createContactDraft } from "./contact.mjs";

export function ContactForm({ recipient }: { recipient: string }) {
  const id = useId();
  const [enhanced, setEnhanced] = useState(false);
  const [draft, setDraft] = useState<string | null>(null);
  useEffect(() => setEnhanced(true), []);
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const messageField = event.currentTarget.elements.namedItem(
      "message",
    ) as HTMLTextAreaElement;
    if (!messageField.value.trim()) {
      messageField.setCustomValidity("Bitte geben Sie eine Nachricht ein.");
      messageField.reportValidity();
      return;
    }
    const values = new FormData(event.currentTarget);
    const email = createContactDraft(recipient, {
      name: String(values.get("name") || ""),
      institution: String(values.get("institution") || ""),
      email: String(values.get("email") || ""),
      message: String(values.get("message") || ""),
    });
    if (!email) return;
    setDraft(email);
    window.location.assign(email);
  };
  return (
    <form
      className="contact-form"
      aria-labelledby={`${id}-title`}
      aria-describedby={`${id}-delivery`}
      onSubmit={submit}
      onChange={() => setDraft(null)}
    >
      <h3 id={`${id}-title`}>Kontaktanfrage</h3>
      <p className="contact-form-intro">
        Erzählen Sie uns von Ihrer Hochschule und dem Vorhaben, das Sie mit
        Campuszeit besprechen möchten.
      </p>
      <fieldset disabled={!enhanced}>
        <legend className="sr-only">Ihre Kontaktangaben</legend>
        <div className="contact-field">
          <label htmlFor={`${id}-name`}>
            Name <span>(optional)</span>
          </label>
          <input
            id={`${id}-name`}
            name="name"
            autoComplete="name"
            maxLength={120}
          />
        </div>
        <div className="contact-field">
          <label htmlFor={`${id}-institution`}>
            Hochschule / Einrichtung <span>(optional)</span>
          </label>
          <input
            id={`${id}-institution`}
            name="institution"
            autoComplete="organization"
            maxLength={200}
          />
        </div>
        <div className="contact-field">
          <label htmlFor={`${id}-email`}>Ihre E-Mail-Adresse</label>
          <input
            id={`${id}-email`}
            name="email"
            type="email"
            autoComplete="email"
            required
            maxLength={254}
          />
        </div>
        <div className="contact-field">
          <label htmlFor={`${id}-message`}>Nachricht</label>
          <textarea
            id={`${id}-message`}
            name="message"
            required
            maxLength={1500}
            rows={5}
            onInput={(event) => event.currentTarget.setCustomValidity("")}
            aria-describedby={`${id}-message-hint`}
            placeholder="Zum Beispiel: Studiengang, bisheriger Planungsablauf und Fragen zum Pilotbetrieb."
          />
          <p id={`${id}-message-hint`} className="small-print">
            Bitte keine personenbezogenen Stundenpläne oder Daten von
            Studierenden eintragen.
          </p>
        </div>
        <p id={`${id}-delivery`} className="small-print contact-delivery">
          Ihre Angaben bleiben zunächst auf dieser Seite. Der Button öffnet eine
          vorbereitete E-Mail in Ihrem E-Mail-Programm. Erst wenn Sie diese dort
          abschicken, wird die Anfrage übermittelt.
        </p>
        <p className="small-print contact-privacy">
          Wie wir mit Anfragen umgehen, erfahren Sie in den{" "}
          <a href="/datenschutz/">Datenschutzhinweisen</a>.
        </p>
        {!recipient && (
          <p className="pending-contact" role="note">
            Der Versand wird gerade eingerichtet. Sie können Ihre Anfrage
            bereits vorbereiten.
          </p>
        )}
        <button
          className="button primary"
          type="submit"
          disabled={!enhanced || !recipient}
          aria-describedby={!recipient ? `${id}-delivery` : undefined}
        >
          <Icon name="mail" />
          E-Mail vorbereiten
        </button>
      </fieldset>
      <noscript>
        <p className="small-print">
          Zum Ausfüllen des Formulars ist JavaScript erforderlich.
          {recipient && (
            <>
              {" "}
              Sie können uns stattdessen direkt an{" "}
              <a href={`mailto:${recipient}`}>{recipient}</a> schreiben.
            </>
          )}
        </p>
      </noscript>
      {draft && (
        <p className="contact-draft-status" role="status">
          Die Anfrage wurde noch nicht versendet. Bitte prüfen und senden Sie
          die E-Mail in Ihrem E-Mail-Programm.{" "}
          <a href={draft}>E-Mail erneut öffnen</a>
        </p>
      )}
    </form>
  );
}
