import { expect } from "@playwright/test";
import { toHaveScreenshotOdiff } from "./toHaveScreenshotOdiff";
import "./types";

expect.extend({
  toHaveScreenshotOdiff,
});
