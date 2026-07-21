// @ts-check
const fs = require("fs");
const path = require("path");

const SUPPORTED_PLATFORMS = [
  "linux-x64",
  "linux-arm64",
  "linux-riscv64",
  "darwin-x64",
  "darwin-arm64",
  "win32-x64",
  "win32-arm64",
];

/**
 * Resolves the odiff binary installed by the platform-specific
 * `@odiff/*` package (an optionalDependency of odiff-bin) which
 * exports the absolute path to its binary. Falls back to
 * `bin/odiff.exe` populated from a local zig build during development.
 *
 * @returns {string} absolute path to the odiff binary
 */
function findBinary() {
  const platformKey = `${process.platform}-${process.arch}`;

  if (SUPPORTED_PLATFORMS.includes(platformKey)) {
    try {
      const binaryPath = require(`@odiff/${platformKey}`);

      if (fs.existsSync(binaryPath)) {
        return binaryPath;
      }
    } catch (_) {
      // package is not installed, fall through to the dev binary
    }
  }

  const devBinaryPath = path.join(__dirname, "bin", "odiff.exe");
  if (fs.existsSync(devBinaryPath)) {
    return devBinaryPath;
  }

  if (!SUPPORTED_PLATFORMS.includes(platformKey)) {
    throw new Error(
      `odiff-bin: platform "${platformKey}" is not supported. Prebuilt binaries exist for: ${SUPPORTED_PLATFORMS.join(", ")}. ` +
        "You can build odiff from source (https://github.com/dmtrKovalenko/odiff#building) and pass the binary location using the __binaryPath option.",
    );
  }

  throw new Error(
    `odiff-bin: could not find the odiff binary. The "@odiff/${platformKey}" package should have been installed automatically as an optional dependency of odiff-bin. ` +
      "Make sure your package manager is not configured to skip optional dependencies and reinstall, " +
      "or pass an explicit binary location using the __binaryPath option.",
  );
}

module.exports = { findBinary };
