const std = @import("std");
const lib = @import("odiff_lib");

const print = std.debug.print;

const cli = lib.cli;
const image_io = lib.image_io;
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

    // Load images
    var base_img = image_io.loadImage(args.base_image, allocator) catch |err| switch (err) {
        error.ImageNotLoaded => {
            print("Error: Could not load base image: {s}\n", .{args.base_image});
            std.process.exit(1);
        },
        error.UnsupportedFormat => {
            print("Error: Unsupported image format: {s}\n", .{args.base_image});
            std.process.exit(1);
        },
        else => {
            print("Error: Failed to load base image\n", .{});
            std.process.exit(1);
        },
    };
    defer base_img.deinit();

    var comp_img = image_io.loadImage(args.comp_image, allocator) catch |err| switch (err) {
        error.ImageNotLoaded => {
            print("Error: Could not load comparison image: {s}\n", .{args.comp_image});
            std.process.exit(1);
        },
        error.UnsupportedFormat => {
            print("Error: Unsupported image format: {s}\n", .{args.comp_image});
            std.process.exit(1);
        },
        else => {
            print("Error: Failed to load comparison image\n", .{});
            std.process.exit(1);
        },
    };
    defer comp_img.deinit();

    const diff_pixel = cli.parseHexColor(args.diff_color) catch {
        print("Error: Invalid hex color format\n", .{});
        std.process.exit(1);
    };

    const diff_options = diff.DiffOptions{
        .output_diff_mask = args.diff_mask,
        .threshold = args.threshold,
        .diff_pixel = diff_pixel,
        .fail_on_layout_change = args.fail_on_layout,
        .antialiasing = args.antialiasing,
        .diff_lines = args.diff_lines,
        .ignore_regions = args.ignore_regions.items,
        .capture_diff = args.diff_output != null,
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
                    img.deinit();
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
                        image_io.saveImage(&output_img, output_path, allocator) catch {
                            print("Error: Failed to save diff output\n", .{});
                            try stdout.flush();

                            std.process.exit(1);
                        };
                    }
                }

                if (args.parsable_stdout) {
                    stdout.print("{d}\n", .{pixel_result.diff_count}) catch {};
                    if (pixel_result.diff_lines) |diff_lines| {
                        if (diff_lines.count > 0) {
                            for (diff_lines.getItems()) |line| {
                                stdout.print("{d}\n", .{line}) catch {};
                            }
                        }
                    }
                } else {
                    print("Found {d} different pixels ({d:.2}%)\n", .{ pixel_result.diff_count, pixel_result.diff_percentage });
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
