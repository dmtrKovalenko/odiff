const std = @import("std");
const manifest = @import("build.zig.zon");
const Imgz = @import("imgz");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dynamic = b.option(bool, "dynamic", "Link against libspng, libjpeg and libtiff dynamically") orelse false;

    const native_target = b.resolveTargetQuery(.{});
    const is_cross_compiling = target.result.cpu.arch != native_target.result.cpu.arch or
        target.result.os.tag != native_target.result.os.tag;

    const lib_mod, const exe = buildOdiff(b, target, optimize, dynamic);
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
        const root_lib = b.addLibrary(.{
            .name = "odiff_lib",
            .root_module = lib_mod,
        });
        for (integration_tests_with_io) |test_path| {
            const integration_test = b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path(test_path),
                    .target = target,
                    .optimize = optimize,
                }),
            });
            integration_test.linkLibC();
            integration_test.linkLibrary(root_lib);
            linkDeps(b, target, optimize, false, integration_test.root_module);

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

    const build_ci_step = b.step("ci", "Build the app for CI");
    for (build_targets) |target_query| {
        const t = b.resolveTargetQuery(target_query);
        _, const odiff_exe = buildOdiff(b, t, optimize, dynamic);
        odiff_exe.root_module.strip = true;
        const odiff_output = b.addInstallArtifact(odiff_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = try target_query.zigTriple(b.allocator),
                },
            },
        });
        build_ci_step.dependOn(&odiff_output.step);
    }
}

fn buildOdiff(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dynamic: bool,
) struct { *std.Build.Module, *std.Build.Step.Compile } {
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

    return .{ lib_mod, exe };
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
        const imgz = Imgz.get(b, .{
            .target = target,
            .optimize = optimize,
            .jpeg_turbo = .{},
            .spng = .{},
            .tiff = .{},
        }) catch @panic("Failed to link required dependencies, please create an issue on the repo :)");
        module.linkLibrary(imgz);
    }
}

const build_targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};
