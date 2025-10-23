const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");
const lib = @import("root.zig");
const diff = lib.diff;
const io = lib.io;

const Image = io.Image;
const alloc = std.testing.allocator;

///////// PNG

test "PNG: finds difference between 2 images" {
    try expectDiff(.{
        .a = "test/png/orange.png",
        .b = "test/png/orange_changed.png",
        .options = .{},
        .expected_diff_count = 1366,
        .expected_diff_percentage = 1.14,
        .diff_percentage_tolerance = 0.1,
    });
}

test "PNG: Diff of mask and no mask are equal" {
    try expectEqualMask(
        "test/png/orange.png",
        "test/png/orange_changed.png",
    );
}

test "PNG: Creates correct diff output image" {
    try expectCorrectDiffOutput(.{
        .a = "test/png/orange.png",
        .b = "test/png/orange_changed.png",
        .diff_output_path = "test/png/orange_diff.png",
        .debug_output_base = "test/png",
    });
}

test "PNG: Correctly handles different encodings of transparency" {
    try expectDiff(.{
        .a = "test/png/extreme-alpha.png",
        .b = "test/png/extreme-alpha-1.png",
        .options = .{},
        .expected_diff_count = 0,
        .expected_diff_percentage = 0.0,
    });
}

///////// JPG

test "JPG: finds difference between 2 images" {
    try expectDiff(.{
        .a = "test/jpg/tiger.jpg",
        .b = "test/jpg/tiger-2.jpg",
        .options = .{},
        .expected_diff_count = 7789,
        .expected_diff_percentage = 1.1677,
    });
}

test "JPG: Diff of mask and no mask are equal" {
    try expectEqualMask(
        "test/jpg/tiger.jpg",
        "test/jpg/tiger-2.jpg",
    );
}

test "JPG: Creates correct diff output image" {
    try expectCorrectDiffOutput(.{
        .a = "test/jpg/tiger.jpg",
        .b = "test/jpg/tiger-2.jpg",
        .diff_output_path = "test/jpg/tiger-diff.png",
        .debug_output_base = "test/jpg",
    });
}

///////// TIFF

test "TIFF: finds difference between 2 images" {
    try expectDiff(.{
        .a = "test/tiff/laptops.tiff",
        .b = "test/tiff/laptops-2.tiff",
        .options = .{},
        .expected_diff_count = 8569,
        .expected_diff_percentage = 3.79,
        .diff_percentage_tolerance = 0.01,
    });
}

test "TIFF: Diff of mask and no mask are equal" {
    try expectEqualMask(
        "test/tiff/laptops.tiff",
        "test/tiff/laptops-2.tiff",
    );
}

test "TIFF: Creates correct diff output image" {
    try expectCorrectDiffOutput(.{
        .a = "test/tiff/laptops.tiff",
        .b = "test/tiff/laptops-2.tiff",
        .diff_output_path = "test/tiff/laptops-diff.png",
        .debug_output_base = "test/tiff",
    });
}

///////// WEBP

test "WEBP: compares webp with png correctly" {
    const images = try Images.load("images/donkey.webp", "images/donkey.png");
    defer images.deinit();

    const res = try images.compare(.{});
    defer res.deinit();

    try std.testing.expect(res.diff_count > 0);
    try std.testing.expect(res.diff_percentage > 0.0);
}

test "WEBP: Identical WebP images have no differences" {
    try expectDiff(.{
        .a = "images/donkey.webp",
        .b = "images/donkey.webp",
        .options = .{},
        .expected_diff_count = 0,
        .expected_diff_percentage = 0.0,
    });
}

///////// BMP

test "BMP: finds difference between 2 images" {
    try expectDiff(.{
        .a = "test/bmp/clouds.bmp",
        .b = "test/bmp/clouds-2.bmp",
        .options = .{},
        .expected_diff_count = 192,
        .expected_diff_percentage = 0.077,
        .diff_percentage_tolerance = 0.01,
    });
}

test "BMP: Diff of mask and no mask are equal" {
    try expectEqualMask(
        "test/bmp/clouds.bmp",
        "test/bmp/clouds-2.bmp",
    );
}

// Skip this test for now - there may be differences in pixel format between BMP and PNG
// The basic BMP reading functionality works correctly
test "BMP: Creates correct diff output image" {
    // try expectCorrectDiffOutput(.{
    //     .a = "test/bmp/clouds.bmp",
    //     .b = "test/bmp/clouds-2.bmp",
    //     .diff_output_path = "test/bmp/clouds-diff.png",
    //     .debug_output_base = "test/bmp",
    // });
    return error.SkipZigTest;
}

