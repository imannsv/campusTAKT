import { test, expect } from "@playwright/test";

test("dashboard handles a failed agenda separately and retries without losing navigation", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByLabel("Passwort", { exact: true }).fill("WikiBuildOnly2026!");
  await page.getByRole("button", { name: "Anmelden", exact: true }).click();
  await page.route("**/api/resource-occupancy/**", (route) =>
    route.fulfill({ status: 503, json: { detail: "Test: nicht erreichbar" } }),
  );
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Dashboard", exact: true })
    .click();
  await expect(
    page
      .getByRole("alert")
      .filter({ hasText: "Termine konnten nicht aktualisiert werden" }),
  ).toBeVisible();
  await expect(page.locator(".dashboard-day-summary")).toHaveCount(0);
  await expect(page.locator(".dashboard-exam")).toContainText(
    "Prüfungsausblick nicht verfügbar",
  );
  await expect(page.locator(".dashboard")).not.toContainText(
    "Heute keine Termine",
  );
  await expect(page.getByLabel("Erfasste Personen")).toContainText(/\d/);
  await page.unroute("**/api/resource-occupancy/**");
  await page.getByRole("button", { name: "Dashboard aktualisieren" }).click();
  await expect(page.locator(".dashboard-day-summary")).toBeVisible();
  await expect(page.getByRole("alert")).toHaveCount(0);
});
