const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqRel = testing.expectApproxEqRel;

const odiff = @import("root.zig");
const io = odiff.io;
const diff = odiff.diff;
const color_delta = odiff.color_delta;

fn loadTestImage(path: []const u8, allocator: std.mem.Allocator) !io.Image {
    return io.loadImage(allocator, path, .precise) catch |err| {
        std.debug.print("Failed to load image: {s}\nError: {}\n", .{ path, err });
        return err;
    };
}

test "layoutDifference: diff images with different layouts without capture" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/white4x4.png", allocator);
    defer img1.deinit(allocator);

    var img2 = try loadTestImage("test/png/purple8x8.png", allocator);
    defer img2.deinit(allocator);

    const options = diff.DiffOptions{
        .antialiasing = false,
        .output_diff_mask = false,
        .capture_diff = false,
        .enable_asm = true,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines, _ = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit(allocator);
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 64), diff_count); // diffPixels - includes extra comp pixels
    try expectApproxEqRel(@as(f64, 100.0), diff_percentage, 0.001); // diffPercentage - 64/max(4,8)^2
}

test "PNG: finds difference between 2 images without capture" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit(allocator);

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit(allocator);

    const options = diff.DiffOptions{
        .capture_diff = false,
        .enable_asm = true,
    };
    var diff_output, const diff_count, const diff_percentage, var diff_lines, _ = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit(allocator);
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 1366), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 1.14), diff_percentage, 0.1); // diffPercentage
}

fn rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    return @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16) | (@as(u32, a) << 24);
}

fn makeImage(allocator: std.mem.Allocator, width: u32, height: u32, pixels: []const u32) !io.Image {
    std.debug.assert(width * height == pixels.len);
    const data = try allocator.dupe(u32, pixels);
    return io.Image{
        .data = data.ptr,
        .len = data.len,
        .width = width,
        .height = height,
    };
}

fn expectAsmMatchesScalar(allocator: std.mem.Allocator, width: u32, height: u32, pixels1: []const u32, pixels2: []const u32, expected: u32) !void {
    if (!diff.HAS_VXDIFF_ASM) return error.SkipZigTest;

    var img1 = try makeImage(allocator, width, height, pixels1);
    defer img1.deinit(allocator);

    var img2 = try makeImage(allocator, width, height, pixels2);
    defer img2.deinit(allocator);

    var asm_count: u32 = 0;
    try diff.compareAVX(&img1, &img2, &asm_count);

    const options = diff.DiffOptions{
        .capture_diff = false,
    };
    var diff_output, const scalar_count, _, var diff_lines, _ = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit(allocator);
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(expected, scalar_count);
    try expectEqual(scalar_count, asm_count);
}

test "transparent pixel does not affect diff of neighbouring pixels" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // pixel 0 fully transparent in both images, pixel 1 black vs white
    try expectAsmMatchesScalar(allocator, 4, 1, &.{
        rgba(0, 0, 0, 0), rgba(0, 0, 0, 255), rgba(32, 64, 96, 255), rgba(96, 64, 32, 255),
    }, &.{
        rgba(0, 0, 0, 0), rgba(255, 255, 255, 255), rgba(32, 64, 96, 255), rgba(96, 64, 32, 255),
    }, 1);

    // transparent vs opaque black differs only in pixel 0
    try expectAsmMatchesScalar(allocator, 4, 1, &.{
        rgba(0, 0, 0, 0), rgba(5, 5, 5, 255), rgba(6, 6, 6, 255), rgba(7, 7, 7, 255),
    }, &.{
        rgba(0, 0, 0, 255), rgba(5, 5, 5, 255), rgba(6, 6, 6, 255), rgba(7, 7, 7, 255),
    }, 1);

    // same as the first case, but in the leftover path (width not divisible by 4):
    // pixel 4 fully transparent in both images, pixel 5 black vs white
    try expectAsmMatchesScalar(allocator, 7, 1, &.{
        rgba(1, 2, 3, 255), rgba(4, 5, 6, 255), rgba(7, 8, 9, 255), rgba(10, 11, 12, 255),
        rgba(0, 0, 0, 0),   rgba(0, 0, 0, 255), rgba(13, 14, 15, 255),
    }, &.{
        rgba(1, 2, 3, 255), rgba(4, 5, 6, 255), rgba(7, 8, 9, 255), rgba(10, 11, 12, 255),
        rgba(0, 0, 0, 0),   rgba(255, 255, 255, 255), rgba(13, 14, 15, 255),
    }, 1);
}
