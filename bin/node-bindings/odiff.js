// @ts-check
const path = require("path");
const { execFile } = require("child_process");

function optionsToArgs(options) {
  if (!options) {
    return [];
  }

  let argArray = [];

  const setArgWithValue = (name, value) => {
    argArray.push(`--${name}`);
    argArray.push(value.toString());
  };

  const setFlag = (name, value) => {
    if (value) {
      argArray.push(`--${name}`);
    }
  };

  Object.entries(options).forEach((optionEntry) => {
    /** 
     * @type {[keyof import('./odiff').ODiffOptions, unknown]} 
     * @ts-expect-error */
    const [option, value] = optionEntry

    switch (option) {
      case "failOnLayoutDiff":
        setFlag("fail-on-layout", value);
        break;

      case "outputDiffMask":
        setFlag("diff-image", value);
        break;

      case "threshold":
        setArgWithValue("threshold", value);
        break;
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
      path.join(__dirname, "bin", "odiff"),
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
