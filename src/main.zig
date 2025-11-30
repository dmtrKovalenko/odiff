const std = @import("std");
const lib = @import("odiff_lib");
const server = @import("server.zig");

const print = std.debug.print;

const cli = lib.cli;
const io = lib.io;
const diff = lib.diff;

// we need a large stdout for the lines parsable output
var stdout_buffer: [4096]u8 = undefined;

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args = cli.parseArgs(allocator) catch |err| switch (err) {
        error.OutOfMemory => {
            print("Error: Out of memory\n", .{});
            std.process.exit(1);
        },
        else => {
            print("Error: Failed to parse arguments\n", .{});
            std.process.exit(1);
        },
    };
    defer args.deinit();

    if (args.server_mode) {
        return try server.runServerMode(allocator);
    }

    // Load images with color decoding strategy based on threshold
    const strategy = io.ColorDecodingStrategy.fromThreshold(args.threshold);
    const load_result = io.loadTwoImages(allocator, args.base_image, args.comp_image, strategy);
    const images = switch (load_result) {
        .ok => |imgs| imgs,
        .err => |load_err| switch (load_err) {
            .base_failed => |err| {
                print("Error: Could not load base image: {s}\n", .{args.base_image});
                if (err == error.ImageNotLoaded) {
                    // File not found
                } else if (err == error.UnsupportedFormat) {
                    print("Error: Unsupported image format\n", .{});
                }
                std.process.exit(1);
            },
            .compare_failed => |err| {
                print("Error: Could not load comparison image: {s}\n", .{args.comp_image});
                if (err == error.ImageNotLoaded) {
                    // File not found
                } else if (err == error.UnsupportedFormat) {
                    print("Error: Unsupported image format\n", .{});
                }
                std.process.exit(1);
            },
            .thread_spawn_failed => |err| {
                print("Error: Failed to spawn thread: {s}\n", .{@errorName(err)});
                std.process.exit(1);
            },
        },
    };
    var base_img = images.base;
    defer base_img.deinit(allocator);
    var comp_img = images.compare;
    defer comp_img.deinit(allocator);

    const diff_pixel = cli.parseHexColor(args.diff_color) catch {
        print("Error: Invalid hex color format\n", .{});
        std.process.exit(1);
    };

    const diff_options = diff.DiffOptions{
        .output_diff_mask = args.diff_mask,
        .diff_overlay_factor = args.diff_overlay_factor,
        .threshold = args.threshold,
        .diff_pixel = diff_pixel,
        .fail_on_layout_change = args.fail_on_layout,
        .antialiasing = args.antialiasing,
        .diff_lines = args.diff_lines,
        .ignore_regions = args.ignore_regions.items,
        .capture_diff = args.diff_output != null,
        .enable_asm = args.enable_asm,
    };

    const result = diff.diff(&base_img, &comp_img, diff_options, allocator) catch |err| {
        print("Error: Failed to perform diff: {}\n", .{err});
        std.process.exit(1);
    };

    switch (result) {
        .layout => {
            if (args.parsable_stdout) {
                stdout.print("layout\n", .{}) catch {};
            } else {
                print("Images have different dimensions\n", .{});
            }

            try stdout.flush();
            std.process.exit(21);
        },
        .pixel => |pixel_result| {
            defer {
                if (pixel_result.diff_output) |*output| {
                    var img = output.*;
                    img.deinit(allocator);
                }
                if (pixel_result.diff_lines) |lines| {
                    var mutable_lines = lines;
                    mutable_lines.deinit();
                }
            }

            if (pixel_result.diff_count == 0) {
                if (args.parsable_stdout) {
                    stdout.print("0\n", .{}) catch {};
                } else {
                    print("Images are identical\n", .{});
                }

                try stdout.flush();
                std.process.exit(0);
            } else {
                // Save diff output if requested
                if (args.diff_output) |output_path| {
                    if (pixel_result.diff_output) |output_img| {
                        io.saveImage(output_img, output_path) catch {
                            print("Error: Failed to save diff output\n", .{});
                            try stdout.flush();

                            std.process.exit(1);
                        };
                    }
                }

                if (args.parsable_stdout) {
                    stdout.print("{d};{:.2}", .{ pixel_result.diff_count, pixel_result.diff_percentage }) catch {};
                    if (pixel_result.diff_lines) |diff_lines| {
                        if (diff_lines.count > 0) {
                            stdout.print(";", .{}) catch {};
                            for (diff_lines.getItems(), 0..) |line, i| {
                                if (i > 0) stdout.print(",", .{}) catch {};
                                stdout.print("{d}", .{line}) catch {};
                            }
                        }
                    }
                    stdout.print("\n", .{}) catch {};
                } else {
                    print("Found {d} different pixels ({:.2}%)\n", .{ pixel_result.diff_count, pixel_result.diff_percentage });
                    if (args.diff_lines) {
                        if (pixel_result.diff_lines) |diff_lines| {
                            if (diff_lines.count > 0) {
                                print("Different lines: ", .{});
                                for (diff_lines.getItems(), 0..) |line, i| {
                                    if (i > 0) print(", ", .{});
                                    print("{d}", .{line});
                                }
                                print("\n", .{});
                            }
                        }
                    }
                }

                try stdout.flush();
                std.process.exit(22);
            }
        },
    }
}
