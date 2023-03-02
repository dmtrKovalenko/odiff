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

      case "antialiasing":
        setFlag("antialiasing", value);
        break;

      case "captureDiffLines":
        setFlag("output-diff-lines", value);
        break;

      case "ignoreRegions": {
        const regions = value
          .map(
            (region) => `${region.x1}:${region.y1}-${region.x2}:${region.y2}`
          )
          .join(",");

        setArgWithValue("ignore", regions);
        break;
      }
    }
  });

  return argArray;
}

/** @type {(stdout: string) => Partial<{ diffCount: number, diffPercentage: number, diffLines: number[] }>} */
function parsePixelDiffStdout(stdout) {
  try {
    const parts = stdout.split(";");

    if (parts.length === 2) {
      const [diffCount, diffPercentage] = parts;

      return {
        diffCount: parseInt(diffCount),
        diffPercentage: parseFloat(diffPercentage),
      };
    } else if (parts.length === 3) {
      const [diffCount, diffPercentage, linesPart] = parts;

      return {
        diffCount: parseInt(diffCount),
        diffPercentage: parseFloat(diffPercentage),
        diffLines: linesPart.split(",").flatMap((line) => {
          let parsedInt = parseInt(line);

          return isNaN(parsedInt) ? [] : parsedInt;
        }),
      };
    } else {
      throw new Error(`Weird pixel diff stdout: ${stdout}`);
    }
  } catch (e) {
    console.warn(
      "Can't parse output from internal process. Please submit an issue at https://github.com/dmtrKovalenko/odiff/issues/new with the following stacktrace:",
      e
    );
  }

  return {};
}

const CMD_BIN_HELPER_MSG =
  "Usage: odiff [OPTION]... [BASE] [COMPARING] [DIFF]\nTry `odiff --help' for more information.\n";

async function compare(basePath, comparePath, diffOutput, options = {}) {
  return new Promise((resolve, reject) => {
    let producedStdout, producedStdError;

    const binaryPath =
      options && options.__binaryPath
        ? options.__binaryPath
        : path.join(__dirname, "bin", "odiff");

    execFile(
      binaryPath,
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
          resolve({
            match: false,
            reason: "pixel-diff",
            ...parsePixelDiffStdout(producedStdout),
          });
          break;
        case 124:
          /** @type string */
          const originalErrorMessage = (
            producedStdError || "Invalid Argument Exception"
          ).replace(CMD_BIN_HELPER_MSG, "");

          const noFileOrDirectoryMatches = originalErrorMessage.match(
            /no\n\s*`(.*)'\sfile or\n\s*directory/
          );

          if (options.noFailOnFsErrors && noFileOrDirectoryMatches?.[1]) {
            resolve({
              match: false,
              reason: "file-not-exists",
              file: noFileOrDirectoryMatches[1],
            });
          } else {
            reject(new TypeError(originalErrorMessage));
          }
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
