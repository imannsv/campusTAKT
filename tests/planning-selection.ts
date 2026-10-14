import { test, expect } from "@playwright/test";

test("Studiengangskarten füllen die kürzeste Spalte statt den Jahresabschnitt zu verlängern", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.locator(".planning-selection")).toBeVisible();
  await page.evaluate(() => {
    const key = "campustime-browser-demo-v1";
    const state = JSON.parse(localStorage.getItem(key)!);
    [3, 1, 11, 3, 7, 1].forEach((count, index) => {
      const id = 800 + index;
      state.data.programs.push({
        id,
        code: `PACK-${index}`,
        name: `Studiengang ${index}`,
      });
      state.data.cohorts.push({
        id,
        code: `PACK-${index}`,
        name: `JG30-${index}`,
        entry_year: 2030,
        program: id,
      });
      for (let group = 0; group < count; group++)
        state.data.groups.push({
          id: 8000 + index * 20 + group,
          code: `PACK-${index}-${group}`,
          name: `Gruppe ${index}-${group}`,
          cohort: id,
          size: 20,
        });
    });
    localStorage.setItem(key, JSON.stringify(state));
  });
  await page.reload();
  const year = page
    .locator(".selection-year")
    .filter({ has: page.getByRole("button", { name: /^2030 / }) });
  const cards = year.locator(".selection-program");
  await expect(cards).toHaveCount(6);
  await page.evaluate(() => document.fonts.ready);
  await expect
    .poll(async () => {
      const short = (await cards.nth(1).boundingBox())!;
      const next = (await cards.nth(3).boundingBox())!;
      return (
        Math.abs(next.x - short.x) < 1 &&
        Math.abs(next.y - short.y - short.height - 18) < 2
      );
    })
    .toBe(true);
  const bounds = await cards.evaluateAll((elements) =>
    elements.map((element) => {
      const box = element.getBoundingClientRect();
      return { x: box.x, y: box.y, right: box.right, bottom: box.bottom };
    }),
  );
  for (let i = 0; i < bounds.length; i++)
    for (const other of bounds.slice(i + 1)) {
      const box = bounds[i];
      expect(
        box.right <= other.x ||
          other.right <= box.x ||
          box.bottom <= other.y ||
          other.bottom <= box.y,
      ).toBe(true);
    }
});

test("Gruppenauswahl ordnet Jahrgänge und öffnet nur passende Pläne und Termine", async ({
  page,
}) => {
  await page.clock.install({ time: new Date("2026-10-07T08:00:00Z") });
  await page.goto("/");
  const selection = page.getByRole("region", {
    name: "Stundenplanung: Gruppe auswählen",
  });
  await expect(selection).toBeVisible();
  await expect(page.locator(".timetable")).toHaveCount(0);
  await page.evaluate(() => {
    const key = "campustime-browser-demo-v1";
    const state = JSON.parse(localStorage.getItem(key)!);
    for (const cohort of state.data.cohorts) {
      if (cohort.name.endsWith("26")) cohort.entry_year = 2026;
      if (cohort.name.endsWith("25")) cohort.entry_year = 2025;
    }
    localStorage.setItem(key, JSON.stringify(state));
  });
  await page.reload();
  const year = page.getByRole("button", { name: /^2026 \d+ Gruppen$/ });
  await expect(year).toHaveAttribute("aria-expanded", "true");
  await year.focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByRole("button", { name: "Gruppe dWI26 A1 öffnen", exact: true }),
  ).toBeHidden();
  await page.keyboard.press("Enter");
  await page
    .getByRole("button", { name: "Gruppe dWI26 A1 öffnen", exact: true })
    .click();
  await expect(page.getByLabel("Stundenplan auswählen")).toHaveValue("3");
  await expect(
    page.getByLabel("Stundenplan auswählen").locator("option"),
  ).toHaveCount(1);
  await expect(page.locator(".calendar-event")).not.toHaveCount(0);
  await expect(page.locator(".planning-scope-bar")).toContainText("dWI26 A1");
  await page
    .getByRole("button", { name: "Gruppe wechseln", exact: true })
    .click();
  await expect(selection).toBeVisible();
  await page.getByLabel("Suche", { exact: true }).fill("INF25 A2");
  await expect(page.locator(".selection-group")).toHaveCount(1);
  await page
    .getByRole("button", { name: "Gruppe INF25 A2 öffnen", exact: true })
    .click();
  await expect(page.getByLabel("Stundenplan auswählen")).toHaveValue("4");
  await expect(page.getByLabel("Suche", { exact: true })).toHaveValue("");
});

