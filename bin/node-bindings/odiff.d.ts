export type ODiffOptions = Partial<{
  /** Color used to highlight different pixels in the output (in hex format e.g. #cd2cc9). */
  diffColor: string;
  /** Output full diff image. */
  outputDiffMask: boolean;
  /** Do not compare images and produce output if images layout is different. */
  failOnLayoutDiff: boolean;
  /** Color difference threshold (from 0 to 1). Less more precise. */
  threshold: number;
  /** If this is true, antialiased pixels are not counted to the diff of an image */
  antialiasing: boolean;
  /** An array of regions to ignore in the diff. */
  ignoreRegions: Array<{
    x1: number,
    y1: number,
    x2: number,
    y2: number,
  }>;
}>;

declare function compare(
  basePath: string,
  comparePath: string,
  diffPath: string,
  options?: ODiffOptions
): Promise<
  | { match: true }
  | { match: false; reason: "layout-diff" }
  | {
      match: false;
      reason: "pixel-diff";
      /** Amount of different pixels */
      diffCount: number;
      /** Percentage of different pixels in the whole image */
      diffPercentage: number;
    }
>;

export { compare };
