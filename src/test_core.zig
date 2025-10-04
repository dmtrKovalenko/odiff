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

test "antialiasing: does not count anti-aliased pixels as different" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/aa/antialiasing-on.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/aa/antialiasing-off.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{
        .antialiasing = true,
        .output_diff_mask = false,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 38), diff_count);
    try expectApproxEqRel(@as(f64, 0.095), diff_percentage, 0.001);
}

test "antialiasing: tests different sized AA images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/aa/antialiasing-on.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/aa/antialiasing-off-small.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{
        .antialiasing = true,
        .output_diff_mask = true,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 417), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 1.0425), diff_percentage, 0.01); // diffPercentage
}

test "threshold: uses provided threshold" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{
        .threshold = 0.5,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 25), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 0.020948550360315066), diff_percentage, 0.001); // diffPercentage - Zig implementation value
}

test "ignore regions: uses provided ignore regions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit();

    const ignore_regions = [_]diff.IgnoreRegion{
        .{ .x1 = 150, .y1 = 30, .x2 = 310, .y2 = 105 },
        .{ .x1 = 20, .y1 = 175, .x2 = 105, .y2 = 200 },
    };

    const options = diff.DiffOptions{
        .ignore_regions = &ignore_regions,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 0), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 0.0), diff_percentage, 0.001); // diffPercentage
}

test "diff color: creates diff output image with custom green diff color" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit();

    const green_pixel: u32 = 4278255360; // #00ff00 in int32 representation

    const options = diff.DiffOptions{
        .diff_pixel = green_pixel,
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    _ = diff_count;
    _ = diff_percentage;

    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expect(diff_output != null); // diffOutput should exist

    if (diff_output) |*diff_output_img| {
        var original_diff = try loadTestImage("test/png/orange_diff_green.png", allocator);
        defer original_diff.deinit();

        const compare_options = diff.DiffOptions{};
        var nested_diff_output, const nested_diff_count, const nested_diff_percentage, var nested_diff_lines = try diff.compare(&original_diff, diff_output_img, compare_options, allocator);
        defer if (nested_diff_output) |*img| img.deinit();
        defer if (nested_diff_lines) |*lines| lines.deinit();

        try expect(nested_diff_output != null); // diffMaskOfDiff should exist

        // If there are differences, save debug images
        if (nested_diff_count > 0) {
            try image_io.saveImage(diff_output_img, "test/png/diff-output-green.png", allocator);
            if (nested_diff_output) |*diff_mask| {
                try image_io.saveImage(diff_mask, "test/png/diff-of-diff-green.png", allocator);
            }
        }

        try expectEqual(@as(u32, 0), nested_diff_count); // diffOfDiffPixels
        try expectApproxEqRel(@as(f64, 0.0), nested_diff_percentage, 0.001); // diffOfDiffPercentage
    }
}

test "blendSemiTransparentColor: blend semi-transparent colors" {
    const testBlend = struct {
        fn call(r: f64, g: f64, b: f64, a: f64, expected_r: f64, expected_g: f64, expected_b: f64, expected_a: f64) !void {
            const pixel = color_delta.Pixel{ .r = r, .g = g, .b = b, .a = a };
            const blended = color_delta.blendSemiTransparentPixel(pixel);

            try expectApproxEqRel(expected_r, blended.r, 0.01);
            try expectApproxEqRel(expected_g, blended.g, 0.01);
            try expectApproxEqRel(expected_b, blended.b, 0.01);
            try expectApproxEqRel(expected_a, blended.a, 0.01);
        }
    }.call;

    try testBlend(0.0, 128.0, 255.0, 255.0, 0.0, 128.0, 255.0, 1.0);
    try testBlend(0.0, 128.0, 255.0, 0.0, 255.0, 255.0, 255.0, 0.0);
    try testBlend(0.0, 128.0, 255.0, 5.0, 250.0, 252.51, 255.0, 0.0196078431372549); // Mathematically correct value
    try testBlend(0.0, 128.0, 255.0, 51.0, 204.0, 229.6, 255.0, 0.2);
    try testBlend(0.0, 128.0, 255.0, 128.0, 127.0, 191.25, 255.0, 0.5);
}

test "layoutDifference: diff images with different layouts" {
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
    };

    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 16), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 100.0), diff_percentage, 0.001); // diffPercentage
}
