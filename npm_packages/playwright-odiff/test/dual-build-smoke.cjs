// Smoke test for the dual CJS/ESM build. Run with `node test/dual-build-smoke.cjs`.
// Ensures the `require` entry points work (consumers on CJS — e.g. Playwright
// transpiling TS tests to CJS, or Bazel/rules_js where the ESM loader's
// realpath resolution loads a duplicate @playwright/test) alongside `import`.
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

// require(".") must resolve to the CJS build
const cjs = require("../");
assert.strictEqual(
  typeof cjs.toHaveScreenshotOdiff,
  "function",
  "require('playwright-odiff') must expose toHaveScreenshotOdiff",
);

// the CJS output dir must be marked commonjs so Node doesn't parse it as ESM
const cjsPkg = JSON.parse(
  fs.readFileSync(path.join(__dirname, "../dist/cjs/package.json"), "utf8"),
);
assert.strictEqual(cjsPkg.type, "commonjs", "dist/cjs must be type=commonjs");

// "./setup" must be require-able (registers the matcher via expect.extend)
require("../dist/cjs/setup.js");

// and the ESM build must still work
import("../dist/index.js").then((esm) => {
  assert.strictEqual(
    typeof esm.toHaveScreenshotOdiff,
    "function",
    "import('playwright-odiff') must expose toHaveScreenshotOdiff",
  );
  console.log("dual build smoke test passed");
});
