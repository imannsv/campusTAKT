import { test, expect } from "@playwright/test";

test("sidebar offers simple cohort and group creation without changing study settings", async ({
  page,
}) => {
  test.setTimeout(60000);
  await page.goto("/");
  await page.getByLabel("Passwort", { exact: true }).fill("WikiBuildOnly2026!");
  await page.getByRole("button", { name: "Anmelden", exact: true }).click();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Gruppen & Jahrgänge", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Gruppen & Jahrgänge", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Jahrgang hinzufügen", exact: true })
    .click();
  const cohortForm = page.getByRole("dialog", {
    name: "Jahrgang hinzufügen",
    exact: true,
  });
  await expect(cohortForm.getByLabel(/^Kennung/)).not.toHaveValue("");
  await expect(
    cohortForm.getByText("CP-Planungsgrenze je Semester (0 = Mittelwert)", {
      exact: true,
    }),
  ).toHaveCount(0);
  const name = `Testjahrgang ${Date.now()}`;
  await cohortForm.getByLabel(/^Name/).fill(name);
  await cohortForm.getByLabel("Aufnahmejahr", { exact: true }).fill("2028");
  const program = cohortForm.getByRole("combobox", {
    name: "Studien- & Bildungsgänge",
    exact: true,
  });
  await expect(
    program.locator('option:not([value=""])').first(),
  ).toBeAttached();
  await program.selectOption(
    (await program
      .locator('option:not([value=""])')
      .first()
      .getAttribute("value")) as string,
  );
  const saved = page.waitForResponse(
    (response) =>
      response.url().endsWith("/api/cohorts/") &&
      response.request().method() === "POST",
  );
  await cohortForm
    .getByRole("button", { name: "Speichern", exact: true })
    .click();
  const response = await saved;
  expect(response.status()).toBe(201);
  const cohort = await response.json();
  const card = page.getByRole("article", { name });
  await expect(card).toBeVisible();
  await card
    .getByRole("button", { name: "Gruppe hinzufügen", exact: true })
    .click();
  const groupForm = page.getByRole("dialog", {
    name: "Gruppe hinzufügen",
    exact: true,
  });
  await expect(
    groupForm.getByRole("combobox", { name: "Jahrgänge", exact: true }),
  ).toHaveValue(String(cohort.id));
  await groupForm.getByLabel(/^Name/).fill("A1 Browsergruppe");
  await groupForm.getByLabel("Gruppengröße", { exact: true }).fill("25");
  await groupForm
    .getByRole("button", { name: "Speichern", exact: true })
    .click();
  await expect(card).toContainText("A1 Browsergruppe");
  await page.screenshot({ path: ".playwright/groups-desktop.png" });
  const csrf = (await page.context().cookies()).find(
    (cookie) => cookie.name === "csrftoken",
  )?.value;
  expect(csrf).toBeTruthy();
  const configured = await page.request.patch(`/api/cohorts/${cohort.id}/`, {
    headers: { "X-CSRFToken": csrf! },
    data: {
      semester_credit_limit: 29,
      semester_weekly_limit: 31,
      semester_difficulty_limit: 7,
    },
  });
  expect(configured.status()).toBe(200);
  const beforeEdit = await configured.json();
  await page.reload();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Gruppen & Jahrgänge", exact: true })
    .click();
  await card
    .getByRole("button", { name: "Jahrgang bearbeiten", exact: true })
    .click();
  const edit = page.getByRole("dialog", {
    name: "Jahrgang bearbeiten",
    exact: true,
  });
  await edit.getByLabel(/^Name/).fill(name + " geändert");
  page.once("dialog", (dialog) => dialog.dismiss());
  await edit.getByRole("button", { name: "Abbrechen", exact: true }).click();
  await expect(edit).toBeVisible();
  await edit.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(edit).not.toBeVisible();
  const persisted = await (
    await page.request.get(`/api/cohorts/${cohort.id}/`)
  ).json();
  expect(persisted.study_schedule).toEqual(cohort.study_schedule);
  expect(persisted.semester_credit_limit).toBe(
    beforeEdit.semester_credit_limit,
  );
  expect(persisted.semester_weekly_limit).toBe(31);
  expect(persisted.semester_difficulty_limit).toBe(7);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ colorScheme: "dark" });
  await expect(
    page.getByRole("article", { name: name + " geändert" }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({ path: ".playwright/groups-mobile-dark.png" });
  await page
    .getByRole("combobox", { name: "Aufnahmejahr filtern", exact: true })
    .selectOption("2028");
  await expect(
    page.getByRole("article", { name: name + " geändert" }),
  ).toBeVisible();
  await page
    .getByRole("article", { name: name + " geändert" })
    .getByRole("button", {
      name: "Personen der Gruppe A1 Browsergruppe öffnen",
      exact: true,
    })
    .click();
  await expect(
    page.getByRole("heading", { name: "Schüler & Studierende", exact: true }),
  ).toBeVisible();
  const context = await page.request.get("/api/campusai/context/?page=groups");
  expect(context.status()).toBe(200);
  expect((await context.json()).view.label).toBe("Gruppen & Jahrgänge");
});
