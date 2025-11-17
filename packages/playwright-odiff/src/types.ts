import type { Locator } from '@playwright/test';

export type OdiffScreenshotOptions = {
  /** Snapshot name. Can be a string or path segments */
  name?: string | string[];
  /** Color difference threshold (from 0 to 1). Less is more precise. Default: 0.1 */
  threshold?: number;
  /** If this is true, antialiased pixels are not counted to the diff of an image. Default: true */
  antialiasing?: boolean;
  /** Maximum number of different pixels allowed. Default: 0 */
  maxDiffPixels?: number;
  /** Maximum ratio of different pixels (0-1). Default: undefined */
  maxDiffPixelRatio?: number;
  /** Color used to highlight different pixels in the output (in hex format e.g. #cd2cc9) */
  diffColor?: string;
  /** An array of regions to ignore in the diff */
  ignoreRegions?: Array<{
    x1: number;
    y1: number;
    x2: number;
    y2: number;
  }>;

  // Screenshot options (same as Playwright's toHaveScreenshot)
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
  animations?: 'disabled' | 'allow';
  /** Caret visibility. Default: 'hide' */
  caret?: 'hide' | 'initial';
  /** Screenshot scale mode. Default: 'css' */
  scale?: 'css' | 'device';
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
