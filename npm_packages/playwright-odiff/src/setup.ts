import { expect } from "@playwright/test";
import { toHaveScreenshotOdiff } from "./toHaveScreenshotOdiff.js";
import "./types";

expect.extend({
  toHaveScreenshotOdiff,
});
