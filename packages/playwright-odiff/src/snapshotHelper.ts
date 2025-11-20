/***
 * This files is stolen from playwright to be compatible with their snapshot paths resolution logic
 * With a few additional imporvements to support async IO
 *
 * IMPORTANT NOTE FOR: when upgrading this makes sure to use the EXACT logic from playwrigth but preserve async IO
 * https://github.com/dmtrKovalenko/playwright/blob/main/packages/playwright/src/matchers/toMatchSnapshot.ts#L69-L69
 ***/
import fs from "fs";
import path from "path";
import type { TestInfo } from "@playwright/test";
import type { OdiffScreenshotOptions, MatcherResult } from "./types";

type NameOrSegments = string | string[];

function addSuffixToFilePath(filePath: string, suffix: string): string {
  const ext = path.extname(filePath);
  const base = filePath.slice(0, -ext.length);
  return base + suffix + ext;
}

export class SnapshotHelper {
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

    // Generate snapshot paths using Playwright's exact convention
    const snapshotName = Array.isArray(name) ? name.join(path.sep) : name || "";

    // Use Playwright's snapshot directory structure: {test-file}-snapshots/
    const testFile = testInfo.file;
    const snapshotDir = testFile + "-snapshots";

    // Get project name (browser-platform format as Playwright does)
    const projectName = testInfo.project.name || "chromium";
    const platform =
      process.platform === "darwin"
        ? "darwin"
        : process.platform === "win32"
          ? "win32"
          : "linux";
    const projectSuffix = `-${projectName}-${platform}`;

    let fileName: string;
    if (snapshotName) {
      const baseName = snapshotName.replace(/\.png$/i, "");
      fileName = baseName + projectSuffix + ".png";
    } else {
      const fullTitle = testInfo.titlePath.slice(1).join(" ");
      const index = 1; // First anonymous snapshot
      const fullTitleWithIndex = `${fullTitle} ${index}`;
      // Sanitize the path
      const sanitized = fullTitleWithIndex
        .replace(/[^a-z0-9]+/gi, "-")
        .replace(/^-|-$/g, "");
      fileName = sanitized + projectSuffix + ".png";
    }

    this.expectedPath = path.join(snapshotDir, fileName);

    // Build output paths
    const outputDir = testInfo.outputDir;
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

  handleDifferent(hasDiff: boolean, errorMessage: string): MatcherResult {
    const output = [
      `Screenshot comparison failed:`,
      ``,
      `  ${errorMessage}`,
      ``,
      `  Expected: ${this.expectedPath}`,
      `  Actual:   ${this.actualPath}`,
      hasDiff ? `  Diff:     ${this.diffPath}` : "",
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
