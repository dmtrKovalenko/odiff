import type { Locator } from "@playwright/test";
import type { ODiffOptions } from "odiff-bin";

export type OdiffScreenshotOptions = ODiffOptions & {
  /** Maximum number of different pixels allowed. Default: 0 */
  maxDiffPixels?: number;
  /** Maximum ratio of different pixels (0-1). Default: undefined */
  maxDiffPixelRatio?: number;
  /** Clip area to screenshot. Default: undefined */
  clip?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  /** Take fullPage screenshot. Default: false */
  fullPage?: boolean;
  /** Array of locators to mask before taking screenshot */
  mask?: Locator[];
  /** Color to use for masked areas. Default: 'pink' */
  maskColor?: string;
  /** Hides default white background. Default: false */
  omitBackground?: boolean;
  /** Screenshot timeout in milliseconds. Default: 30000 */
  timeout?: number;
  /** CSS animations control. Default: 'disabled' */
  animations?: "disabled" | "allow";
  /** Caret visibility. Default: 'hide' */
  caret?: "hide" | "initial";
  /** Screenshot scale mode. Default: 'css' */
  scale?: "css" | "device";
  /** CSS stylesheet paths to apply before screenshot */
  stylePath?: string | string[];
};

export type MatcherResult = {
  pass: boolean;
  message: () => string;
  name?: string;
  expected?: string;
  actual?: string;
  diff?: string;
  log?: string[];
};
