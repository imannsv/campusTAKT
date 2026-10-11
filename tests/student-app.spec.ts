import { test, expect } from "@playwright/test";

test("administration provides QR access and notices without exposing stored secrets", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByLabel("Passwort", { exact: true }).fill("WikiBuildOnly2026!");
  await page.getByRole("button", { name: "Anmelden", exact: true }).click();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Studierenden-App", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Zugang erstellen", exact: true })
    .click();
  const form = page.getByRole("dialog", { name: "Gruppenzugang erstellen" });
  const firstGroup = await form
    .locator('optgroup[label="Gruppen"] option')
    .first()
    .getAttribute("value");
  await form.getByLabel("Zielgruppe").selectOption(firstGroup!);
  await form.getByLabel("Serveradresse").fill("http://127.0.0.1:8123");
  const creation = page.waitForResponse(
    (response) =>
      response.url().endsWith("/api/student-app/accesses/") &&
      response.request().method() === "POST",
  );
  await form
    .getByRole("button", { name: "Zugang erstellen", exact: true })
    .click();
  const result = await (await creation).json();
  const provided = page.getByRole("dialog", { name: "Zugang bereitstellen" });
  await expect(
    provided.getByRole("img", { name: /Anmelde-QR-Code/ }),
  ).toBeVisible();
  await expect(provided).toContainText(result.password);
  await provided.getByRole("button", { name: "Fertig", exact: true }).click();
  const listing = await (
    await page.request.get("/api/student-app/accesses/")
  ).json();
  expect(JSON.stringify(listing)).not.toContain(result.password);
  await page
    .getByRole("button", { name: "Mitteilung erstellen", exact: true })
    .click();
  const notice = page.getByRole("dialog", {
    name: "Mitteilung veröffentlichen",
  });
  await notice
    .getByLabel("Titel", { exact: true })
    .fill("Raumänderung für Donnerstag");
  await notice
    .getByLabel("Mitteilung", { exact: true })
    .fill("Die Vorlesung findet in R 1.1 statt.");
  await notice
    .getByRole("button", { name: "Veröffentlichen", exact: true })
    .click();
  await expect(notice).toHaveCount(0);
  await expect(
    page
      .locator(".student-admin-row")
      .filter({ hasText: "Raumänderung für Donnerstag" }),
  ).toBeVisible();
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  const rows = page
    .locator(".student-admin-row")
    .filter({ hasText: result.code });
  page.once("dialog", (dialog) => dialog.accept());
  await rows.getByRole("button", { name: "Sperren", exact: true }).click();
  await expect(rows).toContainText("Gesperrt");
});
