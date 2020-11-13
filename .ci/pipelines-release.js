const fs = require("fs");
const path = require("path");

console.log("Creating package.json");

const exists = fs.existsSync("package.json");
if (!exists) {
  console.error("No package.json or esy.json at " + "package.json");
  process.exit(1);
}
// Now require from this script's location.
const mainPackageJson = require(path.join("..", "package.json"));
const bins = Array.isArray(mainPackageJson.esy.release.bin)
  ? mainPackageJson.esy.release.bin.reduce(
      (acc, curr) => Object.assign({ [curr]: "bin/" + curr }, acc),
      {}
    )
  : Object.keys(mainPackageJson.esy.release.bin).reduce(
      (acc, currKey) =>
        Object.assign(
          { [currKey]: "bin/" + mainPackageJson.esy.release.bin[currKey] },
          acc
        ),
      {}
    );

const packageJson = JSON.stringify(
  {
    name: "odiff-bin",
    version: mainPackageJson.version,
    license: mainPackageJson.license,
    description: mainPackageJson.description,
    repository: mainPackageJson.repository,
    author: mainPackageJson.author,
    typings: "./odiff.d.ts",
    module: "./odiff.js",
    scripts: {
      "postinstall": "node ./postinstall.js"
    },
    bin: bins,
  },
  null,
  2
);

fs.writeFileSync(
  path.join(__dirname, "..", "_release", "package.json"),
  packageJson,
  {
    encoding: "utf8",
  }
);

try {
  console.log("Copying LICENSE");
  fs.copyFileSync(
    path.join(__dirname, "..", "LICENSE"),
    path.join(__dirname, "..", "_release", "LICENSE")
  );
} catch (e) {
  console.warn("No LICENSE found");
}

console.log("Copying README.md");
fs.copyFileSync(
  path.join(__dirname, "..", "README.md"),
  path.join(__dirname, "..", "_release", "README.md")
);

console.log("Copying postinstall.js");
fs.copyFileSync(
  path.join(__dirname, "release-postinstall.js"),
  path.join(__dirname, "..", "_release", "postinstall.js")
);

console.log("Copying node bindings");
fs.copyFileSync(
  path.join(__dirname, "..", "bin", "node-bindings", "odiff.js"),
  path.join(__dirname, "..", "_release", "odiff.js")
);

fs.copyFileSync(
  path.join(__dirname, "..", "bin", "node-bindings", "odiff.d.ts"),
  path.join(__dirname, "..", "_release", "odiff.d.ts")
);

if (!fs.existsSync(path.join(__dirname, "..", "_release", "bin"))) {
  console.log("Creating placeholder files");
  const placeholderFile = `:; echo "Binary was not linked. You need to have postinstall enabled. Please rerun 'npm install'"; exit $?
@ECHO OFF
ECHO Binary was not linked. You need to have postinstall enabled. Please rerun 'npm install'`;
  fs.mkdirSync(path.join(__dirname, "..", "_release", "bin"));

  Object.keys(bins).forEach((name) => {
    if (bins[name]) {
      const binPath = path.join(__dirname, "..", "_release", bins[name]);
      fs.writeFileSync(binPath, placeholderFile);
      fs.chmodSync(binPath, 0777);
    } else {
      console.log("bins[name] name=" + name + " was empty. Weird.");
      console.log(bins);
    }
  });
}
