const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqRel = testing.expectApproxEqRel;

const odiff = @import("root.zig");
const image_io = odiff.image_io;
const diff = odiff.diff;

fn loadTestImage(path: []const u8, allocator: std.mem.Allocator) !image_io.Image {
    return image_io.loadImage(path, allocator) catch |err| {
        std.debug.print("Failed to load image: {s}\nError: {}\n", .{ path, err });
        return err;
    };
}

test "webp: loads webp image correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img = try loadTestImage("images/donkey.webp", allocator);
    defer img.deinit();

    try expectEqual(img.width, 1258);
    try expectEqual(img.height, 3054);
}

test "webp: compares webp with png correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var webp_img = try loadTestImage("images/donkey.webp", allocator);
    defer webp_img.deinit();

    var png_img = try loadTestImage("images/donkey.png", allocator);
    defer png_img.deinit();

    const options = diff.DiffOptions{};
    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&webp_img, &png_img, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    // These are actually different images, so diff_count should be > 0
    try expect(diff_count > 0);
    try expect(diff_percentage > 0.0);
}

test "webp: identical WebP images have no differences" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("images/donkey.webp", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("images/donkey.webp", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{};
    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 0), diff_count); // diffPixels should be 0
    try expectApproxEqRel(@as(f64, 0.0), diff_percentage, 0.001); // diffPercentage should be 0
}
