import { test, expect } from "@playwright/test";

test("Dashboard steht zuerst und zeigt echte Tagesdaten mit funktionierenden Sprüngen", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-12T08:30:00+02:00") });
  await page.goto("/");
  const nav = page.getByRole("navigation", { name: "Arbeitsbereiche" });
  await expect(nav.getByRole("button").first()).toHaveAccessibleName(
    "Dashboard",
  );
  await nav.getByRole("button", { name: "Dashboard", exact: true }).click();
  await expect(page.locator(".dashboard")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Heute auf dem Campus" }),
  ).toBeVisible();
  await expect(page.locator(".dashboard-agenda-item").first()).toBeVisible();
  expect(
    await page.locator(".dashboard-agenda-item").count(),
  ).toBeLessThanOrEqual(6);
  await expect(page.locator(".dashboard")).not.toContainText("undefined");
  const state = await page.evaluate(() =>
    JSON.parse(localStorage.getItem("campustime-browser-demo-v1")!),
  );
  await expect(page.getByLabel("Erfasste Personen")).toContainText(
    String(state.data.people.length),
  );
  await page
    .getByRole("button", { name: "Personen verwalten", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "Schüler & Studierende", exact: true }),
  ).toBeVisible();
  await nav.getByRole("button", { name: "Dashboard", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ colorScheme: "dark" });
  await expect
    .poll(() =>
      page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
    )
    .toBe(true);
  await page.screenshot({
    path: ".playwright/dashboard-mobile-dark.png",
    animations: "disabled",
  });
});

test("Dashboard trennt Ausfälle und Sperren von aktiven Terminen", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-12T08:30:00+02:00") });
  await page.goto("/");
  await page.getByRole("button", { name: "Dashboard", exact: true }).click();
  await expect(page.locator(".dashboard-agenda-item").first()).toBeVisible();
  await page.evaluate(() => {
    const key = "campustime-browser-demo-v1";
    const state = JSON.parse(localStorage.getItem(key)!);
    state.data.sessions[0].cancelled = true;
    localStorage.setItem(key, JSON.stringify(state));
  });
  await page.reload();
  await page.getByRole("button", { name: "Dashboard", exact: true }).click();
  await expect(
    page.locator(".dashboard-agenda-item.cancelled").first(),
  ).toBeVisible();
  await expect(
    page.locator(".dashboard-agenda-item").filter({ hasText: "Blockzeit" }),
  ).toHaveCount(0);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.screenshot({
    path: ".playwright/dashboard-light.png",
    animations: "disabled",
  });
  await page.emulateMedia({ colorScheme: "dark" });
  await page.screenshot({
    path: ".playwright/dashboard-dark.png",
    animations: "disabled",
  });
});
