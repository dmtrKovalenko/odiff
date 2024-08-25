const fs = require('fs');
const path = require('path');
const os = require('os');

const binaries = {
  'linux-x64': 'odiff-linux-x64.exe',
  'darwin-arm64': 'odiff-macos-arm64.exe',
  'darwin-x64': 'odiff-macos-x64.exe',
  'win32-x64': 'odiff-windows-x64.exe',
};

const platform = os.platform();
const arch = os.arch();

let binaryKey = `${platform}-${arch}`;
if (platform === 'win32' && arch === 'x64') {
  binaryKey = 'win32-x64';
}

const binaryFile = binaries[binaryKey];

if (!binaryFile) {
  console.error(`odiff: Sorry your platform or architecture is not supported. Here is a list of supported binaries: ${Object.keys(binaries).join(', ')}`);
  process.exit(1);
}

const sourcePath = path.join(__dirname, 'raw_binaries', binaryFile);
const destPath = path.join(__dirname, 'bin', 'odiff.exe');

try {
  fs.copyFileSync(sourcePath, destPath);
  fs.chmodSync(destPath, 0o755);
} catch (err) {
  console.error(`odiff: failed to copy and link the binary file: ${err}`);
  process.exit(1);
}
