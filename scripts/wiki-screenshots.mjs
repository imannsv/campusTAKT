// Capture only the disposable Wiki fixture, never a customer's live database.
import { chromium, expect } from "@playwright/test";
import { captureWikiView } from "./wiki-capture.mjs";
import fs from "node:fs/promises";
import path from "node:path";
const baseURL = "http://127.0.0.1:5186";
const directory = path.resolve(import.meta.dirname, "../shared/wiki/images");
await fs.mkdir(directory, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 1440, height: 1000 },
  deviceScaleFactor: 1,
});
page.setDefaultTimeout(15000);
try {
  await page.goto(baseURL);
  await page.getByLabel("Passwort", { exact: true }).fill("WikiBuildOnly2026!");
  await page.getByRole("button", { name: "Anmelden", exact: true }).click();
  await page.getByRole("navigation", { name: "Arbeitsbereiche" }).waitFor();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Stundenplanung", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Gesamtübersicht öffnen", exact: true })
    .click();
  await page.getByRole("button", { name: "Termin", exact: true }).waitFor();
  const capture = async (ready, ...names) => {
    await captureWikiView(page, directory, ready, ...names);
    console.log(names.join(", "));
  };
  const nav = async (name) => {
    const appData =
      name === "Studierenden-App"
        ? ["accesses", "notices"].map((resource) =>
            page.waitForResponse(
              (response) =>
                response.request().method() === "GET" &&
                new URL(response.url()).pathname ===
                  `/api/student-app/${resource}/`,
            ),
          )
        : [];
    await page
      .getByRole("navigation", { name: "Arbeitsbereiche" })
      .getByRole("button", { name, exact: true })
      .click();
    if (appData.length) {
      const responses = await Promise.all(appData);
      for (const response of responses) expect(response.ok()).toBe(true);
      const [accesses, notices] = await Promise.all(
        responses.map((response) => response.json()),
      );
      await expect(
        page.locator(".student-app-admin .student-admin-row"),
      ).toHaveCount(accesses.length + notices.length);
    }
  };
  const step = async (index, name) => {
    await nav("Einrichtung & Studienstruktur");
    await page
      .getByRole("button", { name: `Schritt ${index}: ${name}`, exact: true })
      .click();
  };
  const cancel = async () => {
    await page
      .getByRole("dialog")
      .getByRole("button", { name: "Abbrechen", exact: true })
      .click();
  };
  await nav("Dashboard");
  await capture(
    page.locator(
      '.dashboard:not(:has([role="status"], [role="alert"])) .dashboard-day-summary',
    ),
    "dashboard",
  );
  await nav("Gruppen & Jahrgänge");
  await capture(page.locator(".group-cohort").first(), "group-admin");
  await nav("Schüler & Studierende");
  await page.locator(".learner-row").first().waitFor();
  await capture(page.locator(".learner-row").first(), "learners-list");
  await page.getByRole("button", { name: "Kacheln", exact: true }).click();
  await capture(page.locator(".selection-group").first(), "learners-tiles");
  await nav("Studierenden-App");
  await capture(page.locator(".student-app-admin"), "student-app");
  await nav("Stundenplanung");
  await page
    .getByRole("button", { name: "Gesamtübersicht öffnen", exact: true })
    .click();
  await page.getByRole("button", { name: "Termin", exact: true }).waitFor();
  await capture(
    page.locator(".calendar-scroll .calendar-event").first(),
    "schedule",
    "start-10",
    "periods",
    "ui",
  );
  await page.getByRole("button", { name: "Termin", exact: true }).click();
  await page.getByRole("dialog").waitFor();
  await capture(page.getByRole("dialog").locator(".record-form"), "manual");
  await cancel();
  await page
    .getByRole("button", { name: "Veröffentlichen", exact: true })
    .click();
  await page.getByRole("dialog").waitFor();
  await capture(page.getByRole("dialog"), "publication");
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Schließen", exact: true })
    .first()
    .click();
  await nav("Räume");
  await page
    .getByRole("button", { name: "Raumverwaltung", exact: true })
    .click();
  await capture(
    page.locator(".room-tile").first(),
    "rooms",
    "start-02",
    "definitions",
  );
  await step(2, "Lehrende");
  await page
    .getByRole("button", { name: "Lehrende hinzufügen", exact: true })
    .click();
  await page.getByRole("dialog").waitFor();
  await capture(
    page.getByRole("dialog").locator(".record-form"),
    "teachers",
    "start-03",
  );
  await cancel();
  await step(3, "Studiengänge");
  await capture(page.locator(".study-card").first(), "start-04");
  await step(4, "Studienstruktur");
  await page
    .getByRole("button", { name: "Neue Version aus Kopie", exact: true })
    .click();
  const copy = page.getByRole("dialog", { name: "Neue Lehrplanversion" });
  await copy.getByLabel("Kennung", { exact: true }).fill(`WIKI-${Date.now()}`);
  await copy.getByLabel("Versionsbezeichnung", { exact: true }).fill("2028");
  await copy
    .getByLabel("Name", { exact: true })
    .fill("Wirtschaftsinformatik · Entwurf 2028");
  await copy
    .getByRole("button", { name: "Kopie anlegen", exact: true })
    .click();
  await copy.waitFor({ state: "hidden" });
  await expect(
    page
      .getByLabel("Lehrplanversion", { exact: true })
      .locator("option:checked"),
  ).toContainText("Entwurf 2028");
  await capture(page.locator(".study-report"), "study", "start-05");
  const approve = page.getByRole("button", {
    name: "Lehrplan freigeben",
    exact: true,
  });
  await approve.scrollIntoViewIfNeeded();
  await page
    .locator(".study-report")
    .getByRole("heading", { name: "Vollständigkeitsprüfung" })
    .waitFor();
  await fs.writeFile(
    path.join(directory, "start-06.png"),
    await page.screenshot({ animations: "disabled" }),
  );
  await page.getByLabel("Lehrplanversion", { exact: true }).selectOption({
    label: "Wirtschaftsinformatik · Beispiel 2027 · Freigegeben",
  });
  await page.getByText("Semesterübersicht", { exact: true }).click();
  await capture(
    page.locator(".study-semester-overview[open] .study-card").first(),
    "schools",
  );
  await step(5, "Jahrgänge");
  await capture(
    page.locator(".study-panel .study-card").first(),
    "cohort",
    "start-07",
  );
  const progression = page.getByText("Studienverlauf und Semesterbelastung", {
    exact: true,
  });
  if (await progression.count()) await progression.click();
  await capture(
    page.locator(".cohort-progression .progression-semester").first(),
    "progression",
    "start-08",
  );
  await step(6, "Semester planen");
  await capture(
    page.getByRole("button", { name: "Semesterplan hinzufügen", exact: true }),
    "start-09",
  );
  await nav("Prüfungen");
  await page
    .getByRole("button", { name: "Gesamtübersicht öffnen", exact: true })
    .click();
  await capture(
    page
      .locator(".exam-table-panel:not(:has(.table-loading))")
      .locator("tbody tr, .empty-state")
      .first(),
    "assessments",
    "start-11",
  );
  await nav("Öffentliche Anzeige");
  await capture(
    page.locator(".display-cards article").first(),
    "display",
    "start-12",
  );
  await nav("Studierendenübersicht");
  await capture(page.locator(".display-cards article").first(), "students");
  await nav("Stammdaten");
  await page
    .locator(".resource-tabs")
    .getByRole("button", { name: "Raumblockierungen", exact: true })
    .click();
  await capture(
    page.locator(".data-panel:not(:has(.table-loading)) tbody tr").first(),
    "blocks",
  );
  await page
    .locator(".resource-tabs")
    .getByRole("button", { name: "Veranstaltungen", exact: true })
    .click();
  await capture(
    page.locator(".data-panel:not(:has(.table-loading)) tbody tr").first(),
    "electives",
  );
  await page.getByRole("button", { name: "Importieren", exact: true }).click();
  await page.getByRole("dialog").waitFor();
  await capture(page.getByRole("dialog"), "imports");
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Schließen", exact: true })
    .first()
    .click();
  await page
    .getByRole("button", { name: "Einstellungen", exact: true })
    .click();
  await capture(
    page.getByRole("heading", {
      name: "Einrichtungseinstellungen",
      exact: true,
    }),
    "settings",
    "accounts",
    "start-01",
  );
  await page
    .getByRole("button", { name: "Freddy öffnen", exact: true })
    .click();
  await capture(
    page.locator(".campus-ai-welcome"),
    "freddy",
    "troubleshooting",
  );
  await page.goto(baseURL + "/wiki/setup");
  await page.locator(".wiki-article").waitFor();
} finally {
  await browser.close();
}
