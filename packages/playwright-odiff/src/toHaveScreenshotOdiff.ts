import fs from "fs";
import path from "path";
import type { Page, Locator, TestInfo } from "@playwright/test";
import { test } from "@playwright/test";
import { compare } from "odiff-bin";
import currentTestInfo from "playwright/test/common/globals";
import type { OdiffScreenshotOptions, MatcherResult } from "./types";

type NameOrSegments = string | string[];

interface ExpectMatcherContext {
  isNot: boolean;
  utils: any;
}

// Helper to add suffix to file path
function addSuffixToFilePath(filePath: string, suffix: string): string {
  const ext = path.extname(filePath);
  const base = filePath.slice(0, -ext.length);
  return base + suffix + ext;
}

// Helper class for snapshot path management
class SnapshotHelper {
  readonly expectedPath: string;
  readonly actualPath: string;
  readonly diffPath: string;
  readonly updateSnapshots: "all" | "missing" | "none" | "changed";
  readonly matcherName: string;
  readonly testInfo: TestInfo;
  readonly options: OdiffScreenshotOptions;
  readonly attachmentBaseName: string;

  constructor(
    testInfo: TestInfo,
    matcherName: string,
    nameOrOptions:
      | NameOrSegments
      | ({ name?: NameOrSegments } & OdiffScreenshotOptions),
    optOptions: OdiffScreenshotOptions,
  ) {
    this.testInfo = testInfo;
    this.matcherName = matcherName;

    let name: NameOrSegments | undefined;
    if (Array.isArray(nameOrOptions) || typeof nameOrOptions === "string") {
      name = nameOrOptions;
      this.options = { ...optOptions };
    } else {
      const { name: nameFromOptions, ...options } = nameOrOptions || {};
      this.options = options;
      name = nameFromOptions;
    }

    // Generate snapshot paths using Playwright's convention
    const snapshotName = Array.isArray(name) ? name.join(path.sep) : name || "";

    // Use Playwright's snapshot directory structure
    const testDir = path.dirname(testInfo.file);
    const testName = testInfo.titlePath.slice(1).join(" ");
    const snapshotDir = path.join(testDir, "__screenshots__");

    // Build expected path
    const fileName =
      snapshotName ||
      `${testName.replace(/[^a-z0-9]/gi, "-")}-${testInfo.testId}.png`;
    this.expectedPath = path.join(snapshotDir, fileName);

    // Build output paths
    const outputDir = testInfo.outputDir;
    const baseName = snapshotName || testName;
    this.attachmentBaseName = path.basename(this.expectedPath);
    this.actualPath = path.join(
      outputDir,
      addSuffixToFilePath(path.basename(this.expectedPath), "-actual"),
    );
    this.diffPath = path.join(
      outputDir,
      addSuffixToFilePath(path.basename(this.expectedPath), "-diff"),
    );

    this.updateSnapshots = (testInfo.config as any).updateSnapshots || "none";
  }

  createMatcherResult(
    message: string,
    pass: boolean,
    log?: string[],
  ): MatcherResult {
    return {
      pass,
      message: () => message,
      name: this.matcherName,
      expected: this.expectedPath,
      actual: this.actualPath,
      diff: this.diffPath,
      log,
    };
  }

  handleMissing(actual: Buffer): MatcherResult {
    const isWriteMissingMode = this.updateSnapshots !== "none";

    if (isWriteMissingMode) {
      this.writeFileSync(this.expectedPath, actual);
    }

    this.writeFileSync(this.actualPath, actual);

    const message = `A snapshot doesn't exist at ${this.expectedPath}${isWriteMissingMode ? ", writing actual." : "."}`;

    if (this.updateSnapshots === "all" || this.updateSnapshots === "missing") {
      console.log(message);
      return this.createMatcherResult(message, true);
    }

    return this.createMatcherResult(message, false);
  }

  handleDifferent(
    actual: Buffer,
    expected: Buffer,
    diffImage: Buffer | undefined,
    errorMessage: string,
  ): MatcherResult {
    // Write all comparison artifacts
    this.writeFileSync(this.actualPath, actual);

    if (diffImage) {
      this.writeFileSync(this.diffPath, diffImage);
    }

    const output = [
      `Screenshot comparison failed:`,
      ``,
      `  ${errorMessage}`,
      ``,
      `  Expected: ${this.expectedPath}`,
      `  Actual:   ${this.actualPath}`,
      diffImage ? `  Diff:     ${this.diffPath}` : "",
    ]
      .filter(Boolean)
      .join("\n");

    return this.createMatcherResult(output, false);
  }

