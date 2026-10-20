import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";

test("website and demo themes can be controlled independently and survive navigation", async ({
  page,
}) => {
  await page.goto("/");
  const site = page.getByRole("button", {
    name: "Dunkler Modus für die Website",
    exact: true,
  });
  const previews = page.locator(".application-preview");
  await site.click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expect(site).toHaveAttribute("aria-pressed", "true");
  await expect(previews.first()).toHaveAttribute("data-theme", "dark");
  await previews
    .first()
    .getByRole("button", { name: "Dunkler Modus für die Produktvorschau" })
    .click();
  await expect(previews.first()).toHaveAttribute("data-theme", "light");
  await expect(previews.first()).toHaveCSS(
    "background-color",
    "rgb(255, 255, 255)",
  );
  await expect(previews.last()).toHaveAttribute("data-theme", "light");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.reload();
  await expect(previews.last()).toHaveAttribute("data-theme", "light");
  await page.getByRole("link", { name: "Impressum", exact: true }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.goto("/");
  await site.click();
  await previews
    .last()
    .getByRole("button", { name: "Dunkler Modus für die Produktvorschau" })
    .click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
  await expect(previews.last()).toHaveAttribute("data-theme", "dark");
  await expect(previews.last()).toHaveCSS(
    "background-color",
    "rgb(23, 40, 57)",
  );
});

test("contrasting website and demo themes keep accessible colors", async ({
  page,
}) => {
  await page.goto("/");
  const site = page.getByRole("button", {
    name: "Dunkler Modus für die Website",
    exact: true,
  });
  const demo = page.locator(".hero-product").getByRole("button", {
    name: "Dunkler Modus für die Produktvorschau",
    exact: true,
  });
  await demo.click();
  for (const width of [320, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    for (let combination = 0; combination < 2; combination++) {
      expect(
        (
          await new AxeBuilder({ page })
            .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
            .analyze()
        ).violations,
      ).toEqual([]);
      await site.click();
      await demo.click();
    }
  }
});

test("dark theme remains usable in all preview views, dialogs, forms and legal pages", async ({
  page,
}) => {
  for (const width of [320, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto("/");
    const site = page.getByRole("button", {
      name: "Dunkler Modus für die Website",
      exact: true,
    });
    if ((await site.getAttribute("aria-pressed")) !== "true")
      await site.click();
    const preview = page.getByRole("region", {
      name: "Produktvorschau",
      exact: true,
    });
    const nav = preview.getByRole("group", {
      name: "Produktansicht auswählen",
    });
    for (const name of ["Dashboard", "Räume", "Prüfungen", "Stundenplanung"]) {
      await nav.getByRole("button", { name, exact: true }).click();
      if (name === "Prüfungen" || name === "Stundenplanung") {
        await preview
          .getByRole("button", { name: "Gesamtübersicht öffnen", exact: true })
          .click();
      }
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
    for (const path of ["/impressum/", "/datenschutz/"]) {
      await page.goto(path);
      expect(
        (
          await new AxeBuilder({ page })
            .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
            .analyze()
        ).violations,
      ).toEqual([]);
    }
  }
});

test("blocked preference storage does not break theme controls", async ({
  page,
}) => {
  await page.addInitScript(() => {
    Object.defineProperty(window, "localStorage", {
      get() {
        throw new Error("Storage blocked");
      },
    });
  });
  await page.goto("/");
  await page
    .getByRole("button", { name: "Dunkler Modus für die Website", exact: true })
    .click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
});

test("dark mobile header keeps both controls on one row and its menu below them", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 844 });
  await page.goto("/");
  await page
    .getByRole("button", { name: "Dunkler Modus für die Website", exact: true })
    .click();
  const header = await page.locator(".site-header").boundingBox();
  expect(header!.height).toBeLessThan(90);
  await page.getByRole("button", { name: "Menü öffnen", exact: true }).click();
  const nav = await page
    .getByRole("navigation", { name: "Hauptnavigation" })
    .boundingBox();
  expect(nav!.y).toBeGreaterThanOrEqual(header!.y + header!.height - 1);
  await page.keyboard.press("Escape");
  await expect(
    page.getByRole("button", { name: "Menü öffnen", exact: true }),
  ).toBeFocused();
});
