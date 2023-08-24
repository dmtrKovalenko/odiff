/*
 * For transparency reasons, this is a script and not a native executable
 */

const fs = require("fs");
const path = require("path");
const os = require("os");
const crypto = require("crypto");
const url = require("url");
const cp = require("child_process");

function mkdirpSync(pathStr) {
  if (fs.existsSync(pathStr)) {
    return;
  } else {
    mkdirpSync(path.dirname(pathStr));
    fs.mkdirSync(pathStr);
  }
}

function copy(src, dest) {
  let srcStat = fs.statSync(src);
  if (srcStat.isDirectory()) {
    if (!fs.existsSync(dest)) {
      mkdirpSync(dest);
    }
    let srcEntries = fs.readdirSync(src);
    for (srcEntry of srcEntries) {
      copy(path.join(src, srcEntry), path.join(dest, srcEntry));
    }
  } else {
    fs.writeFileSync(dest, fs.readFileSync(src));
  }
}

function fetch(urlStr, urlObj, pathStr, callback) {
  let httpm;
  switch (urlObj.protocol) {
    case "http:":
      httpm = require("http");
      break;
    case "https:":
      httpm = require("https");
      break;
    default:
      throw `Unrecognised protocol in provided url: ${urlStr}`;
  }
  httpm.get(urlObj, function (response) {
    if (response.statusCode == 302) {
      let urlStr = response.headers.location;
      fetch(urlStr, url.parse(urlStr), pathStr, callback);
    } else {
      response.pipe(fs.createWriteStream(pathStr)).on("finish", function () {
        callback(pathStr);
      });
    }
  });
}

function uncompress(pathStr, pkgPath) {
  pathStr = normalisePath(pathStr);
  switch (path.extname(pathStr)) {
    case ".tgz":
    case ".gz":
      tar(pathStr, pkgPath, true);
      break;
    case ".xz":
      tar(pathStr, pkgPath);
      break;
    case ".zip":
      unzip(pathStr, pkgPath);
      break;
  }
}

function computeChecksum(filePath, algo) {
  return new Promise((resolve, reject) => {
    let stream = fs.createReadStream(filePath).pipe(crypto.createHash(algo));
    let buf = "";
    stream.on("data", (chunk) => {
      buf += chunk.toString("hex");
    });
    stream.on("end", () => {
      resolve(buf);
    });
  });
}

function normalisePath(path) {
  let platform;
  try {
    platform = cp.execSync("uname").toString().trim();
  } catch (e) {
    console.log(e);
    platform = "Windows";
  }

  if (/cygwin/i.test(platform) || /mingw/i.test(platform)) {
    path = cp.execSync(`cygpath -u ${path}`).toString().trim();
  }

  return path;
}

function download(urlStrWithChecksum, pkgPath) {
  return new Promise(function (resolve, reject) {
    let [urlStr, checksum] = urlStrWithChecksum.split("#");
    if (!urlStr) {
      reject(`No url in ${urlStr}`);
    } else if (!checksum) {
      reject(`No checksum in ${urlStr}`);
    }

    let urlObj = url.parse(urlStr);
    let filename = path.basename(urlObj.path);
    let tmpDownloadedPath = path.join(os.tmpdir(), "esy-package-" + filename);

    let protoParts = urlObj.protocol.split("+");

    if (protoParts.length > 2) {
      reject("Unrecognised protocol " + urlObj.protocol);
    } else if (protoParts.length === 2) {
      let [a, b] = protoParts;
      if (a === "git") {
        let gitUrl = url.format({ ...urlObj, protocol: b });

        if (fs.existsSync(tmpDownloadedPath)) {
          reject("TODO: run rm -rf");
        } else {
          let destDir = path.join(pkgPath, "git-source"); // TODO: not network resilient. Any interruptions will corrupt the path
          cp.execSync(`git clone ${gitUrl} ${destDir}`);
          let commitHash = checksum;
          cp.execSync(`git -C ${destDir} checkout ${commitHash}`);
          resolve(destDir);
        }
      } else {
        reject("Unrecognised protocol " + urlObj.protocol);
      }
    } else {
      let [algo, hashStr] = checksum.split(":");
      if (!hashStr) {
        hashStr = algo;
        algo = "sha1";
      }

      if (fs.existsSync(tmpDownloadedPath)) {
        computeChecksum(tmpDownloadedPath, algo).then((checksum) => {
          if (hashStr == checksum) {
            uncompress(tmpDownloadedPath, pkgPath);
            resolve(tmpDownloadedPath);
          } else {
            fetch(urlStr, urlObj, tmpDownloadedPath, () =>
              computeChecksum(tmpDownloadedPath, algo).then((checksum) => {
                if (hashStr == checksum) {
                  uncompress(tmpDownloadedPath, pkgPath);
                  resolve(tmpDownloadedPath);
                } else {
                  reject(`Checksum error: expected ${hashStr} got ${checksum}`);
                }
              })
            );
          }
        });
      } else {
        fetch(urlStr, urlObj, tmpDownloadedPath, () =>
          computeChecksum(tmpDownloadedPath, algo).then((checksum) => {
            if (hashStr == checksum) {
              uncompress(tmpDownloadedPath, pkgPath);
              resolve(tmpDownloadedPath);
            } else {
              reject(`Checksum error: expected ${hashStr} got ${checksum}`);
            }
          })
        );
      }
    }
  });
}

let cwd = process.argv[2] || process.cwd();
let manifest = require(path.join(cwd, "esy.json"));

let {
  source,
  name,
  version,
  description,
  override: { build, install, buildsInSource, dependencies },
} = manifest;

function tar(filePath, destDir, gzip) {
  cp.execSync(`tar -x${gzip ? "z" : ""}f ${filePath} -C ${destDir}`, {
    stdio: "inherit",
  });
}

function unzip(filePath, destDir) {
  cp.execSync(`unzip -o ${filePath} -d ${destDir}`);
}

let esyPackageDir = path.join(cwd, "_esy-package");
mkdirpSync(esyPackageDir);
let pkgPath = esyPackageDir;
download(source, pkgPath)
  .then(() => {
    let entries = fs.readdirSync(pkgPath);
    if (entries.length > 1) {
      // Extracted tarball is not wrapped by a single root directory. The entire `pkgPath` must be considered as package root
      return pkgPath;
    } else {
      return path.join(pkgPath, entries[0]);
    }
  })
  .then((pkgPath) => {
    function filterComments(o = {}) {
      return Object.keys(o)
        .filter((k) => !k.startsWith("//"))
        .reduce((acc, k) => {
          acc[k] = o[k];
          return acc;
        }, {});
    }
    let buildEnv = filterComments(manifest.override.buildEnv);
    let exportedEnv = filterComments(manifest.override.exportedEnv);
    let esy = { buildsInSource, build, install, buildEnv, exportedEnv };
    let patchFilesPath = path.join(cwd, "files");
    if (fs.existsSync(patchFilesPath)) {
      copy(patchFilesPath, pkgPath);
    }
    fs.writeFileSync(
      path.join(pkgPath, "package.json"),
      JSON.stringify({ name, version, description, esy, dependencies }, null, 2)
    );
    fs.writeFileSync(
      path.join(pkgPath, ".npmignore"),
      `
_esy
`
    );
  });
