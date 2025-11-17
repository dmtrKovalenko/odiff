import { test, expect } from '@playwright/test';
import { toHaveScreenshotOdiff } from '../src';
import path from 'path';

// Extend expect with the custom matcher
expect.extend({ toHaveScreenshotOdiff });

test.describe('toHaveScreenshotOdiff - Integration Tests', () => {
  const testPagePath = `file://${path.resolve(__dirname, 'fixtures/test-page.html')}`;

  test('should take and compare full page screenshot', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-full.png');
  });

  test('should take and compare screenshot with custom threshold', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-threshold.png', {
      threshold: 0.15,
      antialiasing: true,
    });
  });

  test('should take and compare locator screenshot', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    const header = page.locator('.header');
    await expect(header).toHaveScreenshotOdiff('test-page-header.png');
  });

  test('should take screenshot of specific feature section', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    const features = page.locator('.content');
    await expect(features).toHaveScreenshotOdiff('test-page-features.png', {
      threshold: 0.1,
    });
  });

  test('should take screenshot of stats section', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    const stats = page.locator('.stats');
    await expect(stats).toHaveScreenshotOdiff('test-page-stats.png');
  });

  test('should allow pixel differences within tolerance', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-tolerant.png', {
      maxDiffPixels: 100,
      maxDiffPixelRatio: 0.01,
      threshold: 0.1,
    });
  });

  test('should use path segments for organized snapshots', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff(['integration', 'test-page.png']);
  });

  test('should work with options object including name', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff({
      name: 'test-page-options.png',
      threshold: 0.1,
      antialiasing: true,
    });
  });

  test('should mask elements before comparison', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    // Mask the test marker badge that has absolute positioning
    const testMarker = page.locator('.test-marker');

    await expect(page).toHaveScreenshotOdiff('test-page-masked.png', {
      mask: [testMarker],
      maskColor: '#FF00FF',
    });
  });

  test('should compare individual feature cards', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    const features = await page.locator('.feature').all();

    for (let i = 0; i < features.length; i++) {
      await expect(features[i]).toHaveScreenshotOdiff(`test-page-feature-${i + 1}.png`);
    }
  });

  test('should handle viewport changes', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 720 });
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-1280x720.png');
  });

  test('should work with fullPage option', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-fullpage.png', {
      fullPage: true,
    });
  });

  test('should compare with custom diff color', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-custom-diff.png', {
      diffColor: '#FF0000',
      threshold: 0.1,
    });
  });

  test('should take screenshot with animations disabled', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-no-animations.png', {
      animations: 'disabled',
      timeout: 10000,
    });
  });

  test('should handle clipped screenshots', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-clipped.png', {
      clip: {
        x: 0,
        y: 0,
        width: 400,
        height: 300,
      },
    });
  });
});

test.describe('toHaveScreenshotOdiff - Edge Cases', () => {
  const testPagePath = `file://${path.resolve(__dirname, 'fixtures/test-page.html')}`;

  test('should handle very small elements', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    const icon = page.locator('.feature-icon').first();
    await expect(icon).toHaveScreenshotOdiff('test-page-icon.png', {
      threshold: 0.1,
    });
  });

  test('should compare with high precision', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshotOdiff('test-page-precise.png', {
      threshold: 0.01, // Very strict
      antialiasing: false, // Don't ignore antialiasing
    });
  });

  test('should work with negative test (.not)', async ({ page }) => {
    await page.goto(testPagePath);
    await page.waitForLoadState('networkidle');

    // Modify the page slightly
    await page.evaluate(() => {
      const header = document.querySelector('.header h1');
      if (header) header.textContent = 'Modified Content';
    });

    // This should pass because the content IS different
    await expect(page).not.toHaveScreenshotOdiff('test-page-full.png');
  });
});
