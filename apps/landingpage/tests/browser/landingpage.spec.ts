import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("product benefits and honest demo link are present", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Die Planungszentrale für Ihren Hochschulalltag.",
  );
  const demo = page.getByRole("link", { name: "Demo ausprobieren" }).first();
  await expect(demo).toHaveAttribute(
    "href",
    "https://campustime-flame.vercel.app",
  );
  await expect(
    page
      .getByText("Die Browser-Demo verwendet fiktive Testdaten.", {
        exact: false,
      })
      .first(),
  ).toBeVisible();
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    "noindex, nofollow",
  );
});

test("product view selector exposes meaningful room and exam examples", async ({
  page,
}) => {
  await page.goto("/#produkt");
  const preview = page.getByRole("region", { name: "Produktvorschau" });
  await preview
    .getByRole("group", { name: "Produktansicht auswählen" })
    .getByRole("button", { name: "Räume", exact: true })
    .click();
  await expect(preview.getByText("Seminarraum A.204")).toBeVisible();
  await preview
    .getByRole("group", { name: "Produktansicht auswählen" })
    .getByRole("button", { name: "Prüfungen", exact: true })
    .click();
  await expect(preview.getByText("Statistik · Klausur")).toBeVisible();
  await preview
    .getByRole("group", { name: "Produktansicht auswählen" })
    .getByRole("button", { name: "Stundenplanung", exact: true })
    .click();
  await expect(preview.getByText("Wochenplanung")).toBeVisible();
});

test("planning preview allows keyboard selection and shows the matching saved example", async ({
  page,
}) => {
  await page.goto("/#produkt");
  const preview = page.getByRole("region", { name: "Produktvorschau" });
  const event = preview.getByRole("button", {
    name: "Montag: Projektmanagement, 08:30–10:00",
  });
  await event.focus();
  await page.keyboard.press("Enter");
  await expect(event).toHaveAttribute("aria-pressed", "true");
  const detail = page.getByRole("dialog", { name: "Termindetails" });
  await expect(
    detail.getByRole("heading", { name: "Projektmanagement", exact: true }),
  ).toBeVisible();
  await expect(detail.getByText("A.204", { exact: true })).toBeVisible();
  await expect(
    detail.getByText("WI26 · Gruppe A", { exact: true }),
  ).toBeVisible();
  await expect(
    detail.getByRole("button", { name: "Termindetails schließen" }),
  ).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(detail).not.toBeVisible();
  await expect(event).toBeFocused();
  await preview
    .getByRole("button", { name: "Dienstag: Mathematik, 10:15–11:45" })
    .click();
  await expect(
    detail.getByRole("heading", { name: "Mathematik", exact: true }),
  ).toBeVisible();
  await expect(event).toHaveAttribute("aria-pressed", "false");
  await expect(detail.getByText("B.101", { exact: true })).toBeVisible();
});

test("mobile exam badges and tablet event text stay inside their panels", async ({
  page,
}) => {
  for (const width of [320, 390, 600]) {
    await page.setViewportSize({ width, height: 844 });
    await page.goto("/#produkt");
    const preview = page.getByRole("region", { name: "Produktvorschau" });
    await preview
      .getByRole("group", { name: "Produktansicht auswählen" })
      .getByRole("button", { name: "Prüfungen", exact: true })
      .click();
    expect(
      await preview.locator(".exam-tag").evaluateAll((tags) =>
        tags.every((tag) => {
          const parent = tag.closest(".exam-demo")!.getBoundingClientRect();
          const rect = tag.getBoundingClientRect();
          return rect.left >= parent.left && rect.right <= parent.right;
        }),
      ),
    ).toBe(true);
  }
  await page.setViewportSize({ width: 768, height: 1000 });
  await page.goto("/");
  expect(
    await page.locator(".week-calendar .schedule-event").evaluateAll((events) =>
      events.every((event) => {
        const bounds = event.getBoundingClientRect();
        return Array.from(event.children).every(
          (child) => child.getBoundingClientRect().bottom <= bounds.bottom,
        );
      }),
    ),
  ).toBe(true);
});

test("mobile navigation supports Escape, focus return and closes after navigation", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const menu = page.getByRole("button", { name: "Menü öffnen" });
  await menu.click();
  await expect(
    page.getByRole("button", { name: "Menü schließen" }),
  ).toHaveAttribute("aria-expanded", "true");
  await page.keyboard.press("Escape");
  await expect(menu).toBeFocused();
  await menu.click();
  await page
    .getByRole("navigation", { name: "Hauptnavigation" })
    .getByRole("link", { name: "Ablauf", exact: true })
    .click();
  await expect(page).toHaveURL(/#ablauf$/);
  await expect(menu).toHaveAttribute("aria-expanded", "false");
});

test("FAQ can be opened with the keyboard and does not overpromise backend functions", async ({
  page,
}) => {
  await page.goto("/#fragen");
  const question = page.getByText(
    "Was kann ich in der Browser-Demo ausprobieren?",
    { exact: true },
  );
  await question.focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByText(
      "Automatische Planung und Dateiimporte benötigen das Backend.",
      { exact: false },
    ),
  ).toBeVisible();
});

