export type ODiffOptions = {
  /** Color used to highlight different pixels in the output (in hex format e.g. #cd2cc9). */
  diffColor: boolean;
  /** Output full diff image. */
  outputDiffMask: boolean;
  /** Do not compare images and produce output if images layout is different. */
  failOnLayoutDiff: boolean;
  /** Color difference threshold (from 0 to 1). Less more precise. */
  threshold: number;
};

declare function compare(
  basePath: string,
  comparePath: string,
  diffPath: string,
  options?: ODiffOptions
): Promise<
  { match: true } | { match: false; reason: "layout-diff" | "pixel-diff" }
>;

export { compare };
