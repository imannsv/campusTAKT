import { test, expect } from "@playwright/test";

test("Darstellung wechselt sofort, bleibt nach Neuladen erhalten und ändert keine Planungsdaten", async ({
  page,
}) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/");
  const picker = page.getByRole("combobox", {
    name: "Darstellung",
    exact: true,
  });
  await expect(picker).toHaveValue("system");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  const before = await page.evaluate(() =>
    localStorage.getItem("campustime-browser-demo-v1"),
  );
  const logo = await page
    .locator(".sidebar .brand-symbol i")
    .evaluateAll((nodes) =>
      nodes.map((node) => getComputedStyle(node).backgroundColor),
    );
  await picker.selectOption("dark");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expect(page.locator(".sidebar")).toHaveCSS(
    "background-color",
    "rgb(27, 38, 51)",
  );
  expect(
    await page
      .locator(".sidebar .brand-symbol i")
      .evaluateAll((nodes) =>
        nodes.map((node) => getComputedStyle(node).backgroundColor),
      ),
  ).toEqual(logo);
  expect(
    await page.evaluate(() =>
      localStorage.getItem("campustime-browser-demo-v1"),
    ),
  ).toBe(before);
  await page.reload();
  await expect(picker).toHaveValue("dark");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page
    .getByRole("button", { name: "Einstellungen", exact: true })
    .click();
  const settings = page.getByRole("group", {
    name: "Darstellung wählen",
    exact: true,
  });
  await expect(
    settings.getByRole("button", { name: "Dunkel", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  await settings.getByRole("button", { name: "Hell", exact: true }).click();
  await expect(picker).toHaveValue("light");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await expect(page.locator(".sidebar")).toHaveCSS(
    "background-color",
    "rgb(255, 255, 255)",
  );
});

test("Systemdarstellung reagiert auf Änderungen; explizite Auswahl bleibt unabhängig", async ({
  page,
}) => {
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto("/");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.emulateMedia({ colorScheme: "light" });
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await page.getByLabel("Darstellung", { exact: true }).selectOption("dark");
  await page.emulateMedia({ colorScheme: "dark" });
  await page.emulateMedia({ colorScheme: "light" });
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.getByLabel("Darstellung", { exact: true }).selectOption("system");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
});

test("Darstellung wird mit anderen Tabs und öffentlichen Übersichten synchronisiert", async ({
  page,
  context,
}) => {
  await page.goto("/");
  await page.getByLabel("Darstellung", { exact: true }).selectOption("dark");
  const token = await page.evaluate(
    () =>
      JSON.parse(localStorage.getItem("campustime-browser-demo-v1")!).data
        .displays[0].token,
  );
  const overview = await context.newPage();
  await overview.goto(`/overview/${token}`);
  await expect(overview.getByLabel("Darstellung", { exact: true })).toHaveValue(
    "dark",
  );
  await expect(overview.locator("html")).toHaveAttribute("data-theme", "dark");
  await overview
    .getByLabel("Darstellung", { exact: true })
    .selectOption("light");
  await expect(page.getByLabel("Darstellung", { exact: true })).toHaveValue(
    "light",
  );
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await overview.close();
});
