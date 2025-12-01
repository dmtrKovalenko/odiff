import path from "path";
import { fileURLToPath } from "url";
import { test, expect } from "@playwright/test";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

test.describe("toHaveScreenshotOdiff - Dynamic Content", () => {
  const dynamicPagePath = `file://${path.resolve(__dirname, "fixtures/dynamic-page.html")}`;

  test("should detect different screenshots with .not", async ({ page }) => {
    await page.goto(dynamicPagePath);
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveScreenshotOdiff("dynamic-first.png");

    await page.click("#trigger");
    await page.waitForTimeout(100);

    await expect(page).not.toHaveScreenshotOdiff("dynamic-first.png");
  });

  test("should match with mask over dynamic number", async ({ page }) => {
    await page.goto(dynamicPagePath);
    await page.waitForLoadState("networkidle");

    const bigNumber = page.locator(".big-number");

    // Take first screenshot with mask over just the number
    await expect(page).toHaveScreenshotOdiff("dynamic-masked.png", {
      mask: [bigNumber],
      maskColor: "#000000",
    });

    // Click trigger to change the number
    await page.click("#trigger");

    // Without mask, screenshots would be different
    await expect(page).not.toHaveScreenshotOdiff("dynamic-masked.png");

    // Should still match because big number is masked
    await expect(page).toHaveScreenshotOdiff("dynamic-masked.png", {
      threshold: 0.4,
      mask: [bigNumber],
      maskColor: "#000000",
    });
  });
});
