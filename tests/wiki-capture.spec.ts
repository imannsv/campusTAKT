import { test, expect } from "@playwright/test";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { captureWikiView } from "../scripts/wiki-capture.mjs";

test("wiki capture waits for delayed view data before replacing its image", async ({
  page,
}) => {
  const directory = await mkdtemp(path.join(tmpdir(), "wiki-capture-"));
  try {
    await page.route("https://wiki-fixture.test/data", async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 800));
      await route.fulfill({
        json: { loaded: true },
        headers: { "Access-Control-Allow-Origin": "*" },
      });
    });
    await page.setContent(`<style>body { margin: 0; background: red; }</style>
      <main class="main-content"><button>Ansicht öffnen</button></main>
      <script>document.querySelector('button').onclick = async () => {
        await (await fetch('https://wiki-fixture.test/data')).json();
        document.body.style.background = 'green';
        document.querySelector('main').classList.add('loaded');
      };</script>`);
    await page.waitForLoadState("networkidle");
    await page.getByRole("button").click();
    await captureWikiView(
      page,
      directory,
      page.locator("main.loaded"),
      "dashboard",
      "alias",
    );
    const bytes = await readFile(path.join(directory, "dashboard.png"));
    expect(await readFile(path.join(directory, "alias.png"))).toEqual(bytes);
    const pixel = await page.evaluate(
      async (source) => {
        const image = new Image();
        image.src = source;
        await image.decode();
        const canvas = document.createElement("canvas");
        canvas.width = image.width;
        canvas.height = image.height;
        const context = canvas.getContext("2d")!;
        context.drawImage(image, 0, 0);
        return Array.from(context.getImageData(100, 100, 1, 1).data);
      },
      `data:image/png;base64,${bytes.toString("base64")}`,
    );
    expect(pixel).toEqual([0, 128, 0, 255]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("wiki capture preserves the previous image when view data never arrives", async ({
  page,
}) => {
  const directory = await mkdtemp(path.join(tmpdir(), "wiki-capture-"));
  try {
    const filename = path.join(directory, "dashboard.png");
    await writeFile(filename, "previous image");
    await page.setContent('<main class="main-content">Laden …</main>');
    await page.waitForLoadState("networkidle");
    page.setDefaultTimeout(150);
    await expect(
      captureWikiView(
        page,
        directory,
        page.locator("main.loaded"),
        "dashboard",
      ),
    ).rejects.toThrow();
    expect(await readFile(filename, "utf8")).toBe("previous image");
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("wiki capture rejects stale rows after a failed resource request", async ({
  page,
}) => {
  const directory = await mkdtemp(path.join(tmpdir(), "wiki-capture-"));
  try {
    const filename = path.join(directory, "electives.png");
    await writeFile(filename, "previous electives image");
    await page.setContent(`<main class="main-content"><section class="data-panel">
      <div class="error-box">Veranstaltungen konnten nicht geladen werden.</div>
      <table><tbody><tr><td>Alte Raumblockierung</td></tr></tbody></table>
    </section></main>`);
    await expect(
      captureWikiView(
        page,
        directory,
        page.locator(".data-panel:not(:has(.table-loading)) tbody tr").first(),
        "electives",
      ),
    ).rejects.toThrow("Wiki-Aufnahme abgebrochen");
    expect(await readFile(filename, "utf8")).toBe("previous electives image");
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
