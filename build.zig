const std = @import("std");
const manifest = @import("build.zig.zon");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Modules can depend on one another using the `std.Build.Module.addImport` function.
    // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
    // file path. In this case, we set up `exe_mod` to import `lib_mod`.
    exe_mod.addImport("odiff_lib", lib_mod);

    // Add version information as a build option
    const options = b.addOptions();
    options.addOption([]const u8, "version", manifest.version);
    exe_mod.addImport("build_options", options.createModule());
    lib_mod.addImport("build_options", options.createModule());

    // Build only the executable (no separate static library to avoid duplicate symbols)
    const exe = b.addExecutable(.{
        .name = "odiff",
        .root_module = exe_mod,
    });
    // ODIFF: uncomment to enable binary debugging
    // exe.root_module.strip = false;

    // Base C flags
    var c_flags = std.array_list.Managed([]const u8).init(b.allocator);
    defer c_flags.deinit();
    c_flags.append("-std=c99") catch @panic("OOM");
    c_flags.append("-Wno-nullability-completeness") catch @panic("OOM");

    // Try to detect and configure libraries
    var have_spng = false;
    var have_jpeg = false;
    var have_tiff = false;

    // Add C source files for image I/O
    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target.result.cpu.arch != native_target.result.cpu.arch or
        target.result.os.tag != native_target.result.os.tag;

    // Always try to configure libraries (vcpkg works for cross-compilation)
    configurePlatformLibraries(b, exe, target.result, &have_spng, &have_jpeg, &have_tiff) catch |err| {
        if (is_cross_compiling) {
            // For cross-compilation, library configuration failure should fail the build
            std.log.err("Build failed: {}", .{err});
            @panic("Cross-compilation requires proper vcpkg setup");
        } else {
            std.log.warn("Could not detect all image libraries, using fallback configuration", .{});
        }
    };

    if (have_spng) {
        c_flags.append("-DHAVE_SPNG") catch @panic("OOM");
        c_flags.append("-DSPNG_STATIC") catch @panic("OOM");
        c_flags.append("-DSPNG_SSE=3") catch @panic("OOM");
    }
    if (have_jpeg) c_flags.append("-DHAVE_JPEG") catch @panic("OOM");
    if (have_tiff) c_flags.append("-DHAVE_TIFF") catch @panic("OOM");

    exe.addCSourceFiles(.{
        .files = &.{
            "c_bindings/odiff_io.c",
        },
        .flags = c_flags.items,
    });

    // Link with system libraries
    exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    // Unit tests only test Zig code, no C bindings needed

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // No need to test exe_mod (main.zig) as it's just a CLI wrapper

    // Integration tests that use actual image files and need C bindings
    const integration_tests_with_io = [_][]const u8{
        "src/test_core.zig",
        "src/test_io_png.zig",
        "src/test_io_bmp.zig",
        "src/test_io_jpg.zig",
        "src/test_io_tiff.zig",
    };

    // Tests that don't need image I/O or C bindings
    const integration_tests_pure_zig = [_][]const u8{
        "src/test_color_delta.zig",
    };

    var integration_test_steps = std.array_list.Managed(*std.Build.Step.Run).init(b.allocator);
    defer integration_test_steps.deinit();

    // Skip integration tests when cross-compiling
    if (!is_cross_compiling) {
        // Tests that need C bindings and image I/O
        for (integration_tests_with_io) |test_path| {
            const integration_test = b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path(test_path),
                    .target = target,
                    .optimize = optimize,
                }),
            });

            // Link with system libraries
            integration_test.linkLibC();

            // Add C source files to integration tests (needed for image I/O functionality)
            integration_test.addCSourceFiles(.{
                .files = &.{
                    "c_bindings/odiff_io.c",
                },
                .flags = c_flags.items,
            });

            // Configure libraries for integration tests
            var test_have_spng = false;
            var test_have_jpeg = false;
            var test_have_tiff = false;
            configurePlatformLibraries(b, integration_test, target.result, &test_have_spng, &test_have_jpeg, &test_have_tiff) catch {
                std.log.warn("Could not configure libraries for integration test: {s}", .{test_path});
            };

            const run_integration_test = b.addRunArtifact(integration_test);
            integration_test_steps.append(run_integration_test) catch @panic("OOM");
        }

        // Tests that only need pure Zig code
        for (integration_tests_pure_zig) |test_path| {
            const pure_test = b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path(test_path),
                    .target = target,
                    .optimize = optimize,
                }),
            });

            const run_pure_test = b.addRunArtifact(pure_test);
            integration_test_steps.append(run_pure_test) catch @panic("OOM");
        }
    }

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Integration tests that need image files
    const integration_test_step = b.step("test-integration", "Run integration tests with test images");
    for (integration_test_steps.items) |test_run_step| {
        integration_test_step.dependOn(&test_run_step.step);
    }

    // Run all tests
    const test_all_step = b.step("test-all", "Run both unit and integration tests");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(integration_test_step);
}

