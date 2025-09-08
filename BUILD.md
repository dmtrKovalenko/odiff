# Building odiff

odiff is a cross-platform image comparison tool written in Zig, compatible with Linux, macOS, and Windows.

## Prerequisites

- [Zig](https://ziglang.org/) 0.14.1 or later
- Image processing libraries (platform-specific, see below)

## Platform-Specific Setup

### macOS

Install dependencies via Homebrew:

```bash
brew install libspng jpeg-turbo libtiff
```

Build:
```bash
zig build
```

### Linux (Ubuntu/Debian)

Install dependencies:

```bash
sudo apt-get update
sudo apt-get install libspng-dev libjpeg-dev libtiff-dev pkg-config
```

Build:
```bash
zig build
```

### Linux (Fedora/RHEL)

Install dependencies:

```bash
sudo dnf install libspng-devel libjpeg-turbo-devel libtiff-devel pkgconfig
```

Build:
```bash
zig build
```

### Linux (Arch)

Install dependencies:

```bash
sudo pacman -S libspng libjpeg-turbo libtiff pkgconf
```

Build:
```bash
zig build
```

### Windows

#### Option 1: Using vcpkg (Recommended)

1. Install [vcpkg](https://github.com/Microsoft/vcpkg):
   ```cmd
   git clone https://github.com/Microsoft/vcpkg.git
   cd vcpkg
   .\bootstrap-vcpkg.bat
   ```

2. Set environment variable:
   ```cmd
   set VCPKG_ROOT=C:\path\to\vcpkg
   ```

3. Install dependencies:
   ```cmd
   .\vcpkg install libspng:x64-windows libjpeg-turbo:x64-windows tiff:x64-windows
   ```

4. Build:
   ```cmd
   zig build
   ```

#### Option 2: Manual Installation

If you don't use vcpkg, you can manually install the libraries and update the paths in `build.zig` to point to your installation directories.

## Cross-Compilation

You can cross-compile for different targets:

```bash
# Build for Linux x86_64 from any platform
zig build -Dtarget=x86_64-linux

# Build for Windows x86_64 from any platform  
zig build -Dtarget=x86_64-windows

# Build for macOS x86_64 from any platform
zig build -Dtarget=x86_64-macos

# Build for macOS ARM64 (Apple Silicon) from any platform
zig build -Dtarget=aarch64-macos
```

## Library Fallbacks

If some image libraries are not available, odiff will build with available libraries and provide:

- **No libspng**: Falls back to a simple placeholder (functionality limited)
- **No libjpeg**: Falls back to PNG reading for JPEG files (may fail)
- **No libtiff**: Falls back to PNG reading for TIFF files (may fail)

For full functionality, install all three libraries.

## Troubleshooting

### Library Not Found Errors

1. **Linux**: Ensure pkg-config can find the libraries:
   ```bash
   pkg-config --libs libspng libjpeg libtiff-4
   ```

2. **macOS**: Check Homebrew installation:
   ```bash
   brew list libspng jpeg-turbo libtiff
   ```

3. **Windows**: Verify vcpkg installation and VCPKG_ROOT environment variable.

### Build Errors

- Make sure you're using Zig 0.14.1 or later
- On Windows, ensure you have a C compiler (Visual Studio Build Tools or MinGW)
- Check that all library dependencies are properly installed

## Testing

Run the test suite:

```bash
# Install Node.js dependencies first
npm install

# Run tests
npm test
```

The test suite requires the odiff binary to be built and located at `./zig-out/bin/odiff`.
