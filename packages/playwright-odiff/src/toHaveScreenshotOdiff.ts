import fs from "fs/promises";
import path from "path";
import type { Page, Locator, TestInfo } from "@playwright/test";
import { compare } from "odiff-bin";
import type { OdiffScreenshotOptions, MatcherResult } from "./types";
import { test } from "@playwright/test";
import { SnapshotHelper } from "./snapshotHelper";

// Helper to get test info from Playwright's test context
function currentTestInfo(): TestInfo | undefined {
  return (test as any).info?.();
}

type NameOrSegments = string | string[];

interface ExpectMatcherContext {
  isNot: boolean;
  utils: any;
}

// Removes file and ignores errors
async function removeSafely(filePath: string) {
  await fs.unlink(filePath).catch(() => {});
}

// Main matcher implementation
export async function toHaveScreenshotOdiff(
  this: ExpectMatcherContext,
  pageOrLocator: Page | Locator,
  nameOrOptions:
    | NameOrSegments
    | ({ name?: NameOrSegments } & OdiffScreenshotOptions) = {},
  optOptions: OdiffScreenshotOptions = {},
): Promise<MatcherResult> {
  const testInfo = currentTestInfo();
  if (!testInfo) {
    throw new Error(`toHaveScreenshotOdiff() must be called during the test`);
  }

  // Determine if we're working with a Page or Locator
  const isPage = "goto" in pageOrLocator;
  const page = isPage
    ? (pageOrLocator as Page)
    : (pageOrLocator as Locator).page();
  const locator = isPage ? undefined : (pageOrLocator as Locator);

  const helper = new SnapshotHelper(
    testInfo,
    "toHaveScreenshotOdiff",
    nameOrOptions,
    optOptions,
  );

  const styles = await loadScreenshotStyles(helper.options.stylePath);
  if (styles) {
    await page.addStyleTag({ content: styles });
  }

  const hasSnapshot = await fs.stat(helper.expectedPath).catch(() => false);

  // Build screenshot options
  const screenshotOptions: any = {
    timeout: helper.options.timeout || 30000,
    animations: helper.options.animations || "disabled",
    caret: helper.options.caret || "hide",
    scale: helper.options.scale || "css",
  };

  if (helper.options.clip) screenshotOptions.clip = helper.options.clip;
  if (helper.options.fullPage)
    screenshotOptions.fullPage = helper.options.fullPage;
  if (helper.options.omitBackground)
    screenshotOptions.omitBackground = helper.options.omitBackground;
  if (helper.options.mask) screenshotOptions.mask = helper.options.mask;
  if (helper.options.maskColor)
    screenshotOptions.maskColor = helper.options.maskColor;

  // Handle missing snapshot - need to take screenshot first
  if (!hasSnapshot) {
    const actualScreenshot = (await (locator
      ? locator.screenshot(screenshotOptions)
      : page.screenshot(screenshotOptions))) as Buffer;

    if (helper.updateSnapshots === "none") {
      return helper.createMatcherResult(
        `A snapshot doesn't exist at ${helper.expectedPath}.`,
        false,
      );
    }
    return helper.handleMissing(actualScreenshot);
  }

  // Handle update all mode - take screenshot and update
  if (helper.updateSnapshots === "all") {
    const actualScreenshot = (await (locator
      ? locator.screenshot(screenshotOptions)
      : page.screenshot(screenshotOptions))) as Buffer;

    helper.writeFileSync(helper.expectedPath, actualScreenshot);
    helper.writeFileSync(helper.actualPath, actualScreenshot);
    console.log(helper.expectedPath + " is re-generated, writing actual.");
    return helper.createMatcherResult(
      helper.expectedPath + " running with --update-snapshots, writing actual.",
      true,
    );
  }

  await fs.mkdir(path.dirname(helper.actualPath), { recursive: true });
  screenshotOptions.path = helper.actualPath;

  await (locator
    ? locator.screenshot(screenshotOptions)
    : page.screenshot(screenshotOptions));

  // Compare using odiff - pass file paths directly
  const odiffOptions: any = {
    threshold: helper.options.threshold ?? 0.1,
    antialiasing: helper.options.antialiasing ?? true,
  };

  if (helper.options.diffColor) {
    odiffOptions.diffColor = helper.options.diffColor;
  }
  if (helper.options.ignoreRegions) {
    odiffOptions.ignoreRegions = helper.options.ignoreRegions;
  }

  const result = await compare(
    helper.expectedPath,
    helper.actualPath,
    helper.diffPath,
    odiffOptions,
  );

  if (result.match) {
    await removeSafely(helper.actualPath);
    return helper.handleMatching();
  }

  if (result.reason === "pixel-diff") {
    const { diffCount, diffPercentage } = result;
    const maxDiffPixels = helper.options.maxDiffPixels ?? 0;
    const maxDiffPixelRatio = helper.options.maxDiffPixelRatio;

    let isWithinTolerance = diffCount <= maxDiffPixels;
    if (maxDiffPixelRatio !== undefined) {
      isWithinTolerance =
        isWithinTolerance || diffPercentage / 100 <= maxDiffPixelRatio;
    }

    if (isWithinTolerance) {
      await fs.unlink(helper.actualPath).catch(() => {});
      await fs.unlink(helper.diffPath).catch(() => {});

      return helper.handleMatching();
    }

    const errorMessage = `${diffCount} pixels (${diffPercentage.toFixed(2)}% of all pixels) are different.`;

    // Handle update changed mode
    if (helper.updateSnapshots === "changed") {
      await fs.copyFile(helper.actualPath, helper.expectedPath);
      console.log(helper.expectedPath + " does not match, writing actual.");
      return helper.createMatcherResult(
        helper.expectedPath +
          " running with --update-snapshots, writing actual.",
        true,
      );
    }

    return helper.handleDifferent(true, errorMessage);
  }

  return helper.handleDifferent(
    false,
    "Received screesnhot with differnt dimensions",
  );
}

async function loadScreenshotStyles(
  stylePath?: string | string[],
): Promise<string | undefined> {
  if (!stylePath) return undefined;

  const stylePaths = Array.isArray(stylePath) ? stylePath : [stylePath];
  const styles = await Promise.all(
    stylePaths.map(async (p) => {
      const text = await fs.readFile(p, "utf8");
      return text.trim();
    }),
  );
  return styles.join("\n").trim() || undefined;
}
