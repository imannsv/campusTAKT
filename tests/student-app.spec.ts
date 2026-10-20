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
  await expect
    .poll(() => provided.evaluate((el) => el.contains(document.activeElement)))
    .toBe(true);
  await provided.getByRole("button", { name: "Fertig", exact: true }).click();
  const listing = await (
    await page.request.get("/api/student-app/accesses/")
  ).json();
  expect(JSON.stringify(listing)).not.toContain(result.password);
  await page.reload();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Studierenden-App", exact: true })
    .click();
  const accessRow = page
    .locator(".student-admin-row")
    .filter({ hasText: result.code });
  const reopening = page.waitForResponse(
    (response) =>
      response
        .url()
        .endsWith(`/api/student-app/accesses/${result.id}/credentials/`) &&
      response.request().method() === "GET",
  );
  await accessRow
    .getByRole("button", { name: "Zugang anzeigen", exact: true })
    .click();
  const reopened = await (await reopening).json();
  expect(reopened.qr_payload === result.qr_payload).toBe(true);
  expect(reopened.password).toBeUndefined();
  await expect(
    provided.getByRole("img", { name: /Anmelde-QR-Code/ }),
  ).toBeVisible();
  await expect(provided).toContainText("Wird nur bei der Erstellung angezeigt");
  await expect(
    provided.getByRole("link", { name: "QR-Code speichern", exact: true }),
  ).toHaveAttribute("download", `campuszeit-${result.code}.svg`);
  await provided.getByRole("button", { name: "Fertig", exact: true }).click();
  // Exercise the address prompt for accesses created before addresses were stored.
  let pauseReload = false;
  let finishReload!: () => void;
  const reloadGate = new Promise<void>((resolve) => {
    finishReload = resolve;
  });
  await page.route("**/api/student-app/accesses/", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    const response = await route.fetch();
    const rows = await response.json();
    if (pauseReload) await reloadGate;
    await route.fulfill({
      response,
      json: rows.map((row: any) =>
        row.id === result.id ? { ...row, server: "" } : row,
      ),
    });
  });
  await page.reload();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Studierenden-App", exact: true })
    .click();
  await accessRow
    .getByRole("button", { name: "Zugang anzeigen", exact: true })
    .click();
  const legacy = page.getByRole("dialog", {
    name: "Zugang anzeigen",
    exact: true,
  });
  await expect(legacy.getByLabel("Zielgruppe")).toBeDisabled();
  await legacy.getByLabel("Serveradresse").fill("http://127.0.0.1:8123");
  pauseReload = true;
  await legacy
    .getByRole("button", { name: "QR-Code anzeigen", exact: true })
    .click();
  await expect(
    provided.getByRole("img", { name: /Anmelde-QR-Code/ }),
  ).toBeVisible();
  try {
    await expect(
      provided.getByRole("button", { name: "Fertig", exact: true }),
    ).toBeDisabled();
  } finally {
    finishReload();
  }
  await provided.getByRole("button", { name: "Fertig", exact: true }).click();
  await expect(provided).toHaveCount(0);
  await page.unroute("**/api/student-app/accesses/");
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
    .getByRole("textbox", { name: "Mitteilung", exact: true })
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
  await expect(
    rows.getByRole("button", { name: "Zugang anzeigen", exact: true }),
  ).toBeDisabled();
});

test("access credentials can be copied or manually selected when clipboard access is unavailable", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
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
  const group = await form
    .locator('optgroup[label="Gruppen"] option')
    .first()
    .getAttribute("value");
  await form.getByLabel("Zielgruppe").selectOption(group!);
  await form.getByLabel("Serveradresse").fill("http://127.0.0.1:8123");
  await form
    .getByRole("button", { name: "Zugang erstellen", exact: true })
    .click();
  const provided = page.getByRole("dialog", { name: "Zugang bereitstellen" });
  const copy = provided.getByRole("button", {
    name: "Zugangsdaten kopieren",
    exact: true,
  });
  await expect(copy).toBeVisible();
  await page.evaluate(() =>
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: undefined,
    }),
  );
  await copy.click();
  const fallback = provided.getByRole("alert");
  await expect(fallback).toHaveText(
    "Kopieren fehlgeschlagen. Bitte die Angaben auswählen und kopieren.",
  );
  expect(errors).toEqual([]);
  await page.evaluate(() =>
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: {
        writeText: async () => {
          throw new DOMException("Denied", "NotAllowedError");
        },
      },
    }),
  );
  await copy.click();
  await expect(fallback).toBeVisible();
  expect(errors).toEqual([]);
  await page.evaluate(() => {
    let copied = "";
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: {
        writeText: async (text: string) => {
          copied = text;
        },
        readText: async () => copied,
      },
    });
  });
  await copy.click();
  await expect(fallback).toHaveCount(0);
  const details = provided.locator("dd");
  const [scope, server, code, password] = await details.allTextContents();
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(
    `CampusZeit · ${scope}\nServer: ${server}\nZugangscode: ${code}\nPasswort: ${password}`,
  );
  expect(errors).toEqual([]);
});

test("notice dialog keeps focus while typing and protects current unsaved changes", async ({
  page,
}) => {
  await page.goto("/");
  await page.getByLabel("Passwort", { exact: true }).fill("WikiBuildOnly2026!");
  await page.getByRole("button", { name: "Anmelden", exact: true }).click();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Studierenden-App", exact: true })
    .click();
  const opener = page.getByRole("button", {
    name: "Mitteilung erstellen",
    exact: true,
  });
  await opener.click();
  const notice = page.getByRole("dialog", {
    name: "Mitteilung veröffentlichen",
  });
  const close = notice.getByRole("button", { name: "Schließen", exact: true });
  const publish = notice.getByRole("button", {
    name: "Veröffentlichen",
    exact: true,
  });
  await expect(close).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(publish).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(close).toBeFocused();
  const title = notice.getByRole("textbox", { name: "Titel", exact: true });
  await title.focus();
  for (const letter of "Raumänderung") {
    await page.keyboard.type(letter);
    await expect(title).toBeFocused();
  }
  await expect(title).toHaveValue("Raumänderung");
  const body = notice.getByRole("textbox", { name: "Mitteilung", exact: true });
  await body.focus();
  for (const letter of "Zeile eins\nZeile zwei") {
    await page.keyboard.type(letter);
    await expect(body).toBeFocused();
  }
  await expect(body).toHaveValue("Zeile eins\nZeile zwei");
  const discardRejected = page.waitForEvent("dialog");
  page.once("dialog", (dialog) => dialog.dismiss());
  await page.keyboard.press("Escape");
  expect((await discardRejected).message()).toBe(
    "Ungespeicherte Eingaben verwerfen?",
  );
  await expect(notice).toBeVisible();
  await expect(body).toBeFocused();
  await expect(body).toHaveValue("Zeile eins\nZeile zwei");
  const discardAccepted = page.waitForEvent("dialog");
  page.once("dialog", (dialog) => dialog.accept());
  await page.keyboard.press("Escape");
  expect((await discardAccepted).message()).toBe(
    "Ungespeicherte Eingaben verwerfen?",
  );
  await expect(notice).toHaveCount(0);
  await expect(opener).toBeFocused();
});
