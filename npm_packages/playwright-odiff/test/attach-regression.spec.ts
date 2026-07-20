import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { test, expect } from "@playwright/test";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const testPagePath = `file://${path.resolve(__dirname, "fixtures/test-page.html")}`;

// Regression test for Playwright >= 1.60 where matcher contexts no longer
// receive `_stepInfo` / `_attachToStep`: attachments must be returned on the
// matcher result instead. See https://github.com/dmtrKovalenko/odiff/issues/175
test.describe("attachments regression", () => {
  test("failing comparison attaches expected/actual/diff to the report", async ({
    page,
  }, testInfo) => {
    // In update mode the matcher (correctly) rewrites the baseline instead of failing
    test.skip(
      testInfo.config.updateSnapshots !== "missing" &&
        testInfo.config.updateSnapshots !== "none",
      "not applicable when running with --update-snapshots",
    );

    await page.goto(testPagePath);
    await page.waitForLoadState("networkidle");

    // Create a clean baseline for this exact platform/viewport on the fly
    const snapshotName = "attach-check.png";
    const expectedPath = testInfo.snapshotPath(snapshotName);
    fs.mkdirSync(path.dirname(expectedPath), { recursive: true });
    await page.screenshot({
      path: expectedPath,
      animations: "disabled",
      caret: "hide",
      scale: "css",
    });

    // Force a mismatch against the clean baseline
    await page.evaluate(() => {
      document.body.style.background = "red";
      const h = document.querySelector("h1");
      if (h) h.textContent = "TOTALLY DIFFERENT";
    });

    let failed = false;
    try {
      await expect(page).toHaveScreenshotOdiff(snapshotName, {
        timeout: 3000,
      });
    } catch {
      failed = true;
    } finally {
      fs.rmSync(expectedPath, { force: true });
    }

    expect(failed).toBe(true);
    const names = testInfo.attachments.map((a) => a.name).sort();
    expect(names.some((n) => n.includes("-expected"))).toBe(true);
    expect(names.some((n) => n.includes("-actual"))).toBe(true);
    expect(names.some((n) => n.includes("-diff"))).toBe(true);
  });

  test("works with both page and locator receivers (issue #175)", async ({
    page,
  }, testInfo) => {
    await page.goto(testPagePath);
    await page.waitForLoadState("networkidle");

    // Baselines are generated with the plain public screenshot API. The matcher
    // must produce pixel-identical output (compatibility with page.screenshot()).
    const screenshotOptions = {
      animations: "disabled",
      caret: "hide",
      scale: "css",
    } as const;

    const pagePath = testInfo.snapshotPath("issue-175-page.png");
    const locatorPath = testInfo.snapshotPath("issue-175-locator.png");
    fs.mkdirSync(path.dirname(pagePath), { recursive: true });
    await page.screenshot({ path: pagePath, ...screenshotOptions });
    const header = page.locator(".header");
    await header.screenshot({ path: locatorPath, ...screenshotOptions });

    try {
      // Neither call should throw `pageOrLocator.page is not a function`
      // (Page/Locator detection must not rely on constructor names).
      await expect(page).toHaveScreenshotOdiff("issue-175-page.png");
      await expect(header).toHaveScreenshotOdiff("issue-175-locator.png");
    } finally {
      fs.rmSync(pagePath, { force: true });
      fs.rmSync(locatorPath, { force: true });
    }
  });
});