test("Prüfungen zeigen die Gruppenauswahl und beachten explizite Teilnehmer statt nur den Kurs", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.locator(".planning-selection")).toBeVisible();
  await page.evaluate(() => {
    const key = "campustime-browser-demo-v1";
    const state = JSON.parse(localStorage.getItem(key)!);
    const exam = state.data.exams.find((item: any) => item.plan === 2);
    const excluded = state.data.people.find(
      (person: any) => person.kind === "learner" && person.groups.includes(4),
    );
    state.data.exams.push({
      ...exam,
      id: 99990,
      code: "OTHER-GROUP",
      name: "Nur für A2",
      learners: [excluded.id],
    });
    localStorage.setItem(key, JSON.stringify(state));
  });
  await page.reload();
  await page
    .getByRole("navigation", { name: "Arbeitsbereiche" })
    .getByRole("button", { name: "Prüfungen", exact: true })
    .click();
  await expect(
    page.getByRole("region", { name: "Prüfungen: Gruppe auswählen" }),
  ).toBeVisible();
  await expect(page.locator(".exam-table-panel")).toHaveCount(0);
  await page
    .getByRole("button", { name: "Gruppe dWI24 A1 öffnen", exact: true })
    .click();
  await expect(page.getByLabel("Semesterplan für Prüfungen")).toHaveValue("2");
  await expect(
    page.getByRole("cell", {
      name: "Klausur · Softwarearchitektur",
      exact: true,
    }),
  ).toBeVisible();
  await expect(
    page.getByRole("cell", { name: "Nur für A2", exact: true }),
  ).toHaveCount(0);
  await page
    .getByRole("button", { name: "Gruppe wechseln", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Gruppe dWI24 A2 öffnen", exact: true })
    .click();
  await expect(
    page.getByRole("cell", { name: "Nur für A2", exact: true }),
  ).toBeVisible();
});

test("Auswahl bleibt hell und dunkel responsiv; fehlende Pläne werden nicht durch fremde ersetzt", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.locator(".planning-selection")).toBeVisible();
  for (const theme of ["Hell", "Dunkel"]) {
    await page.getByRole("button", { name: /^Darstellung:/ }).click();
    await page.getByRole("menuitemradio", { name: theme, exact: true }).click();
    for (const width of [390, 768, 1280, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      await expect
        .poll(() => page.evaluate(() => document.documentElement.scrollWidth))
        .toBeLessThanOrEqual(width);
      await expect(page.locator(".selection-group").first()).toBeVisible();
    }
    await page.screenshot({
      path: `test-results/planning-selection-${theme}.png`,
      fullPage: true,
    });
  }
  await page.evaluate(() => {
    document.body.style.zoom = "2";
  });
  await expect
    .poll(() => page.evaluate(() => document.documentElement.scrollWidth))
    .toBeLessThanOrEqual(1440);
  await page.evaluate(() => {
    document.body.style.zoom = "1";
  });
  await page
    .getByRole("button", { name: "Gruppe dWI27 A1 öffnen", exact: true })
    .click();
  await expect(page.getByLabel("Stundenplan auswählen")).toHaveValue("");
  await expect(
    page.getByRole("heading", {
      name: "Noch kein Stundenplan vorhanden",
      exact: true,
    }),
  ).toBeVisible();
  await expect(page.locator(".calendar-event")).toHaveCount(0);
});
