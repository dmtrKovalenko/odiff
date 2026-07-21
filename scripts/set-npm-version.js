// Stamps the given version on every published npm package: the @odiff/*
// platform packages, odiff-bin and playwright-odiff (including their
// cross-package dependency pins), plus the private monorepo root.
//
// The @odiff/* optionalDependencies of odiff-bin are injected here rather
// than committed to its package.json: they must be pinned to the exact
// version published in the same CI run, and any committed pin would point
// to a version that does not exist on npm, breaking `npm ci` (the platform
// packages can not be part of the root lockfile).
//
// Usage: node scripts/set-npm-version.js <version>
const fs = require("fs");
const path = require("path");

const version = process.argv[2];
if (!version) {
  console.error("Usage: node scripts/set-npm-version.js <version>");
  process.exit(1);
}

const root = path.resolve(__dirname, "..");
const platformsDir = path.join(root, "npm_packages", "platforms");

const platformPackageJsonPaths = fs
  .readdirSync(platformsDir)
  .map((dir) => path.join(platformsDir, dir, "package.json"))
  .filter(fs.existsSync);

const packageJsonPaths = [
  path.join(root, "package.json"),
  path.join(root, "npm_packages", "odiff-bin", "package.json"),
  path.join(root, "npm_packages", "playwright-odiff", "package.json"),
  ...platformPackageJsonPaths,
];

for (const packageJsonPath of packageJsonPaths) {
  const pkg = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
  pkg.version = version;

  if (pkg.name === "odiff-bin") {
    pkg.optionalDependencies = Object.fromEntries(
      platformPackageJsonPaths
        .map((p) => JSON.parse(fs.readFileSync(p, "utf8")).name)
        .sort()
        .map((name) => [name, version]),
    );
  }

  for (const depType of ["dependencies", "optionalDependencies"]) {
    for (const dep of Object.keys(pkg[depType] ?? {})) {
      if (dep === "odiff-bin" || dep.startsWith("@odiff/")) {
        pkg[depType][dep] = version;
      }
    }
  }

  fs.writeFileSync(packageJsonPath, JSON.stringify(pkg, null, 2) + "\n");
  console.log(`${path.relative(root, packageJsonPath)} -> ${version}`);
}
