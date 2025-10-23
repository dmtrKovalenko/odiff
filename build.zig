const std = @import("std");
const manifest = @import("build.zig.zon");
const Imgz = @import("imgz");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dynamic = b.option(bool, "dynamic", "Link against libspng, libjpeg and libtiff dynamically") orelse false;

    const odiff_mod, const exe = makeOdiff(b, .{
        .target = target,
        .optimize = optimize,
        .dynamic = dynamic,
    });
    b.installArtifact(exe);

    // const lib = b.addLibrary(.{
    //     .name = "odiff",
    //     .linkage = .static,
    //     .root_module = odiff_mod,
    // });
    // b.installArtifact(lib);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_files: []const []const u8 = &.{
        "src/test_color_delta.zig",
        "src/test_io.zig",
        "src/test_core.zig",
        "src/test_avx.zig",
    };
    const test_step = b.step("test", "Run unit tests");
    for (test_files) |test_file_path| {
        const test_exe = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file_path),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "odiff", .module = odiff_mod },
                },
            }),
        });
        const run_test_exe = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test_exe.step);
    }

    const build_ci_step = b.step("ci", "Build the app for CI");
    for (build_targets) |target_query| {
        const t = b.resolveTargetQuery(target_query);
        var target_name = try target_query.zigTriple(b.allocator);
        if (target_query.cpu_arch == .riscv64 and !target_query.cpu_features_add.isEmpty())
            target_name = try std.mem.join(b.allocator, "-", &[_][]const u8{ target_name, "rva23" });

        const mod, const odiff_exe = makeOdiff(b, .{
            .target = t,
            .optimize = optimize,
            .dynamic = dynamic,
        });
        odiff_exe.root_module.strip = true;

        const odiff_bin_output = b.addInstallArtifact(odiff_exe, .{
            .dest_dir = .{
                .override = .{ .custom = target_name },
            },
        });
        build_ci_step.dependOn(&odiff_bin_output.step);

        _ = mod;
        // const odiff_lib = b.addLibrary(.{
        //     .name = "odiff",
        //     .linkage = .static,
        //     .root_module = mod,
        // });
        // const odiff_lib_output = b.addInstallArtifact(odiff_lib, .{
        //     .dest_dir = .{
        //         .override = .{ .custom = target_name },
        //     },
        // });
        // build_ci_step.dependOn(&odiff_lib_output.step);
    }
}

const OdiffBuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dynamic: bool,
};
fn makeOdiff(b: *std.Build, options: OdiffBuildOptions) struct { *std.Build.Module, *std.Build.Step.Compile } {
    const target = options.target;
    const optimize = options.optimize;
    const dynamic = options.dynamic;

    const image_mod = b.createModule(.{
        .root_source_file = b.path("src/image/image.zig"),
        .target = target,
        .optimize = optimize,
    });

    const io_mod = b.createModule(.{
        .root_source_file = b.path("src/io/io.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "image", .module = image_mod },
        },
    });
    linkImageDeps(b, target, optimize, dynamic, io_mod);

    const module = b.createModule(.{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "io", .module = io_mod },
            .{ .name = "image", .module = image_mod },
        },
    });

    // riscv vector version
    module.addCSourceFile(.{
        .file = b.path("src/lib/rvv.c"),
        .flags = &.{"-std=c99"},
    });

    // avx version
    if (target.result.cpu.arch == .x86_64) {
        const os_tag = target.result.os.tag;
        const fmt: ?[]const u8 = switch (os_tag) {
            .linux => "elf64",
            .macos => "macho64",
            else => null,
        };

        if (fmt) |nasm_fmt| {
            const nasm = b.addSystemCommand(&.{ "nasm", "-f", nasm_fmt, "-o" });
            const asm_obj = nasm.addOutputFileArg("vxdiff.o");
            nasm.addFileArg(b.path("src/lib/vxdiff.asm"));
            module.addObjectFile(asm_obj);
        }
    }

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", manifest.version);
    const exe = b.addExecutable(.{
        .name = "odiff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "odiff", .module = module },
                .{ .name = "build_options", .module = build_options.createModule() },
            },
        }),
    });

    return .{ module, exe };
}

pub fn linkImageDeps(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, dynamic: bool, module: *std.Build.Module) void {
    const host_target = b.graph.host.result;
    const build_target = target.result;
    const is_cross_compiling = host_target.cpu.arch != build_target.cpu.arch or
        host_target.os.tag != build_target.os.tag;
    const can_link_dynamically = switch (build_target.os.tag) {
        .windows => false,
        else => is_cross_compiling,
    };

    if (dynamic and !can_link_dynamically) {
        std.log.warn("Dynamic linking is not supported for this target, falling back to static linking", .{});
    } else if (dynamic) {
        module.linkSystemLibrary("spng", .{});
        module.linkSystemLibrary("jpeg", .{});
        module.linkSystemLibrary("tiff", .{});
        module.linkSystemLibrary("webp", .{});
    } else {
        Imgz.addToModule(b, module, .{
            .target = target,
            .optimize = optimize,
            .jpeg_turbo = .{},
            .spng = .{},
            .tiff = .{},
            .webp = .{},
        }) catch @panic("Failed to link required dependencies, please create an issue on the repo :)");
    }
}

const build_targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .riscv64, .os_tag = .linux },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .cpu_features_add = std.Target.riscv.featureSet(&.{std.Target.riscv.Feature.rva23u64}) },
};
