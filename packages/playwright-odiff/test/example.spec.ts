import { test, expect } from '@playwright/test';
import { toHaveScreenshotOdiff } from '../src';

// Extend expect with the custom matcher
expect.extend({ toHaveScreenshotOdiff });

test.describe('toHaveScreenshotOdiff', () => {
  test('should take and compare a full page screenshot', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff('example-homepage.png');
  });

  test('should take and compare a locator screenshot', async ({ page }) => {
    await page.goto('https://example.com');
    const heading = page.locator('h1');
    await expect(heading).toHaveScreenshotOdiff('example-heading.png');
  });

  test('should use custom threshold', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff('example-with-threshold.png', {
      threshold: 0.2,
      antialiasing: true,
    });
  });

  test('should allow some pixel differences', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff('example-tolerant.png', {
      maxDiffPixels: 100,
      maxDiffPixelRatio: 0.01,
    });
  });

  test('should use fullPage option', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff('example-fullpage.png', {
      fullPage: true,
    });
  });

  test('should mask elements', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff('example-masked.png', {
      mask: [page.locator('h1')],
      maskColor: '#00FF00',
    });
  });

  test('should use path segments', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff(['example', 'nested', 'screenshot.png']);
  });

  test('should ignore regions', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff('example-ignore-regions.png', {
      ignoreRegions: [
        { x1: 0, y1: 0, x2: 100, y2: 50 },
      ],
    });
  });

  test('should work with options object including name', async ({ page }) => {
    await page.goto('https://example.com');
    await expect(page).toHaveScreenshotOdiff({
      name: 'example-options-object.png',
      threshold: 0.15,
      fullPage: false,
    });
  });
});
