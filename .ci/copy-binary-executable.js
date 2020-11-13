const fs = require("fs");
const path = require("path");
const { version } = require("../package.json");

const platform = process.argv[2];
const folder = process.argv[3];

if (!platform || !folder) {
  throw new Error(
    "platform & folder args are required. Pass it as `node copy-binary-executable.js MacOS ../folder`"
  );
}

const odiffExportRegex = /odiff-(.{1,24})\.tar\.gz/;
const binaryArchivePath = path.resolve(
  __dirname,
  "..",
  "_release",
  folder,
  "_export"
);

const odiffExportTarball = fs
  .readdirSync(binaryArchivePath)
  .filter((file) => /odiff-/.test(file))[0];

if (!odiffExportTarball) {
  throw new Error("Can not find the exported binaries");
}

const [_, hash] = path.basename(odiffExportTarball).match(odiffExportRegex);
fs.copyFileSync(
  path.join(binaryArchivePath, odiffExportTarball),
  path.join(
    __dirname,
    "..",
    "_release",
    `odiff-${platform}-${version}-${hash}.tar.gz`
  )
);
