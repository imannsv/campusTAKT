import { test } from "node:test";
import assert from "node:assert/strict";
const contact = await import("../src/contact.mjs").catch(() => ({}));

test("contact draft cannot target an empty recipient", () => {
  assert.equal(typeof contact.createContactDraft, "function");
  assert.equal(
    contact.createContactDraft("", {
      email: "plan@example.org",
      message: "Pilotanfrage",
    }),
    null,
  );
});

test("contact draft keeps entered details in an encoded mail body", () => {
  assert.equal(typeof contact.createContactDraft, "function");
  const draft = contact.createContactDraft("kontakt@example.org", {
    name: "Dr. Müller",
    institution: "Hochschule Nord & Süd",
    email: "planung+pilot@example.org",
    message:
      "Wir möchten einen Pilotbetrieb besprechen.\n2 Studiengänge & Räume #1?",
  });
  const url = new URL(draft);
  assert.equal(url.protocol, "mailto:");
  assert.equal(url.pathname, "kontakt@example.org");
  assert.equal(url.searchParams.get("subject"), "Campuszeit – Kontaktanfrage");
  assert.equal(
    url.searchParams.get("body"),
    "Name: Dr. Müller\r\nHochschule / Einrichtung: Hochschule Nord & Süd\r\nAntwortadresse: planung+pilot@example.org\r\n\r\nWir möchten einen Pilotbetrieb besprechen.\r\n2 Studiengänge & Räume #1?",
  );
  assert.deepEqual([...url.searchParams.keys()], ["subject", "body"]);
});

test("contact draft requires a reply address and message but allows optional identity fields", () => {
  assert.equal(typeof contact.createContactDraft, "function");
  assert.equal(
    contact.createContactDraft("kontakt@example.org", {
      email: "",
      message: "Anfrage",
    }),
    null,
  );
  assert.equal(
    contact.createContactDraft("kontakt@example.org", {
      email: "plan@example.org",
      message: "  ",
    }),
    null,
  );
  const draft = contact.createContactDraft("kontakt@example.org", {
    email: "plan@example.org",
    message: "Pilot",
  });
  assert.equal(
    new URL(draft).searchParams.get("body"),
    "Antwortadresse: plan@example.org\r\n\r\nPilot",
  );
});