fn configurePlatformLibraries(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    target_info: std.Target,
    have_spng: *bool,
    have_jpeg: *bool,
    have_tiff: *bool,
) !void {
    if (tryConfigureVcpkg(b, lib, target_info, have_spng, have_jpeg, have_tiff)) {
        std.log.debug("Using vcpkg libs for target {s}-{s}", .{ @tagName(target_info.cpu.arch), @tagName(target_info.os.tag) });

        // Add system libraries needed by vcpkg packages on Linux
        if (target_info.os.tag == .linux) {
            lib.linkLibC(); // Ensure libc is linked
            lib.linkSystemLibrary("m"); // math library
            lib.linkSystemLibrary("pthread"); // threading
            lib.linkSystemLibrary("dl"); // dynamic loading
        }
        return;
    }

    // Check if we're cross-compiling
    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target_info.cpu.arch != native_target.result.cpu.arch or
        target_info.os.tag != native_target.result.os.tag;
    
    // For cross-compilation, vcpkg is required - don't fall back to native libraries
    if (is_cross_compiling) {
        std.log.err("Cross-compilation requires vcpkg libraries. Target: {s}-{s}", .{ @tagName(target_info.cpu.arch), @tagName(target_info.os.tag) });
        std.log.err("Make sure VCPKG_ROOT is set and libraries are installed for the target.", .{});
        return error.CrossCompilationRequiresVcpkg;
    }

    // Fall back to platform-specific methods for native compilation only
    const is_windows = target_info.os.tag == .windows;
    const is_macos = target_info.os.tag == .macos;
    const is_linux = target_info.os.tag == .linux;

    if (is_windows) {
        try configureWindowsLibraries(b, lib, have_spng, have_jpeg, have_tiff);
    } else if (is_macos) {
        try configureMacOSLibraries(b, lib, have_spng, have_jpeg, have_tiff);
    } else if (is_linux) {
        try configureLinuxLibraries(b, lib, have_spng, have_jpeg, have_tiff);
    } else {
        try configureLinuxLibraries(b, lib, have_spng, have_jpeg, have_tiff);
    }
}

fn configureWindowsLibraries(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    have_spng: *bool,
    have_jpeg: *bool,
    have_tiff: *bool,
) !void {
    // Windows library detection - try vcpkg paths first
    const vcpkg_root = std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            std.log.info("VCPKG_ROOT not found, libraries may need to be installed manually", .{});
            return;
        },
        else => return err,
    };
    defer b.allocator.free(vcpkg_root);

    // Try to find libraries in vcpkg installed directory
    const vcpkg_installed = std.fmt.allocPrint(b.allocator, "{s}/installed/x64-windows", .{vcpkg_root}) catch return;
    defer b.allocator.free(vcpkg_installed);

    // Add vcpkg include and lib paths
    const include_path = std.fmt.allocPrint(b.allocator, "{s}/include", .{vcpkg_installed}) catch return;
    defer b.allocator.free(include_path);
    const lib_path = std.fmt.allocPrint(b.allocator, "{s}/lib", .{vcpkg_installed}) catch return;
    defer b.allocator.free(lib_path);

    lib.addIncludePath(.{ .cwd_relative = include_path });
    lib.addLibraryPath(.{ .cwd_relative = lib_path });

    // Try to link libraries (Windows naming)
    lib.linkSystemLibrary("spng");
    lib.linkSystemLibrary("jpeg");
    lib.linkSystemLibrary("tiff");

    have_spng.* = true;
    have_jpeg.* = true;
    have_tiff.* = true;
}

