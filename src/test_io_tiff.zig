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

const builtin = @import("builtin");
const skip_tiff_on_windows = builtin.os.tag == .windows;

test "TIFF: finds difference between 2 images" {
    if (skip_tiff_on_windows) {
        std.debug.print("Skipping TIFF tests on Windows systems\n", .{});
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/tiff/laptops.tiff", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/tiff/laptops-2.tiff", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{};
    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 8569), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 3.79), diff_percentage, 0.01); // diffPercentage
}

test "TIFF: Diff of mask and no mask are equal" {
    if (skip_tiff_on_windows) {
        std.debug.print("Skipping TIFF tests on Windows systems\n", .{});
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/tiff/laptops.tiff", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/tiff/laptops-2.tiff", allocator);
    defer img2.deinit();

    // Test without mask
    const options_no_mask = diff.DiffOptions{
        .output_diff_mask = false,
    };
    var no_mask_diff_output, const no_mask_diff_count, const no_mask_diff_percentage, var no_mask_diff_lines = try diff.compare(&img1, &img2, options_no_mask, allocator);
    defer if (no_mask_diff_output) |*img| img.deinit();
    defer if (no_mask_diff_lines) |*lines| lines.deinit();

    // Test with mask
    var img1_copy = try loadTestImage("test/tiff/laptops.tiff", allocator);
    defer img1_copy.deinit();

    var img2_copy = try loadTestImage("test/tiff/laptops-2.tiff", allocator);
    defer img2_copy.deinit();

    const options_with_mask = diff.DiffOptions{
        .output_diff_mask = true,
    };
    var mask_diff_output, const mask_diff_count, const mask_diff_percentage, var mask_diff_lines = try diff.compare(&img1_copy, &img2_copy, options_with_mask, allocator);
    defer if (mask_diff_output) |*img| img.deinit();
    defer if (mask_diff_lines) |*lines| lines.deinit();

    try expectEqual(no_mask_diff_count, mask_diff_count); // diffPixels should be equal
    try expectApproxEqRel(no_mask_diff_percentage, mask_diff_percentage, 0.001); // diffPercentage should be equal
}

test "TIFF: Creates correct diff output image" {
    if (skip_tiff_on_windows) {
        std.debug.print("Skipping TIFF tests on Windows systems\n", .{});
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/tiff/laptops.tiff", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/tiff/laptops-2.tiff", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{};
    const diff_output, const diff_count, const diff_percentage, const diff_lines = try diff.compare(&img1, &img2, options, allocator);
    _ = diff_count;
    _ = diff_percentage;
    defer if (diff_output) |img| {
        var mut_img = img;
        mut_img.deinit();
    };
    defer if (diff_lines) |lines| {
        var mut_lines = lines;
        mut_lines.deinit();
    };

    try expect(diff_output != null); // diffOutput should exist

    if (diff_output) |*diff_output_img| {
        var original_diff = try loadTestImage("test/tiff/laptops-diff.png", allocator);
        defer original_diff.deinit();

        const compare_options = diff.DiffOptions{};
        var nested_diff_output, const nested_diff_count, const nested_diff_percentage, var nested_diff_lines = try diff.compare(&original_diff, diff_output_img, compare_options, allocator);
        defer if (nested_diff_output) |*img| img.deinit();
        defer if (nested_diff_lines) |*lines| lines.deinit();

        try expect(nested_diff_output != null); // diffMaskOfDiff should exist

        // If there are differences, save debug images
        if (nested_diff_count > 0) {
            // Note: We can only save as PNG currently, but that's fine for debug output
            try image_io.saveImage(diff_output_img, "test/tiff/_diff-output.png", allocator);
            if (nested_diff_output) |*diff_mask| {
                try image_io.saveImage(diff_mask, "test/tiff/_diff-of-diff.png", allocator);
            }
        }

        try expectEqual(@as(u32, 0), nested_diff_count); // diffOfDiffPixels
        try expectApproxEqRel(@as(f64, 0.0), nested_diff_percentage, 0.001); // diffOfDiffPercentage
    }
}
