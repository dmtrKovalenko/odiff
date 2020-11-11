// @ts-check
const path = require("path");
const { execFile } = require("child_process");
const { Console } = require("console");

function optionsToArgs(options) {
  if (!options) {
    return [];
  }

  let argArray = [];

  const setValueArg = (name, value) => {
    argArray.push(`--${name}`);
    argArray.push(value.toString());
  };

  const setFlag = (name, value) => {
    if (value) {
      argArray.push(`--${name}`);
    }
  };

  Object.entries(options).forEach(([option, value]) => {
    switch (option) {
      case "failOnLayoutDiff":
        setFlag("fail-on-layout", value);
        break;

      case "diffImage":
        setFlag("diff-image", value);
        break;

      case "threshold":
        setValueArg("threshold", value);
        argArray;
    }
  });

  return argArray;
}

const CMD_BIN_HELPER_MSG =
  "Usage: odiff [OPTION]... [BASE] [COMPARING] [DIFF]\nTry `odiff --help' for more information.\n";

async function compare(basePath, comparePath, diffOutput, options) {
  return new Promise((resolve, reject) => {
    let producedStdout, producedStdError;

    execFile(
      path.join(__dirname, "bin", "ODiffBin"),
      [basePath, comparePath, diffOutput, ...optionsToArgs(options)],
      (_, stdout, stderr) => {
        producedStdout = stdout;
        producedStdError = stderr;
      }
    ).on("close", (code) => {
      switch (code) {
        case 0:
          resolve({ match: true });
          break;
        case 21:
          resolve({ match: false, reason: "layout-diff" });
          break;
        case 22:
          resolve({ match: false, reason: "pixel-diff" });
          break;
        case 124:
          reject(
            new TypeError(
              (producedStdError || "Invalid Argument Exception").replace(
                CMD_BIN_HELPER_MSG,
                ""
              )
            )
          );
          break;

        default:
          reject(
            new Error(
              (producedStdError || producedStdout).replace(
                CMD_BIN_HELPER_MSG,
                ""
              )
            )
          );
          break;
      }
    });
  });
}

module.exports = {
  compare,
};
