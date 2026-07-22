import { expect } from "@playwright/test";
// Import via index.js so setup.d.ts pulls in the global Matchers augmentation
// declared there — consumers importing only "playwright-odiff/setup" get typings.
import { toHaveScreenshotOdiff } from "./index.js";

expect.extend({
  toHaveScreenshotOdiff,
});

// Re-export so setup.d.ts references index.d.ts (tsc would otherwise elide the
// import above), keeping the global Matchers augmentation for /setup consumers.
export type { OdiffScreenshotOptions } from "./index.js";
