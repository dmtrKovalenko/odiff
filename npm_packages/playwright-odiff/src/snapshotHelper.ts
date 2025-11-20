/***
 * This files is stolen from playwright to be compatible with their snapshot paths resolution logic
 * With a few additional improvements to support async IO
 *
 * IMPORTANT NOTE FOR: when upgrading this makes sure to use the EXACT logic from playwrigth but preserve async IO
 * https://github.com/dmtrKovalenko/playwright/blob/main/packages/playwright/src/matchers/toMatchSnapshot.ts#L69-L69
 ***/
import fs from "fs";
import path from "path";
import type { TestInfo, Locator } from "@playwright/test";
import type { ODiffScreenshotOptions, MatcherResult } from "./types";
import { ODiffOptions } from "odiff-bin";

type NameOrSegments = string | string[];

function addSuffixToFilePath(filePath: string, suffix: string): string {
  const ext = path.extname(filePath);
  const base = filePath.slice(0, -ext.length);
  return base + suffix + ext;
}

// Non-config properties that should not be inherited from project config
const NonConfigProperties: (keyof ODiffScreenshotOptions)[] = [
  "clip",
  "fullPage",
  "mask",
  "maskColor",
  "omitBackground",
  "timeout",
];

const DEFAULT_ODIFF_OPTIONS: ODiffOptions = {
  failOnLayoutDiff: true,
  noFailOnFsErrors: true,
};

export class SnapshotHelper {
  readonly expectedPath: string;
  readonly legacyExpectedPath: string;
  readonly previousPath: string;
  readonly actualPath: string;
  readonly diffPath: string;
  readonly updateSnapshots: "all" | "missing" | "none" | "changed";
  readonly matcherName: string;
  readonly testInfo: TestInfo;
  readonly options: ODiffScreenshotOptions;
  readonly attachmentBaseName: string;
  readonly locator: Locator | undefined;
  readonly mimeType: string;
  readonly name: string;

  constructor(
    testInfo: TestInfo,
    matcherName: string,
    locator: Locator | undefined,
    configOptions: ODiffScreenshotOptions,
    nameOrOptions:
      | NameOrSegments
      | ({ name?: NameOrSegments } & ODiffScreenshotOptions),
    optOptions: ODiffScreenshotOptions,
  ) {
    this.testInfo = testInfo;
    this.matcherName = matcherName;
    this.locator = locator;

    let name: NameOrSegments | undefined;
    if (Array.isArray(nameOrOptions) || typeof nameOrOptions === "string") {
      name = nameOrOptions;
      this.options = { ...DEFAULT_ODIFF_OPTIONS, ...optOptions };
    } else {
      const { name: nameFromOptions, ...options } = nameOrOptions || {};
      this.options = { ...DEFAULT_ODIFF_OPTIONS, ...options };
      name = nameFromOptions;
    }

    this.name = Array.isArray(name) ? name.join(path.sep) : name || "";

    // Use Playwright's internal path resolution API
    const resolvedPaths = (testInfo as any)._resolveSnapshotPaths(
      "screenshot",
      name,
      "updateSnapshotIndex",
      undefined,
    );

    this.expectedPath = resolvedPaths.absoluteSnapshotPath;
    this.attachmentBaseName = resolvedPaths.relativeOutputPath;

    const outputBasePath = (testInfo as any)._getOutputPath(
      resolvedPaths.relativeOutputPath,
    );
    this.legacyExpectedPath = addSuffixToFilePath(outputBasePath, "-expected");
    this.previousPath = addSuffixToFilePath(outputBasePath, "-previous");
    this.actualPath = addSuffixToFilePath(outputBasePath, "-actual");
    this.diffPath = addSuffixToFilePath(outputBasePath, "-diff");

    // Filter out non-config properties from config options
    const filteredConfigOptions = { ...configOptions };
    for (const prop of NonConfigProperties) {
      delete (filteredConfigOptions as any)[prop];
    }

    // Merge config options with test options
    this.options = {
      ...filteredConfigOptions,
      ...this.options,
    };

    // Validate options
    if (
      this.options.maxDiffPixels !== undefined &&
      this.options.maxDiffPixels < 0
    ) {
      throw new Error(
        "`maxDiffPixels` option value must be non-negative integer",
      );
    }

    if (
      this.options.maxDiffPixelRatio !== undefined &&
      (this.options.maxDiffPixelRatio < 0 || this.options.maxDiffPixelRatio > 1)
    ) {
      throw new Error(
        "`maxDiffPixelRatio` option value must be between 0 and 1",
      );
    }

    this.updateSnapshots = testInfo.config.updateSnapshots;
    this.mimeType = "image/png";
  }

