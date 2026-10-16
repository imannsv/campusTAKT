/**
 * Prepare a local email draft. This does not send or store any form data.
 * @param {string} recipient
 * @param {{name?: string, institution?: string, email: string, message: string}} fields
 * @returns {string | null}
 */
export function createContactDraft(recipient, fields) {
  if (!recipient.trim() || !fields.email.trim() || !fields.message.trim())
    return null;
  const lines = [
    fields.name?.trim() ? `Name: ${fields.name.trim()}` : null,
    fields.institution?.trim()
      ? `Hochschule / Einrichtung: ${fields.institution.trim()}`
      : null,
    `Antwortadresse: ${fields.email.trim()}`,
    "",
    fields.message.trim().replace(/\r?\n/g, "\r\n"),
  ].filter((line) => line !== null);
  const address = recipient.trim().split("@").map(encodeURIComponent).join("@");
  return `mailto:${address}?subject=${encodeURIComponent("Campuszeit – Kontaktanfrage")}&body=${encodeURIComponent(lines.join("\r\n"))}`;
}