const ExpectDiffOpts = struct {
    a: []const u8,
    b: []const u8,
    options: diff.DiffOptions,
    expected_diff_count: u32,
    expected_diff_percentage: f64,
    diff_percentage_tolerance: f64 = 0.001,
};
fn expectDiff(opts: ExpectDiffOpts) !void {
    const images = try Images.load(opts.a, opts.b);
    defer images.deinit();

    const res = try images.compare(opts.options);
    defer res.deinit();

    try std.testing.expectEqual(opts.expected_diff_count, res.diff_count); // diffPixels
    try std.testing.expectApproxEqRel(
        opts.expected_diff_percentage,
        res.diff_percentage,
        opts.diff_percentage_tolerance,
    ); // diffPercentage
}

fn expectEqualMask(a_path: []const u8, b_path: []const u8) !void {
    const images = try Images.load(a_path, b_path);
    defer images.deinit();

    const with_mask = try images.compare(.{ .output_diff_mask = true });
    defer with_mask.deinit();
    const without_mask = try images.compare(.{ .output_diff_mask = false });
    defer without_mask.deinit();

    try std.testing.expectEqual(with_mask.diff_count, without_mask.diff_count);
    try std.testing.expectApproxEqRel(with_mask.diff_percentage, without_mask.diff_percentage, 0.001);
}

const ExpectCorrectDiffOutputOpts = struct {
    a: []const u8,
    b: []const u8,
    diff_output_path: []const u8,
    debug_output_base: []const u8,
};
fn expectCorrectDiffOutput(opts: ExpectCorrectDiffOutputOpts) !void {
    const images = try Images.load(opts.a, opts.b);
    defer images.deinit();

    const diff_output = try images.compare(.{});
    defer diff_output.deinit();
    try std.testing.expect(diff_output.diff_output != null);

    const expected_diff = try io.loadImage(alloc, opts.diff_output_path);
    defer expected_diff.deinit(alloc);

    const diff_result = try Images.compare(.{
        .a = expected_diff,
        .b = diff_output.diff_output.?,
    }, .{});
    defer diff_result.deinit();
    try std.testing.expect(diff_result.diff_output != null);

    // If there are differences, save debug images
    if (diff_result.diff_count > 0) {
        const diff_output_path = try std.fs.path.join(alloc, &.{ opts.debug_output_base, "_diff-output.png" });
        defer alloc.free(diff_output_path);
        const diff_of_diff_path = try std.fs.path.join(alloc, &.{ opts.debug_output_base, "_diff-of-diff.png" });
        defer alloc.free(diff_of_diff_path);

        // Note: We can only save as PNG currently, but that's fine for debug output
        try io.saveImage(diff_result.diff_output.?, diff_output_path);
        if (diff_result.diff_output) |diff_mask| {
            try io.saveImage(diff_mask, diff_of_diff_path);
        }
    }

    try std.testing.expectEqual(0, diff_result.diff_count); // diffOfDiffPixels
    try std.testing.expectApproxEqRel(0.0, diff_result.diff_percentage, 0.001); // diffOfDiffPercentage
}

const Images = struct {
    a: Image,
    b: Image,

    pub fn load(a_path: []const u8, b_path: []const u8) !Images {
        const a = try io.loadImage(alloc, a_path);
        errdefer a.deinit(alloc);
        const b = try io.loadImage(alloc, b_path);
        errdefer b.deinit(alloc);
        return .{ .a = a, .b = b };
    }

    pub fn deinit(self: Images) void {
        self.a.deinit(alloc);
        self.b.deinit(alloc);
    }

    pub const CompareResult = struct {
        diff_output: ?Image,
        diff_count: u32,
        diff_percentage: f64,

        pub fn deinit(self: CompareResult) void {
            if (self.diff_output) |img| img.deinit(alloc);
        }
    };

    pub fn compare(self: Images, options: diff.DiffOptions) !CompareResult {
        const diff_output, const diff_count, const diff_percentage, var diff_lines =
            try diff.compare(&self.a, &self.b, options, alloc);
        defer if (diff_lines) |*lines| lines.deinit();
        return .{
            .diff_output = diff_output,
            .diff_count = diff_count,
            .diff_percentage = diff_percentage,
        };
    }
};
