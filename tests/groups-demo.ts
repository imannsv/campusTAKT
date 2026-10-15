import { test, expect } from "@playwright/test";

test("Gruppenverwaltung: Demo legt Jahrgang und Gruppe mit kurzen Formularen an", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Gruppen & Jahrgänge", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Jahrgang hinzufügen", exact: true })
    .click();
  const form = page.getByRole("dialog", {
    name: "Jahrgang hinzufügen",
    exact: true,
  });
  await form.getByLabel(/^Name/).fill("Demo-Jahrgang 2029");
  await form.getByLabel("Aufnahmejahr", { exact: true }).fill("2029");
  const programs = form.getByRole("combobox", {
    name: "Studien- & Bildungsgänge",
    exact: true,
  });
  await expect(
    programs.locator('option:not([value=""])').first(),
  ).toBeAttached();
  await programs.selectOption(
    (await programs
      .locator('option:not([value=""])')
      .first()
      .getAttribute("value")) as string,
  );
  await form.getByRole("button", { name: "Speichern", exact: true }).click();
  const card = page.getByRole("article", {
    name: "Demo-Jahrgang 2029",
    exact: true,
  });
  await expect(card).toBeVisible();
  await card
    .getByRole("button", { name: "Gruppe hinzufügen", exact: true })
    .click();
  const group = page.getByRole("dialog", {
    name: "Gruppe hinzufügen",
    exact: true,
  });
  await group.getByLabel(/^Name/).fill("Demo-Gruppe A1");
  await group.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(card).toContainText("Demo-Gruppe A1");
  await page.reload();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Gruppen & Jahrgänge", exact: true })
    .click();
  await expect(card).toContainText("Demo-Gruppe A1");
});
