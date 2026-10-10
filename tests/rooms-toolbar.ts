import { expect, test } from "@playwright/test";

test("Raumfilter gelten sofort, zählen Abweichungen und schließen zugänglich", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation")
    .getByRole("button", { name: "Räume", exact: true })
    .click();
  const filters = page.getByRole("button", { name: /Weitere Filter/ });
  const popup = page.getByRole("dialog", {
    name: "Weitere Filter",
    exact: true,
  });
  await filters.focus();
  await page.keyboard.press("Enter");
  await expect(popup.getByLabel("Planungsstand")).toBeFocused();
  await popup.getByLabel("Planungsstand").selectOption("published");
  await expect(filters).toContainText("1");
  await popup.getByLabel("Nur mit Belegung").check();
  await expect(filters).toContainText("2");
  await page.keyboard.press("Escape");
  await expect(popup).toHaveCount(0);
  await expect(filters).toBeFocused();
  await filters.click();
  await expect(popup.getByLabel("Planungsstand")).toHaveValue("published");
  await expect(popup.getByLabel("Nur mit Belegung")).toBeChecked();
  await popup.getByLabel("Planungsstand").selectOption("planning");
  await popup.getByLabel("Nur mit Belegung").uncheck();
  await expect(filters).toHaveText("Weitere Filter");
  await page.getByRole("heading", { name: "Räume", exact: true }).click();
  await expect(popup).toHaveCount(0);
  await page.getByRole("button", { name: "Belegung aktualisieren" }).click();
  await expect(page.locator(".resource-timeline-row").first()).toBeVisible();
});

test("Strukturmenü erstellt Bereiche und Stockwerke; Auswahl, Bearbeitung und Abbrechen bleiben erhalten", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation")
    .getByRole("button", { name: "Räume", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Raumverwaltung", exact: true })
    .click();
  const trigger = page.getByRole("button", {
    name: "Struktur verwalten",
    exact: true,
  });
  const menu = page.getByRole("menu", { name: "Struktur verwalten" });
  const dialog = page.getByRole("dialog");
  const area = page.getByLabel("Bereich", { exact: true });
  const floor = page.getByLabel("Stockwerk", { exact: true });
  await trigger.click();
  await expect(
    menu.getByRole("menuitem", { name: "Stockwerk bearbeiten" }),
  ).toBeDisabled();
  await page.keyboard.press("End");
  await expect(
    menu.getByRole("menuitem", { name: "Stockwerk hinzufügen" }),
  ).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(trigger).toBeFocused();
  await trigger.click();
  await menu.getByRole("menuitem", { name: "Bereich hinzufügen" }).click();
  await dialog.getByLabel("Kennung").fill("TOOLBAR");
  await dialog.getByLabel(/^Name/).fill("Toolbar Testbereich");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(area.locator("option:checked")).toHaveText(
    "Toolbar Testbereich",
  );
  await expect(floor).toBeDisabled();
  await expect(
    page.getByRole("button", { name: "Raum hinzufügen", exact: true }),
  ).toBeDisabled();
  await trigger.click();
  await menu.getByRole("menuitem", { name: "Stockwerk hinzufügen" }).click();
  await dialog.getByLabel("Kennung").fill("TB-OG1");
  await dialog.getByLabel(/^Name/).fill("Teststockwerk");
  await dialog.getByLabel("Stockwerknummer").fill("1");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await floor.selectOption({ label: "Teststockwerk" });
  await page
    .getByRole("button", { name: "Raum hinzufügen", exact: true })
    .click();
  await dialog.getByLabel("Kennung").fill("TB101");
  await dialog.getByLabel(/^Name/).fill("Toolbar Testraum");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await page
    .getByRole("button", { name: "Toolbar Testraum", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Raum bearbeiten", exact: true })
    .click();
  await dialog.getByLabel(/^Name/).fill("Verworfen");
  await dialog.getByRole("button", { name: "Abbrechen", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Toolbar Testraum", exact: true }),
  ).toBeVisible();
  await trigger.click();
  await menu.getByRole("menuitem", { name: "Stockwerk bearbeiten" }).click();
  await dialog.getByLabel(/^Name/).fill("Teststockwerk geändert");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(floor.locator("option:checked")).toHaveText(
    "Teststockwerk geändert",
  );
  await trigger.click();
  await menu.getByRole("menuitem", { name: "Bereich bearbeiten" }).click();
  await dialog.getByLabel(/^Name/).fill("Bereich geändert");
  await dialog.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(area.locator("option:checked")).toHaveText("Bereich geändert");
  await area.selectOption({ label: "Hauptgebäude" });
  await expect(floor).toHaveValue("");
  await expect(page.locator(".room-selection-hint")).toBeVisible();
});

test("Raumleisten bleiben in Hell und Dunkel bei schmalen Ansichten und doppeltem Zoom im Bildschirm", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("navigation")
    .getByRole("button", { name: "Räume", exact: true })
    .click();
  for (const theme of ["light", "dark"]) {
    await page.evaluate(
      (theme) => document.documentElement.setAttribute("data-theme", theme),
      theme,
    );
    for (const width of [390, 768, 1280, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      for (const zoom of [1, 2]) {
        await page.evaluate((zoom) => {
          document.body.style.zoom = String(zoom);
        }, zoom);
        if (zoom === 2 && width < 1280) continue;
        await expect(page.getByLabel("Bereich", { exact: true })).toBeVisible();
        expect(
          await page.evaluate(() => document.documentElement.scrollWidth),
        ).toBeLessThanOrEqual(width);
        await page.getByRole("button", { name: /Weitere Filter/ }).click();
        const popup = page.getByRole("dialog", {
          name: "Weitere Filter",
          exact: true,
        });
        const bounds = await popup.boundingBox();
        expect(bounds!.x).toBeGreaterThanOrEqual(0);
        expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(width + 1);
        await page.keyboard.press("Escape");
        await page
          .getByRole("button", { name: "Raumverwaltung", exact: true })
          .click();
        await page
          .getByRole("button", { name: "Struktur verwalten", exact: true })
          .click();
        const menuBounds = await page
          .getByRole("menu", { name: "Struktur verwalten" })
          .boundingBox();
        expect(menuBounds!.x).toBeGreaterThanOrEqual(0);
        expect(menuBounds!.x + menuBounds!.width).toBeLessThanOrEqual(
          width + 1,
        );
        await page.keyboard.press("Escape");
        expect(
          await page.evaluate(() => document.documentElement.scrollWidth),
        ).toBeLessThanOrEqual(width);
        await page
          .getByRole("button", { name: "Raumbelegung", exact: true })
          .click();
      }
      await page.evaluate(() => {
        document.body.style.zoom = "1";
      });
    }
  }
});