  createMatcherResult(
    message: string,
    pass: boolean,
    log?: string[],
  ): MatcherResult {
    const unfiltered: MatcherResult = {
      pass,
      message: () => message,
      name: this.matcherName,
      expected: this.expectedPath,
      actual: this.actualPath,
      diff: this.diffPath,
      log,
    };
    return Object.fromEntries(
      Object.entries(unfiltered).filter(([_, v]) => v !== undefined),
    ) as MatcherResult;
  }

  handleMissingNegated(): MatcherResult {
    const isWriteMissingMode = this.updateSnapshots !== "none";
    const message = `A snapshot doesn't exist at ${this.expectedPath}${isWriteMissingMode ? ', matchers using ".not" won\'t write them automatically.' : "."}`;
    // NOTE: 'isNot' matcher implies inversed value.
    return this.createMatcherResult(message, true);
  }

  handleDifferentNegated(): MatcherResult {
    // NOTE: 'isNot' matcher implies inversed value.
    return this.createMatcherResult("", false);
  }

  handleMatchingNegated(): MatcherResult {
    const message = [
      "Screenshot comparison failed:",
      "",
      "  Expected result should be different from the actual one.",
    ].join("\n");
    // NOTE: 'isNot' matcher implies inversed value.
    return this.createMatcherResult(message, true);
  }

  handleMissing(actual: Buffer, step: any | undefined): MatcherResult {
    const isWriteMissingMode = this.updateSnapshots !== "none";

    if (isWriteMissingMode) {
      this.writeFileSync(this.expectedPath, actual);
    }

    step?._attachToStep({
      name: addSuffixToFilePath(this.attachmentBaseName, "-expected"),
      contentType: this.mimeType,
      path: this.expectedPath,
    });

    // actualPath already written by screenshot() - just attach it
    step?._attachToStep({
      name: addSuffixToFilePath(this.attachmentBaseName, "-actual"),
      contentType: this.mimeType,
      path: this.actualPath,
    });

    const message = `A snapshot doesn't exist at ${this.expectedPath}${isWriteMissingMode ? ", writing actual." : "."}`;

    if (this.updateSnapshots === "all" || this.updateSnapshots === "changed") {
      console.log(message);
      return this.createMatcherResult(message, true);
    }

    if (this.updateSnapshots === "missing") {
      (this.testInfo as any)._hasNonRetriableError = true;
      (this.testInfo as any)._failWithError(new Error(message));
      return this.createMatcherResult("", true);
    }

    return this.createMatcherResult(message, false);
  }

  handleDifferent(
    hasActual: boolean,
    hasExpected: boolean,
    hasPrevious: boolean,
    hasDiff: boolean,
    header: string,
    diffError: string,
    log: string[] | undefined,
    step: any | undefined,
  ): MatcherResult {
    const output = [`${header}  ${diffError}`];

    if (this.name) {
      output.push("");
      output.push(`  Snapshot: ${this.name}`);
    }

    // Files already exist at paths, just attach them
    if (hasExpected && fs.existsSync(this.expectedPath)) {
      // Copy the expectation inside the test-results folder for backwards compatibility (kernel copy, no Buffer)
      fs.copyFileSync(this.expectedPath, this.legacyExpectedPath);
      step?._attachToStep({
        name: addSuffixToFilePath(this.attachmentBaseName, "-expected"),
        contentType: this.mimeType,
        path: this.expectedPath,
      });
    }

    if (hasPrevious && fs.existsSync(this.previousPath)) {
      step?._attachToStep({
        name: addSuffixToFilePath(this.attachmentBaseName, "-previous"),
        contentType: this.mimeType,
        path: this.previousPath,
      });
    }

    if (hasActual && fs.existsSync(this.actualPath)) {
      step?._attachToStep({
        name: addSuffixToFilePath(this.attachmentBaseName, "-actual"),
        contentType: this.mimeType,
        path: this.actualPath,
      });
    }

    if (hasDiff && fs.existsSync(this.diffPath)) {
      step?._attachToStep({
        name: addSuffixToFilePath(this.attachmentBaseName, "-diff"),
        contentType: this.mimeType,
        path: this.diffPath,
      });
    }

    if (log?.length) {
      output.push("");
      output.push("Call log:");
      output.push(...log.map((l) => `  - ${l}`));
    }

    output.push("");

    return this.createMatcherResult(output.join("\n"), false, log);
  }

  handleMatching(): MatcherResult {
    return this.createMatcherResult("", true);
  }

  writeFileSync(filePath: string, content: Buffer) {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
  }
}