fn configureMacOSLibraries(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    have_spng: *bool,
    have_jpeg: *bool,
    have_tiff: *bool,
) !void {
    // Check if we're cross-compiling - if so, don't add system paths
    const target_info = lib.root_module.resolved_target.?.result;
    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target_info.cpu.arch != native_target.result.cpu.arch or
        target_info.os.tag != native_target.result.os.tag;

    if (is_cross_compiling) {
        std.log.info("Cross-compiling macOS target, skipping system library paths", .{});
        return error.CrossCompilationNotSupported;
    }

    // macOS Homebrew configuration (native only)
    lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    lib.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });

    // Also try /usr/local for Intel Macs
    lib.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    lib.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });

    lib.linkSystemLibrary("spng");
    lib.linkSystemLibrary("jpeg");
    lib.linkSystemLibrary("tiff");

    have_spng.* = true;
    have_jpeg.* = true;
    have_tiff.* = true;
}

fn configureLinuxLibraries(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    have_spng: *bool,
    have_jpeg: *bool,
    have_tiff: *bool,
) !void {
    // Linux pkg-config configuration

    // Try to use pkg-config for library detection
    if (tryPkgConfig(b, lib, "libspng")) {
        have_spng.* = true;
    } else {
        // Fallback: try common system paths
        lib.linkSystemLibrary("spng");
        have_spng.* = true;
    }

    if (tryPkgConfig(b, lib, "libjpeg")) {
        have_jpeg.* = true;
    } else {
        // Fallback: try common library names
        lib.linkSystemLibrary("jpeg");
        have_jpeg.* = true;
    }

    if (tryPkgConfig(b, lib, "libtiff-4")) {
        have_tiff.* = true;
    } else {
        // Fallback
        lib.linkSystemLibrary("tiff");
        have_tiff.* = true;
    }
}

fn tryPkgConfig(b: *std.Build, lib: *std.Build.Step.Compile, package: []const u8) bool {
    // Try to run pkg-config to get flags
    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{ "pkg-config", "--cflags", "--libs", package },
    }) catch {
        return false;
    };
    defer b.allocator.free(result.stdout);
    defer b.allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        return false;
    }

    // Parse the pkg-config output
    var flags_it = std.mem.tokenizeAny(u8, result.stdout, " \n");
    while (flags_it.next()) |flag| {
        if (std.mem.startsWith(u8, flag, "-I")) {
            const include_path = flag[2..];
            lib.addIncludePath(.{ .cwd_relative = include_path });
        } else if (std.mem.startsWith(u8, flag, "-L")) {
            const lib_path = flag[2..];
            lib.addLibraryPath(.{ .cwd_relative = lib_path });
        } else if (std.mem.startsWith(u8, flag, "-l")) {
            const lib_name = flag[2..];
            lib.linkSystemLibrary(lib_name);
        }
    }

    return true;
}

