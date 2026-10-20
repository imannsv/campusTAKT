import fs from "node:fs/promises";
import path from "node:path";

export async function captureWikiView(page, directory, ready, ...names) {
  await ready.waitFor();
  if (
    await page
      .locator("main.main-content .error-box, main.main-content [role='alert']")
      .count()
  )
    throw new Error(
      "Wiki-Aufnahme abgebrochen: Die Ansicht enthält einen Ladefehler.",
    );
  await page.evaluate(() => document.fonts.ready);
  const main = page.locator("main.main-content");
  await main
    .evaluate((el) => (el.scrollTop = 0), { timeout: 1000 })
    .catch(() => {});
  await page.evaluate(() => window.scrollTo(0, 0));
  const bytes = await page.screenshot({ animations: "disabled" });
  for (const name of names) {
    const target = path.join(directory, name + ".png");
    const temporary = target + ".tmp";
    try {
      await fs.writeFile(temporary, bytes);
      await fs.rename(temporary, target);
    } finally {
      await fs.rm(temporary, { force: true });
    }
  }
}
