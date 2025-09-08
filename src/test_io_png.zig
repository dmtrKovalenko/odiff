const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqRel = testing.expectApproxEqRel;

const odiff = @import("root.zig");
const image_io = odiff.image_io;
const diff = odiff.diff;

// Helper function to load test images
fn loadTestImage(path: []const u8, allocator: std.mem.Allocator) !image_io.Image {
    return image_io.loadImage(path, allocator) catch |err| {
        std.debug.print("Failed to load image: {s}\nError: {}\n", .{ path, err });
        return err;
    };
}

test "PNG: finds difference between 2 images" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{};
    var diff_output, const diff_count, const diff_percentage, var diff_lines = try diff.compare(&img1, &img2, options, allocator);
    defer if (diff_output) |*img| img.deinit();
    defer if (diff_lines) |*lines| lines.deinit();

    try expectEqual(@as(u32, 1366), diff_count); // diffPixels
    try expectApproxEqRel(@as(f64, 1.14), diff_percentage, 0.1); // diffPercentage
}

test "PNG: Diff of mask and no mask are equal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2.deinit();

    // Test without mask
    const options_no_mask = diff.DiffOptions{
        .output_diff_mask = false,
    };
    var diff_output_no_mask, const diff_count_no_mask, const diff_percentage_no_mask, var diff_lines_no_mask = try diff.compare(&img1, &img2, options_no_mask, allocator);
    defer if (diff_output_no_mask) |*img| img.deinit();
    defer if (diff_lines_no_mask) |*lines| lines.deinit();

    // Test with mask
    var img1_copy = try loadTestImage("test/png/orange.png", allocator);
    defer img1_copy.deinit();

    var img2_copy = try loadTestImage("test/png/orange_changed.png", allocator);
    defer img2_copy.deinit();

    const options_with_mask = diff.DiffOptions{
        .output_diff_mask = true,
    };
    var diff_output_with_mask, const diff_count_with_mask, const diff_percentage_with_mask, var diff_lines_with_mask = try diff.compare(&img1_copy, &img2_copy, options_with_mask, allocator);
    defer if (diff_output_with_mask) |*img| img.deinit();
    defer if (diff_lines_with_mask) |*lines| lines.deinit();

    try expectEqual(diff_count_no_mask, diff_count_with_mask); // diffPixels should be equal
    try expectApproxEqRel(diff_percentage_no_mask, diff_percentage_with_mask, 0.001); // diffPercentage should be equal
}

test "PNG: Creates correct diff output image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/orange.png", allocator);
    defer img1.deinit();
    var img2 = try loadTestImage("test/png/orange_changed.png", allocator);
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
        var original_diff = try loadTestImage("test/png/orange_diff.png", allocator);
        defer original_diff.deinit();

        const compare_options = diff.DiffOptions{};
        var nested_diff_output, const nested_diff_count, const nested_diff_percentage, var nested_diff_lines = try diff.compare(&original_diff, diff_output_img, compare_options, allocator);
        defer if (nested_diff_output) |*img| img.deinit();
        defer if (nested_diff_lines) |*lines| lines.deinit();

        try expect(nested_diff_output != null); // diffMaskOfDiff should exist

        // If there are differences, save debug images
        if (nested_diff_count > 0) {
            try image_io.saveImage(diff_output_img, "test/png/diff-output.png", allocator);
            if (nested_diff_output) |*diff_mask| {
                try image_io.saveImage(diff_mask, "test/png/diff-of-diff.png", allocator);
            }
        }

        try expectEqual(@as(u32, 0), nested_diff_count); // diffOfDiffPixels
        try expectApproxEqRel(@as(f64, 0.0), nested_diff_percentage, 0.001); // diffOfDiffPercentage
    }
}

test "PNG: Correctly handles different encodings of transparency" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img1 = try loadTestImage("test/png/extreme-alpha.png", allocator);
    defer img1.deinit();

    var img2 = try loadTestImage("test/png/extreme-alpha-1.png", allocator);
    defer img2.deinit();

    const options = diff.DiffOptions{};
    const diff_output, const diff_count, const diff_percentage, const diff_lines = try diff.compare(&img1, &img2, options, allocator);
    _ = diff_percentage;
    defer if (diff_output) |img| {
        var mut_img = img;
        mut_img.deinit();
    };
    defer if (diff_lines) |lines| {
        var mut_lines = lines;
        mut_lines.deinit();
    };

    try expectEqual(@as(u32, 0), diff_count); // diffPixels should be 0
}
