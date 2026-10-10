import { test, expect, Page } from "@playwright/test";

const pickerFor = (page: Page) =>
  page.getByRole("button", { name: /^Darstellung:/ });
async function choose(page: Page, label: string) {
  await pickerFor(page).click();
  await page.getByRole("menuitemradio", { name: label, exact: true }).click();
}

test("Darstellung wechselt sofort, bleibt nach Neuladen erhalten und ändert keine Planungsdaten", async ({
  page,
}) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/");
  const picker = pickerFor(page);
  await expect(picker).toHaveAccessibleName("Darstellung: System");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  const before = await page.evaluate(() =>
    localStorage.getItem("campustime-browser-demo-v1"),
  );
  const logo = await page
    .locator(".sidebar .brand-symbol i")
    .evaluateAll((nodes) =>
      nodes.map((node) => getComputedStyle(node).backgroundColor),
    );
  await choose(page, "Dunkel");
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
  await expect(picker).toHaveAccessibleName("Darstellung: Dunkel");
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
  await expect(picker).toHaveAccessibleName("Darstellung: Hell");
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
  await choose(page, "Dunkel");
  await page.emulateMedia({ colorScheme: "dark" });
  await page.emulateMedia({ colorScheme: "light" });
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await choose(page, "System");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
});

test("Darstellung wird mit anderen Tabs und öffentlichen Übersichten synchronisiert", async ({
  page,
  context,
}) => {
  await page.goto("/");
  await choose(page, "Dunkel");
  const token = await page.evaluate(
    () =>
      JSON.parse(localStorage.getItem("campustime-browser-demo-v1")!).data
        .displays[0].token,
  );
  const overview = await context.newPage();
  await overview.goto(`/overview/${token}`);
  await expect(pickerFor(overview)).toHaveAccessibleName("Darstellung: Dunkel");
  await expect(overview.locator("html")).toHaveAttribute("data-theme", "dark");
  await choose(overview, "Hell");
  await expect(pickerFor(page)).toHaveAccessibleName("Darstellung: Hell");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await overview.close();
});

test("Darstellungsmenü funktioniert mit Tastatur, Escape und Klick außerhalb", async ({
  page,
}) => {
  await page.goto("/");
  const picker = pickerFor(page);
  await picker.focus();
  await page.keyboard.press("ArrowDown");
  await expect(
    page.getByRole("menuitemradio", { name: "System", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("Home");
  await expect(
    page.getByRole("menuitemradio", { name: "Hell", exact: true }),
  ).toBeFocused();
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await expect(picker).toHaveAccessibleName("Darstellung: Dunkel");
  await expect(picker).toBeFocused();
  await expect(page.getByRole("menu")).toHaveCount(0);
  await picker.click();
  await page.keyboard.press("Escape");
  await expect(picker).toBeFocused();
  await expect(page.getByRole("menu")).toHaveCount(0);
  await picker.click();
  await page
    .getByRole("heading", { name: "Stundenplanung", exact: true })
    .click();
  await expect(page.getByRole("menu")).toHaveCount(0);
});
