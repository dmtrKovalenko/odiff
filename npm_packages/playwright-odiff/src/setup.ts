import { expect } from "@playwright/test";
import { toHaveScreenshotOdiff } from "./toHaveScreenshotOdiff.js";
import "./types.js";

expect.extend({
  toHaveScreenshotOdiff,
});
