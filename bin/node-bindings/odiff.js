// @ts-check
const path = require("path");
const { execFile } = require("child_process");

function optionsToArgs(options) {
  let argArray = ["--parsable-stdout"];

  if (!options) {
    return argArray;
  }

  const setArgWithValue = (name, value) => {
    argArray.push(`--${name}=${value.toString()}`);
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
    const [option, value] = optionEntry;

    switch (option) {
      case "failOnLayoutDiff":
        setFlag("fail-on-layout", value);
        break;

      case "outputDiffMask":
        setFlag("diff-mask", value);
        break;

      case "threshold":
        setArgWithValue("threshold", value);
        break;

      case "diffColor":
        setArgWithValue("diff-color", value);
        break;
    }
  });

  return argArray;
}

/** @type {(stdout: string) => Partial<{ diffCount: number, diffPercentage: number }>} */
function parsePixelDiffStdout(stdout) {
  const parts = stdout.split(";");
  
  if (parts.length === 2) {
    const [diffCount, diffPercentage] = parts;

    try {
      return {
        diffCount: parseInt(diffCount),
        diffPercentage: parseFloat(diffPercentage),
      };
    } catch (e) {
      console.warn(
        "Can't parse output from internal process. Please file an issue at https://github.com/dmtrKovalenko/odiff/issues/new with the following stacktrace:",
        e
      );
    }
  }

  return {};
}

const CMD_BIN_HELPER_MSG =
  "Usage: odiff [OPTION]... [BASE] [COMPARING] [DIFF]\nTry `odiff --help' for more information.\n";

async function compare(basePath, comparePath, diffOutput, options) {
  return new Promise((resolve, reject) => {
    let producedStdout, producedStdError;

    const binaryPath = options.__binaryPath
      ? options.__binaryPath
      : path.join(__dirname, "bin", "odiff");

    execFile(
      binaryPath,
      [basePath, comparePath, diffOutput].concat(optionsToArgs(options)),
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
          resolve({
            match: false,
            reason: "pixel-diff",
            ...parsePixelDiffStdout(producedStdout),
          });
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
