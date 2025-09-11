const std = @import("std");
const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dynamic = b.option(bool, "dynamic", "Link against libspng, libjpeg and libtiff dynamically") orelse false;

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    linkDeps(b, target, optimize, dynamic, lib_mod);

    var c_flags = std.array_list.Managed([]const u8).init(b.allocator);
    defer c_flags.deinit();
    c_flags.append("-std=c99") catch @panic("OOM");
    c_flags.append("-Wno-nullability-completeness") catch @panic("OOM");
    c_flags.append("-DHAVE_SPNG") catch @panic("OOM");
    c_flags.append("-DSPNG_STATIC") catch @panic("OOM");
    c_flags.append("-DSPNG_SSE=3") catch @panic("OOM");
    c_flags.append("-DHAVE_JPEG") catch @panic("OOM");
    c_flags.append("-DHAVE_TIFF") catch @panic("OOM");

    lib_mod.addCSourceFiles(.{
        .files = &.{
            "c_bindings/odiff_io.c",
        },
        .flags = c_flags.items,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("odiff_lib", lib_mod);

    const options = b.addOptions();
    options.addOption([]const u8, "version", manifest.version);
    exe_mod.addImport("build_options", options.createModule());
    lib_mod.addImport("build_options", options.createModule());

    const exe = b.addExecutable(.{
        .name = "odiff",
        .root_module = exe_mod,
    });

    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target.result.cpu.arch != native_target.result.cpu.arch or
        target.result.os.tag != native_target.result.os.tag;

    // configurePlatformLibraries(b, exe, target.result, &have_spng, &have_jpeg, &have_tiff) catch |err| {
    //     if (is_cross_compiling) {
    //         std.log.err("Build failed: {}", .{err});
    //         @panic("Cross-compilation requires proper vcpkg setup");
    //     } else {
    //         std.log.warn("Could not detect all image libraries, using fallback configuration", .{});
    //     }
    // };

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const integration_tests_with_io = [_][]const u8{
        "src/test_core.zig",
        "src/test_io_png.zig",
        "src/test_io_bmp.zig",
        "src/test_io_jpg.zig",
        "src/test_io_tiff.zig",
    };

    const integration_tests_pure_zig = [_][]const u8{
        "src/test_color_delta.zig",
    };

    var integration_test_steps = std.array_list.Managed(*std.Build.Step.Run).init(b.allocator);
    defer integration_test_steps.deinit();

    if (!is_cross_compiling) {
        for (integration_tests_with_io) |test_path| {
            const integration_test = b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path(test_path),
                    .target = target,
                    .optimize = optimize,
                }),
            });

            integration_test.linkLibC();

            integration_test.addCSourceFiles(.{
                .files = &.{
                    "c_bindings/odiff_io.c",
                },
                .flags = c_flags.items,
            });

            var test_have_spng = false;
            var test_have_jpeg = false;
            var test_have_tiff = false;
            configurePlatformLibraries(b, integration_test, target.result, &test_have_spng, &test_have_jpeg, &test_have_tiff) catch {
                std.log.warn("Could not configure libraries for integration test: {s}", .{test_path});
            };

            const run_integration_test = b.addRunArtifact(integration_test);
            integration_test_steps.append(run_integration_test) catch @panic("OOM");
        }

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

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const integration_test_step = b.step("test-integration", "Run integration tests with test images");
    for (integration_test_steps.items) |test_run_step| {
        integration_test_step.dependOn(&test_run_step.step);
    }

    const test_all_step = b.step("test-all", "Run both unit and integration tests");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(integration_test_step);
}

pub fn linkDeps(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, dynamic: bool, module: *std.Build.Module) void {
    const host_target = b.graph.host.result;
    const build_target = target.result;
    const is_cross_compiling = host_target.cpu.arch != build_target.cpu.arch or
        host_target.os.tag != build_target.os.tag;
    if (dynamic and !is_cross_compiling) {
        switch (build_target.os.tag) {
            .windows => {
                std.log.warn("Dynamic linking is not supported on Windows, falling back to static linking", .{});
                return linkDeps(b, target, optimize, false, module);
            },
            else => {
                module.linkSystemLibrary("spng", .{});
                module.linkSystemLibrary("jpeg", .{});
                module.linkSystemLibrary("tiff", .{});
            },
        }
    } else {
        const libspng = getSpng(b, target, optimize);
        const libjpeg_dep = b.dependency("libjpeg_turbo", .{
            .target = target,
            .optimize = optimize,
        });
        const libjpeg = libjpeg_dep.artifact("jpeg");
        const libtiff_dep = b.dependency("libtiff", .{
            .target = target,
            .optimize = optimize,
            .has_libjpeg = true,
        });
        const libtiff = libtiff_dep.artifact("tiff");
        libtiff.linkLibrary(libjpeg);

        module.linkLibrary(libspng);
        module.linkLibrary(libjpeg);
        module.linkLibrary(libtiff);
    }
}