fn tryConfigureVcpkg(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    target_info: std.Target,
    have_spng: *bool,
    have_jpeg: *bool,
    have_tiff: *bool,
) bool {
    // Get vcpkg root directory
    const vcpkg_root = std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch {
        return false;
    };
    defer b.allocator.free(vcpkg_root);

    // Determine vcpkg triplet based on target architecture and OS
    const vcpkg_triplet = getVcpkgTriplet(target_info) catch {
        return false;
    };
    defer std.heap.page_allocator.free(vcpkg_triplet);

    // Construct vcpkg installed path
    // Check if vcpkg_root already contains "vcpkg_installed" (GitHub Actions format)
    const vcpkg_installed = if (std.mem.endsWith(u8, vcpkg_root, "vcpkg_installed"))
        std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ vcpkg_root, vcpkg_triplet }) catch return false
    else
        std.fmt.allocPrint(b.allocator, "{s}/installed/{s}", .{ vcpkg_root, vcpkg_triplet }) catch return false;
    defer b.allocator.free(vcpkg_installed);

    std.fs.accessAbsolute(vcpkg_installed, .{}) catch {
        std.log.warn("vcpkg triplet directory not found: {s}", .{vcpkg_installed});
        return false;
    };

    const include_path = std.fmt.allocPrint(b.allocator, "{s}/include", .{vcpkg_installed}) catch {
        return false;
    };
    defer b.allocator.free(include_path);

    const lib_path = std.fmt.allocPrint(b.allocator, "{s}/lib", .{vcpkg_installed}) catch {
        return false;
    };
    defer b.allocator.free(lib_path);

    lib.addIncludePath(.{ .cwd_relative = include_path });
    lib.addLibraryPath(.{ .cwd_relative = lib_path });

    // Link libraries using linkSystemLibrary (with vcpkg paths set, it will find the right ones)
    const lib_names = getLibraryNames(target_info);

    // Link SPNG
    lib.linkSystemLibrary(lib_names.spng);
    have_spng.* = true;

    // Link JPEG
    lib.linkSystemLibrary(lib_names.jpeg);
    have_jpeg.* = true;

    // Link TIFF
    lib.linkSystemLibrary(lib_names.tiff);
    have_tiff.* = true;

    // Link required dependencies
    if (target_info.os.tag == .windows) {
        lib.linkSystemLibrary("zlib"); // vcpkg installs as libzlib.a on Windows
        lib.linkSystemLibrary("lzma"); // vcpkg installs as liblzma.a
        // Note: deflate library not available in vcpkg mingw-static, skip it
    } else {
        lib.linkSystemLibrary("z");
        lib.linkSystemLibrary("lzma");
    }

    return true;
}

fn getVcpkgTriplet(target_info: std.Target) ![]const u8 {
    const arch_str = switch (target_info.cpu.arch) {
        .x86_64 => "x64",
        .aarch64 => "arm64",
        .x86 => "x86",
        .arm => "arm",
        else => return error.UnsupportedArchitecture,
    };

    const os_str = switch (target_info.os.tag) {
        .windows => "mingw", // Use mingw to match GitHub Actions triplet
        .linux => "linux",
        .macos => "osx",
        .freebsd => "freebsd",
        else => return error.UnsupportedOS,
    };

    // Handle special cases for static linking preference
    return switch (target_info.os.tag) {
        .windows => std.fmt.allocPrint(std.heap.page_allocator, "{s}-{s}-static", .{ arch_str, os_str }),
        else => std.fmt.allocPrint(std.heap.page_allocator, "{s}-{s}", .{ arch_str, os_str }),
    };
}

const LibraryNames = struct {
    spng: []const u8,
    jpeg: []const u8,
    tiff: []const u8,
};

fn getLibraryNames(target_info: std.Target) LibraryNames {
    return switch (target_info.os.tag) {
        .windows => LibraryNames{
            .spng = "spng_static",
            .jpeg = "turbojpeg",
            .tiff = "tiff",
        },
        else => LibraryNames{
            .spng = "spng_static", // vcpkg installs as libspng_static.a
            .jpeg = "turbojpeg", // vcpkg installs libturbojpeg.a and libjpeg.a
            .tiff = "tiff", // vcpkg installs as libtiff.a
        },
    };
}
