export type ODiffOptions = Partial<{
  /** Color used to highlight different pixels in the output (in hex format e.g. #cd2cc9). */
  diffColor: string;
  /** Output full diff image. */
  outputDiffMask: boolean;
  /** Outputs diff images with a white shaded overlay for easier diff reading */
  diffOverlay: boolean | number;
  /** Do not compare images and produce output if images layout is different. */
  failOnLayoutDiff: boolean;
  /** Return { match: false, reason: '...' } instead of throwing error if file is missing. */
  noFailOnFsErrors: boolean;
  /** Color difference threshold (from 0 to 1). Less more precise. */
  threshold: number;
  /** If this is true, antialiased pixels are not counted to the diff of an image */
  antialiasing: boolean;
  /** If `true` reason: "pixel-diff" output will contain the set of line indexes containing different pixels */
  captureDiffLines: boolean;
  /** If `true` odiff will use less memory but will be slower with larger images */
  reduceRamUsage: boolean;
  /** An array of regions to ignore in the diff. */
  ignoreRegions: Array<{
    x1: number;
    y1: number;
    x2: number;
    y2: number;
  }>;
}>;

export type ODiffResult =
  | { match: true }
  | { match: false; reason: "layout-diff" }
  | {
      match: false;
      reason: "pixel-diff";
      /** Amount of different pixels */
      diffCount: number;
      /** Percentage of different pixels in the whole image */
      diffPercentage: number;
      /** Individual line indexes containing different pixels. Guaranteed to be ordered and distinct.  */
      diffLines?: number[];
    }
  | {
      match: false;
      reason: "file-not-exists";
      /** Errored file path */
      file: string;
    };

declare function compare(
  basePath: string,
  comparePath: string,
  diffPath: string,
  options?: ODiffOptions,
): Promise<ODiffResult>;

/**
 * ODiffServer - Persistent server instance for multiple comparisons
 *
 * Use this when you need to perform multiple image comparisons to avoid
 * process spawn overhead. The server process stays alive and reuses resources.
 *
 * The server initializes automatically on first compare() call, so you can
 * create an instance and start using it immediately.
 *
 * @example
 * ```ts
 * const server = new ODiffServer();
 *
 * const result1 = await server.compare('a.png', 'b.png', 'diff1.png');
 * // add optional timeout to catch any possible crashes on the server side:
 * const result2 = await server.compare('c.png', 'd.png', 'diff2.png', { threshold: 0.3, timeout: 5000 });
 *
 * server.stop();
 * ```
 *
 * It is absolutely fine to keep odiff sever leaving in the module root
 * even if you have several independent workers, it will automatically spawn
 * a server process per each multiplexed core to work in parallel
 *
 * @example
 * ```typescript
 * const odiffServer = new ODiffServer();
 *
 * test('visual test 1', async () => {
 *   await odiffServer.compare('a.png', 'b.png', 'diff1.png');
 * });
 *
 * test('visual test 2', async () => {
 *   await odiffServer.compare('c.png', 'd.png', 'diff2.png');
 * });
 * ```
 */
export declare class ODiffServer {
  /**
   * Create a new ODiffServer instance
   * Server initialization begins immediately in the background
   * @param binaryPath - Optional path to odiff binary (defaults to bundled binary)
   */
  constructor(binaryPath?: string);

  /**
   * Compare two images using the persistent server
   * Automatically waits for server initialization if needed
   * @param basePath - Path to base image
   * @param comparePath - Path to comparison image
   * @param diffOutput - Path to output diff image
   * @param options - Comparison options with optional timeout for request
   * @returns Promise resolving to comparison result
   */
  compare(
    basePath: string,
    comparePath: string,
    diffOutput: string,
    options?: ODiffOptions & { timeout?: number },
  ): Promise<ODiffResult>;

  /**
   * Stop the odiff server process
   * Should be called when done with all comparisons
   * Safe to call even if server is not running
   */
  stop(): void;
}

export { compare, ODiffServer };
