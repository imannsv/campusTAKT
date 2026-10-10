import { test, expect } from "@playwright/test";

test("Prüfungsseite trennt Prüfungen, Anforderungen und Abgaben und behält die Semesterwahl", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation")
    .getByRole("button", { name: "Prüfungen", exact: true })
    .click();
  const views = page.getByRole("group", { name: "Prüfungsbereich wählen" });
  const plan = page.getByLabel("Semesterplan für Prüfungen", { exact: true });
  await expect(
    views.getByRole("button", { name: "Prüfungen", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".assessment-board")).toHaveCount(0);
  await plan.selectOption({ label: "dWI24 · Unterricht & Prüfungen" });
  await expect(
    page.getByRole("cell", {
      name: "Klausur · Softwarearchitektur",
      exact: true,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("columnheader", { name: "Zeitraum", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("button", {
      name: "Klausur · Softwarearchitektur bearbeiten",
      exact: true,
    })
    .click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel(/^Name/).fill("Softwarearchitektur · geändert");
  await dialog.getByRole("button", { name: "Abbrechen", exact: true }).click();
  await expect(
    page.getByRole("cell", {
      name: "Klausur · Softwarearchitektur",
      exact: true,
    }),
  ).toBeVisible();
  await page
    .getByRole("button", {
      name: "Klausur · Softwarearchitektur bearbeiten",
      exact: true,
    })
    .click();
  await dialog.getByLabel(/^Name/).fill("Softwarearchitektur · geändert");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await expect(
    page.getByRole("cell", {
      name: "Softwarearchitektur · geändert",
      exact: true,
    }),
  ).toBeVisible();
  for (const view of ["Anforderungen", "Abgaben & Fristen"]) {
    await views.getByRole("button", { name: view, exact: true }).click();
    await expect(page.locator(".assessment-board")).toBeVisible();
    await expect(page.locator(".data-panel")).toHaveCount(0);
    await expect(plan).toHaveValue("2");
  }
  await views.getByRole("button", { name: "Prüfungen", exact: true }).click();
  await page
    .getByRole("button", { name: "Prüfung hinzufügen", exact: true })
    .click();
  await expect(
    dialog.getByRole("combobox", { name: "Stundenpläne", exact: true }),
  ).toHaveValue("2");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(dialog).toBeVisible();
  await dialog.getByRole("button", { name: "Abbrechen", exact: true }).click();
  await page.reload();
  await page
    .getByRole("navigation")
    .getByRole("button", { name: "Prüfungen", exact: true })
    .click();
  await plan.selectOption("2");
  await expect(
    page.getByRole("cell", {
      name: "Softwarearchitektur · geändert",
      exact: true,
    }),
  ).toBeVisible();
});

test("Prüfungsansichten bleiben auf kleinen Bildschirmen bedienbar und funktionieren im Darkmode", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation")
    .getByRole("button", { name: "Prüfungen", exact: true })
    .click();
  await page
    .getByLabel("Semesterplan für Prüfungen", { exact: true })
    .selectOption("2");
  const views = page.getByRole("group", { name: "Prüfungsbereich wählen" });
  for (const width of [390, 768, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    for (const view of ["Prüfungen", "Abgaben & Fristen", "Anforderungen"]) {
      const button = views.getByRole("button", { name: view, exact: true });
      await button.click();
      await expect(button).toHaveAttribute("aria-pressed", "true");
      expect(
        await page.evaluate(() => document.documentElement.scrollWidth),
      ).toBeLessThanOrEqual(width);
    }
  }
  await page.getByRole("button", { name: /^Darstellung:/ }).click();
  await page
    .getByRole("menuitemradio", { name: "Dunkel", exact: true })
    .click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await views.getByRole("button", { name: "Prüfungen", exact: true }).click();
  await expect(
    page.getByRole("cell", {
      name: "Klausur · Softwarearchitektur",
      exact: true,
    }),
  ).toBeVisible();
});
