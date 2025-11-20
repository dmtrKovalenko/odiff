import fs from "fs/promises";
import fssync from "fs";
import path from "path";
import type { Page, Locator, TestInfo } from "@playwright/test";
import type { ODiffScreenshotOptions, MatcherResult } from "./types";
import { test } from "@playwright/test";
import { SnapshotHelper } from "./snapshotHelper";
import { ODiffServer } from "odiff-bin";

type ODiffServerType = InstanceType<typeof ODiffServer>;

let GLOBAL_ODIFF_SERVER: ODiffServerType | null = null;
function getODiffServer(): ODiffServerType {
  if (!GLOBAL_ODIFF_SERVER) {
    // Create server (it will initialize automatically on first compare)
    GLOBAL_ODIFF_SERVER = new ODiffServer();
  }
  return GLOBAL_ODIFF_SERVER;
}

// Cleanup server on process exit
if (typeof process !== "undefined") {
  process.on("exit", () => {
    if (GLOBAL_ODIFF_SERVER) {
      GLOBAL_ODIFF_SERVER.stop();
    }
  });

  process.on("SIGINT", () => {
    if (GLOBAL_ODIFF_SERVER) {
      GLOBAL_ODIFF_SERVER.stop();
    }
    process.exit();
  });
}

// Helper to get test info from Playwright's test context
function currentTestInfo(): TestInfo | undefined {
  return (test as any).info?.();
}

type NameOrSegments = string | string[];

interface ExpectMatcherContext {
  isNot: boolean;
  utils: any;
  timeout: number;
  _stepInfo?: any;
}

interface ScreenshotStabilizationResult {
  hasActual: boolean;
  hasPrevious: boolean;
  hasDiff: boolean;
  errorMessage?: string;
  log?: string[];
  timedOut?: boolean;
}

// Double requestAnimationFrame to ensure visual updates complete
async function rafrafScreenshot(
  page: Page,
  locator: Locator | undefined,
  path: string,
  options: any,
  delay: number,
): Promise<void> {
  if (delay > 0) {
    await new Promise((resolve) => setTimeout(resolve, delay));
  }

  // Double RAF to ensure pending visual updates complete
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        // @ts-ignore - requestAnimationFrame is available in browser context
        requestAnimationFrame(() => {
          // @ts-ignore - requestAnimationFrame is available in browser context
          requestAnimationFrame(() => resolve());
        });
      }),
  );

  const optionsWithPath = { ...options, path };
  if (locator) {
    await locator.screenshot(optionsWithPath);
  } else {
    await page.screenshot(optionsWithPath);
  }
}