  handleMatching(): MatcherResult {
    return this.createMatcherResult("", true);
  }

  writeFileSync(filePath: string, content: Buffer) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
  }
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

  // Create snapshot helper
  const helper = new SnapshotHelper(
    testInfo,
    "toHaveScreenshotOdiff",
    nameOrOptions,
    optOptions,
  );

  // Validate PNG extension
  if (!helper.expectedPath.toLowerCase().endsWith(".png")) {
    throw new Error(
      `Screenshot name "${path.basename(helper.expectedPath)}" must have '.png' extension`,
    );
  }

  // Load stylesheets if provided
  const styles = await loadScreenshotStyles(helper.options.stylePath);
  if (styles) {
    await page.addStyleTag({ content: styles });
  }

  // Take screenshot
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

  const actualScreenshot = (await (locator
    ? locator.screenshot(screenshotOptions)
    : page.screenshot(screenshotOptions))) as Buffer;

  // Check if expected snapshot exists
  const hasSnapshot = fs.existsSync(helper.expectedPath);

  // Handle missing snapshot
  if (!hasSnapshot) {
    if (helper.updateSnapshots === "none") {
      return helper.createMatcherResult(
        `A snapshot doesn't exist at ${helper.expectedPath}.`,
        false,
      );
    }
    return helper.handleMissing(actualScreenshot);
  }

  // Read expected snapshot
  const expectedScreenshot = fs.readFileSync(helper.expectedPath);

  // Handle update all mode
  if (helper.updateSnapshots === "all") {
    helper.writeFileSync(helper.expectedPath, actualScreenshot);
    helper.writeFileSync(helper.actualPath, actualScreenshot);
    console.log(helper.expectedPath + " is re-generated, writing actual.");
    return helper.createMatcherResult(
      helper.expectedPath + " running with --update-snapshots, writing actual.",
      true,
    );
  }

  // Write actual and expected to temp files for odiff comparison
  const tempActual = path.join(testInfo.outputDir, "temp-actual.png");
  const tempExpected = path.join(testInfo.outputDir, "temp-expected.png");
  const tempDiff = path.join(testInfo.outputDir, "temp-diff.png");

  helper.writeFileSync(tempActual, actualScreenshot);
  helper.writeFileSync(tempExpected, expectedScreenshot);

  // Compare using odiff - only include defined options
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

  try {
    const result = await compare(
      tempExpected,
      tempActual,
      tempDiff,
      odiffOptions,
    );

    // Clean up temp files
    fs.unlinkSync(tempActual);
    fs.unlinkSync(tempExpected);

    if (result.match) {
      // Images match
      if (fs.existsSync(tempDiff)) fs.unlinkSync(tempDiff);
      return helper.handleMatching();
    }

    // Images don't match
    let diffImage: Buffer | undefined;
    if (fs.existsSync(tempDiff)) {
      diffImage = fs.readFileSync(tempDiff);
      fs.unlinkSync(tempDiff);
    }

    // Check if difference is within tolerance
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
        return helper.handleMatching();
      }

      const errorMessage = `${diffCount} pixels (${diffPercentage.toFixed(2)}% of all pixels) are different.`;

      // Handle update changed mode
      if (helper.updateSnapshots === "changed") {
        helper.writeFileSync(helper.expectedPath, actualScreenshot);
        console.log(helper.expectedPath + " does not match, writing actual.");
        return helper.createMatcherResult(
          helper.expectedPath +
            " running with --update-snapshots, writing actual.",
          true,
        );
      }

      return helper.handleDifferent(
        actualScreenshot,
        expectedScreenshot,
        diffImage,
        errorMessage,
      );
    }

    // Layout difference
    const errorMessage = "Images have different dimensions";
    return helper.handleDifferent(
      actualScreenshot,
      expectedScreenshot,
      diffImage,
      errorMessage,
    );
  } catch (error) {
    // Clean up temp files on error
    if (fs.existsSync(tempActual)) fs.unlinkSync(tempActual);
    if (fs.existsSync(tempExpected)) fs.unlinkSync(tempExpected);
    if (fs.existsSync(tempDiff)) fs.unlinkSync(tempDiff);
    throw error;
  }
}

async function loadScreenshotStyles(
  stylePath?: string | string[],
): Promise<string | undefined> {
  if (!stylePath) return undefined;

  const stylePaths = Array.isArray(stylePath) ? stylePath : [stylePath];
  const styles = await Promise.all(
    stylePaths.map(async (p) => {
      const text = await fs.promises.readFile(p, "utf8");
      return text.trim();
    }),
  );
  return styles.join("\n").trim() || undefined;
}
