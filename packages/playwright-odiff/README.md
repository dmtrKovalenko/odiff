# playwright-odiff

> Playwright custom matcher using **odiff** for blazing fast screenshot comparison

This package provides a `toHaveScreenshotOdiff()` matcher for Playwright that uses [odiff](https://github.com/dmtrKovalenko/odiff) - the fastest pixel-by-pixel image difference tool - for screenshot comparison. It's a **100% drop-in replacement** for Playwright's `toHaveScreenshot()` matcher with the same API and file structure.

## Features

- ✅ **6x faster** than pixelmatch and ImageMagick
- ✅ **Same folder structure** as Playwright's built-in matcher
- ✅ **Same API** as `toHaveScreenshot()` - drop-in replacement
- ✅ Works with both `Page` and `Locator`
- ✅ Supports all Playwright screenshot options
- ✅ Advanced odiff features: antialiasing detection, ignore regions, custom threshold
- ✅ Full TypeScript support
- ✅ Respects `--update-snapshots` flag

## Installation

```bash
npm install playwright-odiff odiff-bin
```

## Setup

Add the matcher to your Playwright config or test setup file:

### Option 1: Global Setup (playwright.config.ts)

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { expect } from '@playwright/test';
import { toHaveScreenshotOdiff } from 'playwright-odiff';

// Extend expect with custom matcher
expect.extend({ toHaveScreenshotOdiff });

export default defineConfig({
  // ... your config
});
```

### Option 2: Test Setup File

```typescript
// test-setup.ts
import { expect } from '@playwright/test';
import { toHaveScreenshotOdiff } from 'playwright-odiff';

expect.extend({ toHaveScreenshotOdiff });
```

Then in your `playwright.config.ts`:

```typescript
export default defineConfig({
  setupFiles: ['./test-setup.ts'],
  // ... your config
});
```

## Usage

### Basic Usage

```typescript
import { test, expect } from '@playwright/test';

test('screenshot comparison', async ({ page }) => {
  await page.goto('https://example.com');

  // Compare full page screenshot
  await expect(page).toHaveScreenshotOdiff('landing-page.png');

  // Compare locator screenshot
  await expect(page.locator('.hero')).toHaveScreenshotOdiff('hero.png');
});
```

### With Options

```typescript
test('screenshot with options', async ({ page }) => {
  await page.goto('https://example.com');

  await expect(page).toHaveScreenshotOdiff('landing.png', {
    // Odiff options
    threshold: 0.1,           // Color difference threshold (0-1)
    antialiasing: true,       // Ignore antialiased pixels
    maxDiffPixels: 100,       // Allow up to 100 different pixels
    maxDiffPixelRatio: 0.01,  // Or 1% of total pixels
    diffColor: '#ff0000',     // Custom diff color

    // Playwright screenshot options
    fullPage: true,
    mask: [page.locator('.dynamic-content')],
    animations: 'disabled',
    timeout: 30000,
  });
});
```

### Using Path Segments

```typescript
test('organized snapshots', async ({ page }) => {
  await page.goto('https://example.com');

  // Snapshots will be saved as:
  // __screenshots__/homepage/header.png
  // __screenshots__/homepage/footer.png
  await expect(page.locator('header')).toHaveScreenshotOdiff(['homepage', 'header.png']);
  await expect(page.locator('footer')).toHaveScreenshotOdiff(['homepage', 'footer.png']);
});
```

### Ignore Regions

```typescript
test('ignore dynamic regions', async ({ page }) => {
  await page.goto('https://example.com');

  await expect(page).toHaveScreenshotOdiff('page.png', {
    ignoreRegions: [
      { x1: 0, y1: 0, x2: 100, y2: 50 },    // Ignore top-left corner
      { x1: 200, y1: 300, x2: 400, y2: 400 }, // Ignore specific region
    ],
  });
});
```

### Update Snapshots

Just like Playwright's built-in matcher, use the `--update-snapshots` flag:

```bash
# Update all snapshots
npx playwright test --update-snapshots

# Update only missing snapshots
npx playwright test --update-snapshots=missing

# Don't update (default)
npx playwright test
```

## API

### toHaveScreenshotOdiff(name?, options?)

Compare a screenshot using odiff.

#### Parameters

- `name` (optional): `string | string[]` - Snapshot name or path segments
- `options` (optional): `OdiffScreenshotOptions` - Configuration options

#### OdiffScreenshotOptions

**Odiff-specific options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `threshold` | `number` | `0.1` | Color difference threshold (0-1). Lower is more strict |
| `antialiasing` | `boolean` | `true` | Ignore antialiased pixels in comparison |
| `maxDiffPixels` | `number` | `0` | Maximum number of different pixels allowed |
| `maxDiffPixelRatio` | `number` | `undefined` | Maximum ratio of different pixels (0-1) |
| `diffColor` | `string` | `undefined` | Hex color for highlighting differences (e.g. '#ff0000') |
| `ignoreRegions` | `Array<{x1, y1, x2, y2}>` | `undefined` | Regions to ignore in comparison |

**Playwright screenshot options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `clip` | `{x, y, width, height}` | `undefined` | Clip area to screenshot |
| `fullPage` | `boolean` | `false` | Take full page screenshot |
| `mask` | `Locator[]` | `undefined` | Locators to mask before screenshot |
| `maskColor` | `string` | `'pink'` | Color for masked areas |
| `omitBackground` | `boolean` | `false` | Hide default white background |
| `timeout` | `number` | `30000` | Screenshot timeout in ms |
| `animations` | `'disabled' \| 'allow'` | `'disabled'` | CSS animations control |
| `caret` | `'hide' \| 'initial'` | `'hide'` | Caret visibility |
| `scale` | `'css' \| 'device'` | `'css'` | Screenshot scale mode |
| `stylePath` | `string \| string[]` | `undefined` | CSS stylesheets to apply |

## Snapshot Location

Snapshots are stored in `__screenshots__` directory next to your test file, following Playwright's convention:

```
tests/
├── example.spec.ts
└── __screenshots__/
    ├── landing-page.png
    ├── hero.png
    └── homepage/
        ├── header.png
        └── footer.png
```

Test output artifacts (actual, diff) are stored in `test-results/` directory.

## Comparison with Playwright's toHaveScreenshot()

| Feature | `toHaveScreenshot()` | `toHaveScreenshotOdiff()` |
|---------|---------------------|--------------------------|
| Speed | Baseline (pixelmatch) | **6x faster** |
| API | ✅ Standard | ✅ Same API |
| File structure | ✅ Standard | ✅ Same structure |
| Update snapshots | ✅ Supported | ✅ Supported |
| TypeScript | ✅ Full support | ✅ Full support |
| Antialiasing | ❌ Basic | ✅ Advanced detection |
| Ignore regions | ❌ No | ✅ Yes |
| Cross-format | ❌ PNG only | ✅ PNG, JPEG, WebP |

## Performance

odiff is significantly faster than other image comparison tools:

```
Full page screenshot comparison (1920x1080):
  odiff:       ~170ms
  pixelmatch:  ~1200ms  (6x slower)
  ImageMagick: ~1100ms  (6x slower)
```

For 25,000 screenshots per month, using odiff saves **~7 hours** of CI time!

## License

MIT
