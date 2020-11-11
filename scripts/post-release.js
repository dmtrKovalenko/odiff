const path = require("path");
const fs = require("fs");

const releaseFolder = path.resolve(__dirname, "..", "_release");
const packageJsonPath = path.join(releaseFolder, "package.json");
const nodeBindingsPath = path.resolve(
  __dirname,
  "..",
  "bin",
  "node-bindings",
  "odiff.js"
);
const nodeBindingsTsPath = path.resolve(
  __dirname,
  "..",
  "bin",
  "node-bindings",
  "odiff.d.ts"
);

const { bin, name, ...package } = JSON.parse(
  fs.readFileSync(packageJsonPath, {
    encoding: "utf-8",
  })
);

const packageJsonWithRightBinaryName = {
  name: "odiff-bin",
  ...package,
  typings: "./odiff.d.ts",
  module: "./odiff.js",
  bin: {
    odiff: bin["ODiffBin"],
  },
};

fs.writeFileSync(
  packageJsonPath,
  JSON.stringify(packageJsonWithRightBinaryName, null, 2)
);

fs.copyFileSync(nodeBindingsPath, path.join(releaseFolder, "odiff.js"));
fs.copyFileSync(nodeBindingsTsPath, path.join(releaseFolder, "odiff.d.ts"));