fn getSpng(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });
    const spng_dep = b.dependency("spng", .{});

    const spng_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    spng_mod.addCSourceFiles(.{
        .files = &.{"spng.c"},
        .flags = &.{"-std=c99"},
        .root = spng_dep.path("spng"),
    });
    spng_mod.linkLibrary(zlib_dep.artifact("z"));

    const spng_lib = b.addLibrary(.{
        .name = "spng",
        .root_module = spng_mod,
    });
    spng_lib.installHeader(spng_dep.path("spng/spng.h"), "spng.h");
    return spng_lib;
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

        if (target_info.os.tag == .linux) {
            lib.linkLibC();
            lib.linkSystemLibrary("m");
            lib.linkSystemLibrary("pthread");
            lib.linkSystemLibrary("dl");
        }
        return;
    }

    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target_info.cpu.arch != native_target.result.cpu.arch or
        target_info.os.tag != native_target.result.os.tag;

    if (is_cross_compiling) {
        std.log.err("Cross-compilation requires vcpkg libraries. Target: {s}-{s}", .{ @tagName(target_info.cpu.arch), @tagName(target_info.os.tag) });
        std.log.err("Make sure VCPKG_ROOT is set and libraries are installed for the target.", .{});
        return error.CrossCompilationRequiresVcpkg;
    }

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
    const vcpkg_root = std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            std.log.info("VCPKG_ROOT not found, libraries may need to be installed manually", .{});
            return;
        },
        else => return err,
    };
    defer b.allocator.free(vcpkg_root);

    const vcpkg_installed = std.fmt.allocPrint(b.allocator, "{s}/installed/x64-windows", .{vcpkg_root}) catch return;
    defer b.allocator.free(vcpkg_installed);

    const include_path = std.fmt.allocPrint(b.allocator, "{s}/include", .{vcpkg_installed}) catch return;
    defer b.allocator.free(include_path);
    const lib_path = std.fmt.allocPrint(b.allocator, "{s}/lib", .{vcpkg_installed}) catch return;
    defer b.allocator.free(lib_path);

    lib.addIncludePath(.{ .cwd_relative = include_path });
    lib.addLibraryPath(.{ .cwd_relative = lib_path });

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
    const target_info = lib.root_module.resolved_target.?.result;
    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target_info.cpu.arch != native_target.result.cpu.arch or
        target_info.os.tag != native_target.result.os.tag;

    if (is_cross_compiling) {
        std.log.info("Cross-compiling macOS target, skipping system library paths", .{});
        return error.CrossCompilationNotSupported;
    }

    lib.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    lib.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });

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
    if (tryPkgConfig(b, lib, "libspng")) {
        have_spng.* = true;
    } else {
        lib.linkSystemLibrary("spng");
        have_spng.* = true;
    }

    if (tryPkgConfig(b, lib, "libjpeg")) {
        have_jpeg.* = true;
    } else {
        lib.linkSystemLibrary("jpeg");
        have_jpeg.* = true;
    }

    if (tryPkgConfig(b, lib, "libtiff-4")) {
        have_tiff.* = true;
    } else {
        lib.linkSystemLibrary("tiff");
        have_tiff.* = true;
    }
}

fn tryPkgConfig(b: *std.Build, lib: *std.Build.Step.Compile, package: []const u8) bool {
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
    const vcpkg_root = std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch {
        return false;
    };
    defer b.allocator.free(vcpkg_root);

    const vcpkg_triplet = getVcpkgTriplet(target_info) catch {
        return false;
    };
    defer std.heap.page_allocator.free(vcpkg_triplet);

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

    const lib_names = getLibraryNames(target_info);

    lib.linkSystemLibrary(lib_names.spng);
    have_spng.* = true;

    lib.linkSystemLibrary(lib_names.jpeg);
    have_jpeg.* = true;

    lib.linkSystemLibrary(lib_names.tiff);
    have_tiff.* = true;

    if (target_info.os.tag == .windows) {
        lib.linkSystemLibrary("zlib");
        lib.linkSystemLibrary("lzma");
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
        .windows => "mingw",
        .linux => "linux",
        .macos => "osx",
        .freebsd => "freebsd",
        else => return error.UnsupportedOS,
    };

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
            .spng = "spng_static",
            .jpeg = "turbojpeg",
            .tiff = "tiff",
        },
    };
}