test("legal drafts, contact fallback and unknown routes are honest and reachable", async ({
  page,
}) => {
  await page.goto("/#kontakt");
  await expect(
    page.getByText("Der persönliche Kontaktweg wird gerade eingerichtet.", {
      exact: true,
    }),
  ).toBeVisible();
  await expect(page.locator("form")).toHaveCount(0);
  await page.getByRole("link", { name: "Impressum", exact: true }).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Impressum");
  await expect(
    page.getByText("Noch nicht zur Veröffentlichung freigegeben.", {
      exact: true,
    }),
  ).toBeVisible();
  expect(await page.locator(".legal-page section").count()).toBeGreaterThan(0);
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
    "content",
    "noindex, nofollow",
  );
  await page.goto("/datenschutz/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Datenschutz",
  );
  expect(await page.locator(".legal-page section").count()).toBeGreaterThan(0);
  await page.setViewportSize({ width: 320, height: 844 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  await page.goto("/diese-seite-gibt-es-nicht");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Hier geht es nicht weiter.",
  );
});

test("complete content and FAQ remain usable without JavaScript", async ({
  browser,
}) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:4180/");
  await expect(
    page
      .getByRole("region", { name: "Produktvorschau" })
      .getByRole("button", { name: "Dienstag: Mathematik, 10:15–11:45" }),
  ).toBeDisabled();
  await expect(
    page
      .getByText(
        "Statische Vorschau. In der Browser-Demo können Sie die Oberfläche ausprobieren.",
      )
      .first(),
  ).toBeVisible();
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "Die Planungszentrale",
  );
  await page
    .getByText("Was kann ich in der Browser-Demo ausprobieren?", {
      exact: true,
    })
    .click();
  await expect(
    page.getByText(
      "Automatische Planung und Dateiimporte benötigen das Backend.",
      { exact: false },
    ),
  ).toBeVisible();
  await page
    .getByRole("navigation", { name: "Hauptnavigation" })
    .getByRole("link", { name: "Ablauf", exact: true })
    .click();
  const heading = await page.locator("#workflow-title").boundingBox();
  const header = await page.locator(".site-header").boundingBox();
  expect(heading!.y).toBeGreaterThanOrEqual(
    Math.max(0, header!.y + header!.height),
  );
  await context.close();
});

test("mobile, tablet and desktop fit the viewport and meet accessibility checks", async ({
  page,
}) => {
  for (const width of [320, 390, 768, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto("/");
    await expect(
      page
        .getByRole("region", { name: "Produktvorschau" })
        .locator(".brand:visible"),
    ).toBeVisible();
    await expect
      .poll(() =>
        page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
      )
      .toBe(true);
    const audit = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();
    expect(audit.violations).toEqual([]);
  }
});

test("preview sidebar collapses without losing navigation", async ({
  page,
}) => {
  await page.goto("/#produkt");
  const preview = page.getByRole("region", { name: "Produktvorschau" });
  const collapse = preview.getByRole("button", {
    name: "Seitenleiste einklappen",
    exact: true,
  });
  await collapse.click();
  await expect(
    preview.getByRole("button", {
      name: "Seitenleiste ausklappen",
      exact: true,
    }),
  ).toHaveAttribute("aria-expanded", "false");
  await preview
    .getByRole("group", { name: "Produktansicht auswählen" })
    .getByRole("button", { name: "Räume", exact: true })
    .click();
  await expect(
    preview.getByRole("table", { name: "Raumbelegung am 15. Oktober" }),
  ).toBeVisible();
  await preview
    .getByRole("button", { name: "Raumverwaltung", exact: true })
    .click();
  await expect(preview.getByText("Beamer · Whiteboard").first()).toBeVisible();
});

test("exam preview separates planned exams, deadlines and requirements", async ({
  page,
}) => {
  await page.goto("/#produkt");
  const preview = page.getByRole("region", { name: "Produktvorschau" });
  await preview
    .getByRole("group", { name: "Produktansicht auswählen" })
    .getByRole("button", { name: "Prüfungen", exact: true })
    .click();
  await expect(preview.getByText("Statistik · Klausur")).toBeVisible();
  await expect(
    preview.getByText("Projektmanagement · Hausarbeit"),
  ).not.toBeVisible();
  await preview
    .getByRole("button", { name: "Abgaben & Fristen", exact: true })
    .click();
  await expect(
    preview.getByText("Projektmanagement · Hausarbeit"),
  ).toBeVisible();
  await preview
    .getByRole("button", { name: "Anforderungen", exact: true })
    .click();
  await expect(preview.getByText("Klausur · 120 Minuten")).toBeVisible();
});

test("room, exam and dialog previews remain accessible on mobile and desktop", async ({
  page,
}) => {
  for (const width of [390, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto("/");
    const preview = page.getByRole("region", { name: "Produktvorschau" });
    const nav = preview.getByRole("group", {
      name: "Produktansicht auswählen",
    });
    for (const name of ["Räume", "Prüfungen", "Stundenplanung"]) {
      await nav.getByRole("button", { name, exact: true }).click();
      if (name === "Stundenplanung")
        await preview
          .getByRole("button", {
            name: "Montag: Projektmanagement, 08:30–10:00",
          })
          .click();
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
      ).toBe(true);
      const audit = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
        .analyze();
      expect(audit.violations).toEqual([]);
      if (name === "Stundenplanung") await page.keyboard.press("Escape");
    }
  }
});
