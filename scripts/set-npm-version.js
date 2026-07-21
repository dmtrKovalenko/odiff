// Bumps the version in the local package.json and build.zig.zon files
const fs = require("fs");
const path = require("path");

const version = process.argv[2];
const withPlatformPins = process.argv.includes("--platform-pins");
if (!version) {
  console.error(
    "Usage: node scripts/set-npm-version.js <version> [--platform-pins]",
  );
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

  if (pkg.name === "odiff-bin" && withPlatformPins) {
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

const zonPath = path.join(root, "build.zig.zon");
const zon = fs.readFileSync(zonPath, "utf8");
fs.writeFileSync(zonPath, zon.replace(/\.version = "[^"]*"/, `.version = "${version}"`));
console.log(`build.zig.zon -> ${version}`);