// Screenshot stabilization with retry logic matching Playwright's behavior
// OPTIMIZED VERSION
async function expectScreenshotWithRetry(
  page: Page,
  locator: Locator | undefined,
  screenshotOptions: any,
  helper: SnapshotHelper,
  expectedPath: string | undefined,
  timeout: number,
): Promise<ScreenshotStabilizationResult> {
  const pollIntervals = [0, 100, 250, 500];
  const startTime = Date.now();
  const deadline = startTime + timeout;

  let hasActual = false;
  let hasPrevious = false;
  let timedOut = false;
  const log: string[] = [];

  // our implemeantion writes directly to the test results without any tep files juggling
  const actualPath = helper.actualPath;
  const previousPath = helper.previousPath;
  const diffPath = helper.diffPath;

  // Ensure output directory exists
  await fs.mkdir(path.dirname(helper.actualPath), { recursive: true });

  while (true) {
    const remainingTime = deadline - Date.now();
    if (remainingTime <= 0) {
      timedOut = true;
      break;
    }

    const pollInterval = pollIntervals.shift() ?? 1000;
    const screenshotTimeout = Math.min(pollInterval, remainingTime);

    // Move current actual to previous
    if (hasActual) {
      await fs.rename(actualPath, previousPath).catch(() => {});
      hasPrevious = true;
    }

    try {
      await rafrafScreenshot(
        page,
        locator,
        actualPath,
        {
          ...screenshotOptions,
          timeout: Math.max(remainingTime, 1000),
        },
        screenshotTimeout,
      );
      hasActual = true;
    } catch (error: any) {
      log.push(`Failed to take screesnhot ${error.message}`);
      return {
        log,
        hasActual,
        hasPrevious,
        hasDiff: fssync.existsSync(helper.diffPath),
        errorMessage: `Failed to take screenshot: ${error.message}`,
        timedOut,
      };
    }

    // If we have an expected screenshot, compare against it
    if (expectedPath) {
      const server = getODiffServer();
      const result = await server.compare(
        expectedPath,
        actualPath,
        diffPath,
        helper.options,
      );

      if (!result.match) {
        // Check tolerance
        const maxDiffPixels = helper.options.maxDiffPixels ?? 0;
        const maxDiffPixelRatio = helper.options.maxDiffPixelRatio;

        let isWithinTolerance = false;
        if (result.reason === "pixel-diff") {
          const { diffCount, diffPercentage } = result;
          isWithinTolerance = diffCount <= maxDiffPixels;
          if (maxDiffPixelRatio !== undefined) {
            isWithinTolerance =
              isWithinTolerance || diffPercentage / 100 <= maxDiffPixelRatio;
          }
        }

        if (isWithinTolerance) {
          return {
            log,
            hasActual: true,
            hasPrevious,
            hasDiff: false,
            timedOut: false,
          };
        }

        if (result.reason === "pixel-diff") {
          const { diffCount, diffPercentage } = result;
          log.push(
            `${diffCount} pixels (${diffPercentage.toFixed(2)}% of all pixels) are different.`,
          );
        } else {
          log.push(`Screenshots have different dimensions`);
        }
      } else {
        return {
          hasActual: true,
          hasDiff: false,
          hasPrevious,
          log,
          timedOut: false,
        };
      }
    } else {
      // This only can happen when the baseline does not exists which is a rare path
      // so we don't need to hard optimize it before we actually finished
      if (hasPrevious) {
        const server = getODiffServer();
        const result = await server.compare(
          previousPath,
          actualPath,
          diffPath,
          helper.options,
        );
        if (result.match === true) {
          return {
            hasActual: true,
            hasPrevious: true,
            hasDiff: false,
            log,
            timedOut: false,
          };
        }
      }

      log.push(`Screenshot is still changing...`);
    }
  }

  // Timeout reached
  let errorMessage: string;
  if (expectedPath) {
    if (log.length > 0) {
      errorMessage = log[log.length - 1];
    } else {
      errorMessage = "Screenshots don't match";
    }
  } else {
    errorMessage =
      "Failed to generate stable screenshot - content is still changing";
  }

  return {
    hasActual,
    hasPrevious,
    hasDiff: fssync.existsSync(diffPath),
    errorMessage,
    log,
    timedOut: true,
  };
}

