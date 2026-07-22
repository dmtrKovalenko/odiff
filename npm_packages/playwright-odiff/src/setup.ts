import { expect } from "@playwright/test";
// this is done to keep esm & cjs compatibility at the same time, ts consumers importing types 
// but cjs consumers after build getting the index .js directly
import { toHaveScreenshotOdiff } from "./index.js";

expect.extend({
  toHaveScreenshotOdiff,
});

// re-export so setup.d.ts references index.d.ts (tsc would otherwise elide the
// import above), keeping the global Matchers augmentation for /setup consumers
export type { OdiffScreenshotOptions } from "./index.js";
