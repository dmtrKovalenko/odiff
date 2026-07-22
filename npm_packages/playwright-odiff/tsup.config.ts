import { defineConfig } from "tsup";

// Dual ESM + CJS build. Because package.json has "type": "module", tsup emits:
//   esm -> index.js  / setup.js   (+ .d.ts)
//   cjs -> index.cjs / setup.cjs  (+ .d.cts)
// The correct extensions mean Node picks the right module system per file, so
// there's no need for a dist/cjs/package.json "{type:commonjs}" marker.
export default defineConfig({
  entry: ["src/index.ts", "src/setup.ts"],
  format: ["esm", "cjs"],
  dts: true,
  sourcemap: true,
  clean: true,
  // Keep each entry self-contained (no shared chunk-*.js). ESM splitting is on
  // by default in tsup; the CJS format can't split anyway, so disabling this
  // makes both formats symmetric and avoids the hashed chunk filename.
  splitting: false,
  // @playwright/test (peer) and odiff-bin (dependency) are externalized by
  // default; keep node built-ins external too (tsup does this automatically).
});
