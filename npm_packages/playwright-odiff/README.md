# playwright-odiff

This is a drop-in replacement for `.toHaveScreenshot()` expect matcher that is a **way faster** than a built-in one (and when I am talking way faster I mean 8-10x on the average github actions CI machine) __and it is a way more reliable__.

## Drop-in

Yes, it's drop in replacement. Meaning that it is going to use the same screenshots you already done with Playwright, it will put the screenshots in the same folder as Playwright does and so on and so on.

## Installation

```
npm install playwright-odiff
```

Add this to the top-level setup script. The place where you configure your `test`, `extend`, or just any other common entrypoint to your Playwright tests:

```ts
import "playwright-odiff/setup"
```

Which is equivalent to 

```ts
import { expect } from "@playwright/test";
import { toHaveScreenshotOdiff } from "playwright-odiff/toHaveScreenshotOdiff";
import "playwright-odiff/types";

expect.extend({
  toHaveScreenshotOdiff,
});
```

At this point you are good to go and start using it everywhere and forget about it

```sh
# if you are on macos already install GNU sed: brew install gnu-sed
sed -i -E 's/(await expect\([^)]*\))(\.not)?\.toHaveScreenshot\(/\1\2.toHaveScreenshotOdiff(/g' ./**/*.spec.ts

```

## How does it work?

Similar to the Playwright matcher it runs a burst of screenshots that are ensuring that the content on a screen is stable but in addition to that the underlying algorithm for detecting anti-aliasing is way more stable than the `pixelmatch` that is used by Playwright and the threshold sensitivity is more correct (so you can safely get rid of your `maxDiffPixels` and `maxDiffPixelsRatio` even though we fully support them)
