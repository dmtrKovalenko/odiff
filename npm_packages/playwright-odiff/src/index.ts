import type { ODiffScreenshotOptions } from "./types";

export { toHaveScreenshotOdiff } from "./toHaveScreenshotOdiff";
export type { ODiffScreenshotOptions as OdiffScreenshotOptions };

// Type augmentation for Playwright's expect
declare global {
  namespace PlaywrightTest {
    interface Matchers<R, T> {
      /**
       * Compare page or locator screenshot using odiff.
       *
       * @param name Optional snapshot name or path segments
       * @param options Odiff screenshot options
       */
      toHaveScreenshotOdiff(
        name?: string | string[],
        options?: ODiffScreenshotOptions,
      ): Promise<R>;

      /**
       * Compare page or locator screenshot using odiff.
       *
       * @param options Odiff screenshot options including name
       */
      toHaveScreenshotOdiff(
        options?: { name?: string | string[] } & ODiffScreenshotOptions,
      ): Promise<R>;
    }
  }
}