// Main matcher implementation (unchanged)
export async function toHaveScreenshotOdiff(
  this: ExpectMatcherContext,
  pageOrLocator: Page | Locator,
  nameOrOptions:
    | NameOrSegments
    | ({ name?: NameOrSegments } & ODiffScreenshotOptions) = {},
  optOptions: ODiffScreenshotOptions = {},
): Promise<MatcherResult> {
  const testInfo = currentTestInfo();
  if (!testInfo) {
    throw new Error(`toHaveScreenshotOdiff() must be called during the test`);
  }

  // Check if received is a Promise (common mistake)
  if (pageOrLocator instanceof Promise) {
    throw new Error(
      "An unresolved Promise was passed to toHaveScreenshotOdiff(), make sure to resolve it by adding await to it.",
    );
  }

  // Check ignoreSnapshots flag
  if ((testInfo as any)._projectInternal?.ignoreSnapshots) {
    return {
      pass: !this.isNot,
      message: () => "",
      name: "toHaveScreenshotOdiff",
    };
  }

  // Determine if we're working with a Page or Locator
  const isPage = pageOrLocator.constructor.name === "Page";
  const page = isPage
    ? (pageOrLocator as Page)
    : (pageOrLocator as Locator).page();
  const locator = isPage ? undefined : (pageOrLocator as Locator);

  const configOptions =
    (testInfo as any)._projectInternal?.expect?.toHaveScreenshot || {};
  const helper = new SnapshotHelper(
    testInfo,
    "toHaveScreenshotOdiff",
    locator,
    configOptions,
    nameOrOptions,
    optOptions,
  );

  // Validate .png extension
  if (!helper.expectedPath.toLowerCase().endsWith(".png")) {
    throw new Error(
      `Screenshot name "${path.basename(helper.expectedPath)}" must have '.png' extension`,
    );
  }

  const styles = await loadScreenshotStyles(helper.options.stylePath);
  if (styles) {
    await page.addStyleTag({ content: styles });
  }

  const timeout = helper.options.timeout ?? this.timeout;

  // Build screenshot options
  const screenshotOptions: any = {
    animations: helper.options.animations ?? "disabled",
    caret: helper.options.caret ?? "hide",
    scale: helper.options.scale ?? "css",
    clip: helper.options.clip,
    fullPage: helper.options.fullPage,
    mask: helper.options.mask,
    maskColor: helper.options.maskColor,
    omitBackground: helper.options.omitBackground,
  };

  const hasSnapshot = await fs
    .access(helper.expectedPath)
    .then(() => true)
    .catch(() => false);

  // Handle negated matcher (.not)
  if (this.isNot) {
    if (!hasSnapshot) {
      return helper.handleMissingNegated();
    }

    const result = await expectScreenshotWithRetry(
      page,
      locator,
      screenshotOptions,
      helper,
      helper.expectedPath,
      timeout,
    );

    const isDifferent = !!result.errorMessage;
    return isDifferent
      ? helper.handleDifferentNegated()
      : helper.handleMatchingNegated();
  }

  // Fast path: there's no snapshot and we don't intend to update it
  if (helper.updateSnapshots === "none" && !hasSnapshot) {
    return helper.createMatcherResult(
      `A snapshot doesn't exist at ${helper.expectedPath}.`,
      false,
    );
  }

  // Missing snapshot - generate a new one
  if (!hasSnapshot) {
    const result = await expectScreenshotWithRetry(
      page,
      locator,
      screenshotOptions,
      helper,
      undefined,
      timeout,
    );

    // We tried re-generating new snapshot but failed
    // This can be due to e.g. spinning animation, so we want to show it as a diff
    if (result.errorMessage) {
      const header = `Screenshot comparison failed (timeout: ${timeout}ms):\n`;
      return helper.handleDifferent(
        result.hasActual,
        false, // no snapshot
        result.hasPrevious,
        result.hasDiff,
        header,
        result.errorMessage,
        result.log,
        this._stepInfo,
      );
    }

    // We successfully generated new screenshot - read only for handleMissing
    const actual = await fs.readFile(helper.actualPath);
    return helper.handleMissing(actual, this._stepInfo);
  }

  // General case: snapshot exists, regular matcher (not .not)
  const expectedPathIfComparing =
    helper.updateSnapshots === "all" ? undefined : helper.expectedPath;

  const result = await expectScreenshotWithRetry(
    page,
    locator,
    screenshotOptions,
    helper,
    expectedPathIfComparing,
    timeout,
  );

  if (!result.errorMessage) {
    // Screenshot matches
    if (helper.updateSnapshots === "all" && result.hasActual) {
      // Copy actual to expected (no read/write, just kernel copy)
      await fs.copyFile(helper.actualPath, helper.expectedPath);
      console.log(helper.expectedPath + " is re-generated, writing actual.");
      return helper.createMatcherResult(
        helper.expectedPath +
          " running with --update-snapshots, writing actual.",
        true,
      );
    }
    return helper.handleMatching();
  }

  if (
    helper.updateSnapshots === "changed" ||
    helper.updateSnapshots === "all"
  ) {
    if (result.hasActual) {
      // Copy actual to expected (no read/write, just kernel copy)
      await fs.copyFile(helper.actualPath, helper.expectedPath);
      console.log(helper.expectedPath + " is re-generated, writing actual.");
      return helper.createMatcherResult(
        helper.expectedPath +
          " running with --update-snapshots, writing actual.",
        true,
      );
    }

    let header = `Screenshot comparison failed (timeout: ${timeout}ms):\n`;
    header += "  Failed to re-generate expected.\n";
    return helper.handleDifferent(
      result.hasActual,
      !!expectedPathIfComparing,
      result.hasPrevious,
      result.hasDiff,
      header,
      result.errorMessage,
      result.log,
      this._stepInfo,
    );
  }

  const header = `Screenshot comparison failed (timeout: ${timeout}ms):\n`;
  return helper.handleDifferent(
    result.hasActual,
    !!expectedPathIfComparing,
    result.hasPrevious,
    result.hasDiff,
    header,
    result.errorMessage,
    result.log,
    this._stepInfo,
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
