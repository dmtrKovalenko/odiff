const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqRel = testing.expectApproxEqRel;

const odiff = @import("root.zig");
const image_io = odiff.image_io;
const diff = odiff.diff;
const color_delta = odiff.color_delta;

fn loadTestImage(path: []const u8, allocator: std.mem.Allocator) !image_io.Image {
    return image_io.loadImage(path, allocator) catch |err| {
        std.debug.print("Failed to load image: {s}\nError: {}\n", .{ path, err });
        return err;
    };
}

test "layoutDifference: diff images with different layouts without capture" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/white4x4.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/purple8x8.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{
        .antialiasing = false,
        .output_diff_mask = false,
        .capture_diff = false,
        .enable_asm = true,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 16), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 100.0), diff_percentage, 0.001); // diffPercentage
}

test "PNG: finds difference between 2 images without capture" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{
        .capture_diff = false,
        .enable_asm = true,
    };
    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 1366), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 1.14), diff_percentage, 0.1); // diffPercentage
}
