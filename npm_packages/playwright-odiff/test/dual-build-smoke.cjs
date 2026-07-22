// make sure that both import and require works with playwright-odiff
const assert = require("node:assert");

// require(".") must resolve to the CJS build (dist/index.cjs via package exports)
const cjs = require("../");
assert.strictEqual(
  typeof cjs.toHaveScreenshotOdiff,
  "function",
  "require('playwright-odiff') must expose toHaveScreenshotOdiff",
);

// "./setup" must be require-able (registers the matcher via expect.extend)
require("../dist/setup.cjs");

// and the ESM build must still work
import("../dist/index.js").then((esm) => {
  assert.strictEqual(
    typeof esm.toHaveScreenshotOdiff,
    "function",
    "import('playwright-odiff') must expose toHaveScreenshotOdiff",
  );
});
