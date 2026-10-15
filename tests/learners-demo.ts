import { test, expect } from "@playwright/test";

test("Browser-Demo: Lernende nach Jahrgang und Zuordnung filtern", async ({
  page,
}) => {
  test.setTimeout(60000);
  await page.goto("/");
  const open = () =>
    page
      .getByRole("navigation", { name: "Arbeitsbereiche" })
      .getByRole("button", { name: "Schüler & Studierende", exact: true })
      .click();
  await open();
  const groups = await page.evaluate(
    () =>
      JSON.parse(localStorage.getItem("campustime-browser-demo-v1")!).data
        .groups as { id: number; name: string; cohort: number }[],
  );
  const group = groups.find(
    (candidate) =>
      groups.filter((item) => item.cohort === candidate.cohort).length > 1,
  )!;
  const same = groups.find(
    (item) => item.cohort === group.cohort && item.id !== group.id,
  )!;
  const other = groups.find((item) => item.cohort !== group.cohort)!;
  expect(group && same && other).toBeTruthy();
  const prefix = `Demo Zuordnung ${Date.now()}`;
  const first = `${prefix} Erste Person`;
  const second = `${prefix} Zweite Person`;
  const search = page.getByRole("textbox", {
    name: "Personen suchen",
    exact: true,
  });
  await search.fill(prefix);
  for (const [name, assigned] of [
    [first, [group, same]],
    [second, [other]],
  ] as const) {
    await page
      .getByRole("button", { name: "Person hinzufügen", exact: true })
      .click();
    const form = page.getByRole("dialog", {
      name: "Person hinzufügen",
      exact: true,
    });
    await form.getByRole("textbox", { name: /^Name/ }).fill(name);
    await expect(form.getByRole("textbox", { name: /^Kennung/ })).toHaveValue(
      "",
    );
    await form
      .getByRole("combobox", { name: "Jahrgang", exact: true })
      .selectOption(String(assigned[0].cohort));
    for (const item of assigned)
      await form
        .getByRole("combobox", { name: "Gruppen & Klassen", exact: true })
        .selectOption(String(item.id));
    await form.getByRole("button", { name: "Speichern", exact: true }).click();
    await expect(form).toHaveCount(0);
    await expect(
      page.locator(".learner-row").filter({ hasText: name }),
    ).toBeVisible();
  }
  const rows = page.locator(".learner-row").filter({ hasText: prefix });
  await expect(rows).toHaveCount(2);
  const cohort = page.getByLabel("Jahrgang filtern", { exact: true });
  const selection = page.getByLabel("Gruppe / Klasse filtern", { exact: true });
  await cohort.selectOption(String(group.cohort));
  await expect(rows).toHaveCount(1);
  await expect(rows).toContainText(first);
  await expect(rows).toContainText(group.name);
  await expect(rows).toContainText(same.name);
  await cohort.selectOption(String(other.cohort));
  await expect(rows).toHaveCount(1);
  await expect(rows).toContainText(second);
  await rows.getByRole("button", { name: "Bearbeiten", exact: true }).click();
  const edit = page.getByRole("dialog", {
    name: "Person bearbeiten",
    exact: true,
  });
  await edit
    .locator(".selected-chips button")
    .filter({ hasText: other.name })
    .click();
  await edit.getByRole("button", { name: "Speichern", exact: true }).click();
  await expect(edit).toHaveCount(0);
  await selection.selectOption("unassigned");
  await expect(cohort).toHaveValue("");
  await expect(rows).toHaveCount(1);
  await expect(rows).toContainText(second);
  await expect(rows).toContainText("Ohne Zuordnung");
  await page.reload();
  await open();
  await search.fill(prefix);
  await expect(rows).toHaveCount(2);
  await selection.selectOption("unassigned");
  await expect(rows).toHaveCount(1);
  await expect(rows).toContainText(second);
  const people = await page.evaluate(
    (prefix) =>
      JSON.parse(
        localStorage.getItem("campustime-browser-demo-v1")!,
      ).data.people.filter((person: { name: string }) =>
        person.name.startsWith(prefix),
      ),
    prefix,
  );
  expect(people).toHaveLength(2);
  expect(
    new Set(people.map((person: { code: string }) => person.code)).size,
  ).toBe(2);
  expect(
    people.every(
      (person: { code: string; kind: string }) =>
        person.code.startsWith("ST-") && person.kind === "learner",
    ),
  ).toBe(true);
  await page.getByRole("button", { name: "Kacheln", exact: true }).click();
  await page.getByLabel("Jahrgang oder Gruppe suchen").fill(group.name);
  await expect(
    page.getByRole("button", {
      name: `Gruppe ${group.name} öffnen`,
      exact: true,
    }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: `Gruppe ${group.name} öffnen`, exact: true })
    .click();
  await expect(
    page.getByRole("button", { name: "Liste", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByLabel("Gruppe / Klasse filtern")).toHaveValue(
    String(group.id),
  );
});
