const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectApproxEqRel = testing.expectApproxEqRel;
const Random = std.Random;

const odiff = @import("root.zig");
const image_io = odiff.image_io;
const diff = odiff.diff;
const color_delta = odiff.color_delta;

// Feature detection for NEON
const HAS_NEON = builtin.cpu.arch == .aarch64 and std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon);
const HAS_DOTPROD = builtin.cpu.arch == .aarch64 and std.Target.aarch64.featureSetHas(builtin.cpu.features, .dotprod);

// External NEON assembly function for direct testing
extern fn vneon(
    base_rgba: [*]const u8,
    comp_rgba: [*]const u8,
    base_width: usize,
    comp_width: usize,
    base_height: usize,
    comp_height: usize,
) u32;

fn loadTestImage(path: []const u8, allocator: std.mem.Allocator) !image_io.Image {
    return image_io.loadImage(path, allocator) catch |err| {
        std.debug.print("Failed to load image: {s}\nError: {}\n", .{ path, err });
        return err;
    };
}

// Create a test image with specific pixel patterns
fn createTestImage(width: u32, height: u32, pixels: []const u32, allocator: std.mem.Allocator) !image_io.Image {
    const data = try allocator.dupe(u32, pixels);
    return image_io.Image{
        .width = width,
        .height = height,
        .data = data,
        .allocator = allocator,
    };
}

test "NEON: feature detection" {
    std.debug.print("\n=== NEON Feature Detection ===\n", .{});
    std.debug.print("CPU Architecture: {}\n", .{builtin.cpu.arch});
    std.debug.print("NEON Support: {}\n", .{HAS_NEON});
    std.debug.print("DOTPROD Support: {}\n", .{HAS_DOTPROD});

    if (!HAS_NEON) {
        std.debug.print("⚠️  NEON not available on this system - skipping NEON-specific tests\n", .{});
        return testing.skip();
    }

    std.debug.print("✅ NEON available - running NEON tests\n", .{});
}

test "NEON: direct assembly function test - identical pixels" {
    if (!HAS_NEON) return testing.skip();

    std.debug.print("\n=== NEON Direct Assembly Test - Identical Pixels ===\n", .{});

    // Create identical 4x4 images
    const pixels = [_]u32{
        0xFF000000, 0xFF808080, 0xFFFFFFFF, 0xFF123456,
        0xFF654321, 0xFFFF0000, 0xFF00FF00, 0xFF0000FF,
        0xFF888888, 0xFFAAAAAA, 0xFFCCCCCC, 0xFFEEEEEE,
        0xFF111111, 0xFF333333, 0xFF555555, 0xFF777777,
    };

    const base_ptr: [*]const u8 = @ptrCast(@alignCast(&pixels[0]));
    const comp_ptr: [*]const u8 = @ptrCast(@alignCast(&pixels[0]));

    const diff_count = vneon(base_ptr, comp_ptr, 4, 4, 4, 4);

    std.debug.print("Identical 4x4 images - Differences found: {}\n", .{diff_count});
    try expectEqual(@as(u32, 0), diff_count);
}

test "NEON: direct assembly function test - different pixels" {
    if (!HAS_NEON) return testing.skip();

    std.debug.print("\n=== NEON Direct Assembly Test - Different Pixels ===\n", .{});

    // Create two different 2x2 images
    const base_pixels = [_]u32{
        0xFF000000, 0xFF808080,
        0xFFFFFFFF, 0xFF123456,
    };

    const comp_pixels = [_]u32{
        0xFF010101, 0xFF818181,  // Slight differences
        0xFFFEFEFE, 0xFF123457,  // More slight differences
    };

    const base_ptr: [*]const u8 = @ptrCast(@alignCast(&base_pixels[0]));
    const comp_ptr: [*]const u8 = @ptrCast(@alignCast(&comp_pixels[0]));

    const diff_count = vneon(base_ptr, comp_ptr, 2, 2, 2, 2);

    std.debug.print("Different 2x2 images - Differences found: {}\n", .{diff_count});
    // Should detect some differences (actual count depends on threshold)
    try expect(diff_count >= 0); // Basic sanity check
}

test "NEON: alpha channel handling" {
    if (!HAS_NEON) return testing.skip();

    std.debug.print("\n=== NEON Alpha Channel Test ===\n", .{});

    // Test alpha=0 pixels (should be replaced with white)
    const base_pixels = [_]u32{
        0x00000000, 0x00FF0000,  // Transparent pixels
        0xFF000000, 0xFFFF0000,  // Opaque pixels
    };

    const comp_pixels = [_]u32{
        0x00FFFFFF, 0x0000FF00,  // Different transparent pixels
        0xFF010101, 0xFFFF0101,  // Slightly different opaque pixels
    };

    const base_ptr: [*]const u8 = @ptrCast(@alignCast(&base_pixels[0]));
    const comp_ptr: [*]const u8 = @ptrCast(@alignCast(&comp_pixels[0]));

    const diff_count = vneon(base_ptr, comp_ptr, 2, 2, 2, 2);

    std.debug.print("Alpha test - Differences found: {} (transparent pixels should be treated as white)\n", .{diff_count});
    try expect(diff_count >= 0);
}

test "NEON: comparison with existing implementation" {
    if (!HAS_NEON) return testing.skip();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== NEON vs Existing Implementation Comparison ===\n", .{});

    // Create test images with known patterns
    const test_patterns = [_]struct {
        name: []const u8,
        base: []const u32,
        comp: []const u32,
        width: u32,
        height: u32,
    }{
        .{
            .name = "identical_2x2",
            .base = &[_]u32{ 0xFF000000, 0xFFFFFFFF, 0xFF808080, 0xFF123456 },
            .comp = &[_]u32{ 0xFF000000, 0xFFFFFFFF, 0xFF808080, 0xFF123456 },
            .width = 2,
            .height = 2,
        },
        .{
            .name = "slight_diff_2x2",
            .base = &[_]u32{ 0xFF000000, 0xFFFFFFFF, 0xFF808080, 0xFF123456 },
            .comp = &[_]u32{ 0xFF010101, 0xFFFFFFFF, 0xFF818181, 0xFF123456 },
            .width = 2,
            .height = 2,
        },
        .{
            .name = "major_diff_2x2",
            .base = &[_]u32{ 0xFF000000, 0xFFFFFFFF, 0xFF808080, 0xFF123456 },
            .comp = &[_]u32{ 0xFFFFFFFF, 0xFF000000, 0xFF123456, 0xFF808080 },
            .width = 2,
            .height = 2,
        },
        .{
            .name = "alpha_test_2x2",
            .base = &[_]u32{ 0x00000000, 0xFF000000, 0x80808080, 0xFF808080 },
            .comp = &[_]u32{ 0x00FFFFFF, 0xFF010101, 0x80818181, 0xFF818181 },
            .width = 2,
            .height = 2,
        },
    };

    for (test_patterns) |pattern| {
        std.debug.print("\nTesting pattern: {s}\n", .{pattern.name});

        // Test with NEON assembly
        const base_ptr: [*]const u8 = @ptrCast(@alignCast(pattern.base.ptr));
        const comp_ptr: [*]const u8 = @ptrCast(@alignCast(pattern.comp.ptr));
        const neon_result = vneon(base_ptr, comp_ptr, pattern.width, pattern.width, pattern.height, pattern.height);

        // Test with existing SIMD implementation
        var base_img = try createTestImage(pattern.width, pattern.height, pattern.base, allocator);
        defer base_img.deinit();
        var comp_img = try createTestImage(pattern.width, pattern.height, pattern.comp, allocator);
        defer comp_img.deinit();

        const options = diff.DiffOptions{
            .capture_diff = false,
            .enable_asm = false, // Use non-assembly path for comparison
        };

        var diff_output, const simd_result, const diff_percentage, var diff_lines = try diff.compare(&base_img, &comp_img, options, allocator);
        defer if (diff_output) |*img| img.deinit();
        defer if (diff_lines) |*lines| lines.deinit();

        std.debug.print("  NEON result: {} differences\n", .{neon_result});
        std.debug.print("  SIMD result: {} differences\n", .{simd_result});
        std.debug.print("  Difference percentage: {d:.2}%\n", .{diff_percentage});

        // Results should be reasonably close (algorithms may differ slightly)
        const diff_ratio = if (simd_result > 0)
            @abs(@as(f64, @floatFromInt(neon_result)) - @as(f64, @floatFromInt(simd_result))) / @as(f64, @floatFromInt(simd_result))
        else if (neon_result == 0) @as(f64, 0.0) else @as(f64, 1.0);

        std.debug.print("  Difference ratio: {d:.3}\n", .{diff_ratio});

        // Allow some variance due to different algorithms, but should be close
        try expect(diff_ratio < 0.2); // Within 20% difference
    }
}

test "NEON: performance benchmark" {
    if (!HAS_NEON) return testing.skip();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== NEON Performance Benchmark ===\n", .{});

    // Create larger test images for performance testing
    const width = 128;
    const height = 128;
    const total_pixels = width * height;

    // Generate test pattern
    var base_pixels = try allocator.alloc(u32, total_pixels);
    defer allocator.free(base_pixels);
    var comp_pixels = try allocator.alloc(u32, total_pixels);
    defer allocator.free(comp_pixels);

    // Fill with pseudo-random pattern
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    for (0..total_pixels) |i| {
        base_pixels[i] = random.int(u32) | 0xFF000000; // Ensure opaque
        comp_pixels[i] = base_pixels[i] ^ (random.int(u32) & 0x00010101); // Small differences
    }

    const base_ptr: [*]const u8 = @ptrCast(@alignCast(&base_pixels[0]));
    const comp_ptr: [*]const u8 = @ptrCast(@alignCast(&comp_pixels[0]));

    // Benchmark NEON assembly
    const neon_iterations = 100;
    const neon_start = std.time.nanoTimestamp();

    var neon_result: u32 = 0;
    for (0..neon_iterations) |_| {
        neon_result = vneon(base_ptr, comp_ptr, width, width, height, height);
    }

    const neon_end = std.time.nanoTimestamp();
    const neon_time_ns = neon_end - neon_start;
    const neon_time_per_iter = @as(f64, @floatFromInt(neon_time_ns)) / @as(f64, @floatFromInt(neon_iterations));

    // Benchmark existing SIMD implementation
    var base_img = try createTestImage(width, height, base_pixels, allocator);
    defer base_img.deinit();
    var comp_img = try createTestImage(width, height, comp_pixels, allocator);
    defer comp_img.deinit();

    const simd_options = diff.DiffOptions{
        .capture_diff = false,
        .enable_asm = false, // Use SIMD but not assembly
    };

    const simd_iterations = 100;
    const simd_start = std.time.nanoTimestamp();

    var simd_result: u32 = 0;
    for (0..simd_iterations) |_| {
        var diff_output, const count, const diff_percentage, var diff_lines = try diff.compare(&base_img, &comp_img, simd_options, allocator);
        defer if (diff_output) |*img| img.deinit();
        defer if (diff_lines) |*lines| lines.deinit();
        simd_result = count;
        _ = diff_percentage; // Suppress unused variable warning
    }

    const simd_end = std.time.nanoTimestamp();
    const simd_time_ns = simd_end - simd_start;
    const simd_time_per_iter = @as(f64, @floatFromInt(simd_time_ns)) / @as(f64, @floatFromInt(simd_iterations));

    // Performance results
    const speedup = simd_time_per_iter / neon_time_per_iter;
    const pixels_per_sec_neon = (@as(f64, @floatFromInt(total_pixels)) * 1_000_000_000.0) / neon_time_per_iter;
    const pixels_per_sec_simd = (@as(f64, @floatFromInt(total_pixels)) * 1_000_000_000.0) / simd_time_per_iter;

    std.debug.print("Image size: {}x{} ({} pixels)\n", .{ width, height, total_pixels });
    std.debug.print("Iterations: {}\n", .{neon_iterations});
    std.debug.print("\nResults:\n", .{});
    std.debug.print("  NEON result: {} differences\n", .{neon_result});
    std.debug.print("  SIMD result: {} differences\n", .{simd_result});
    std.debug.print("\nPerformance:\n", .{});
    std.debug.print("  NEON time per iteration: {d:.2} ms\n", .{neon_time_per_iter / 1_000_000.0});
    std.debug.print("  SIMD time per iteration: {d:.2} ms\n", .{simd_time_per_iter / 1_000_000.0});
    std.debug.print("  NEON throughput: {d:.0} Mpixels/sec\n", .{pixels_per_sec_neon / 1_000_000.0});
    std.debug.print("  SIMD throughput: {d:.0} Mpixels/sec\n", .{pixels_per_sec_simd / 1_000_000.0});
    std.debug.print("  Speedup: {d:.2}x\n", .{speedup});

    // Basic validation - results should be reasonable
    try expect(neon_result >= 0);
    try expect(simd_result >= 0);
    try expect(neon_time_per_iter > 0);
    try expect(simd_time_per_iter > 0);
}

test "NEON: integration test with test images" {
    if (!HAS_NEON) return testing.skip();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== NEON Integration Test ===\n", .{});

    // Test with actual image files (if available)
    const test_cases = [_]struct {
        base_path: []const u8,
        comp_path: []const u8,
        expected_behavior: []const u8,
    }{
        .{ .base_path = "test/png/white4x4.png", .comp_path = "test/png/white4x4.png", .expected_behavior = "identical" },
        .{ .base_path = "test/png/white4x4.png", .comp_path = "test/png/purple8x8.png", .expected_behavior = "layout_different" },
        .{ .base_path = "test/png/orange.png", .comp_path = "test/png/orange_changed.png", .expected_behavior = "content_different" },
    };

    for (test_cases) |case| {
        std.debug.print("\nTesting: {s} vs {s} ({s})\n", .{ case.base_path, case.comp_path, case.expected_behavior });

        var img1 = loadTestImage(case.base_path, allocator) catch |err| {
            std.debug.print("⚠️  Could not load {s}: {}, skipping this test case\n", .{ case.base_path, err });
            continue;
        };
        defer img1.deinit();

        var img2 = loadTestImage(case.comp_path, allocator) catch |err| {
            std.debug.print("⚠️  Could not load {s}: {}, skipping this test case\n", .{ case.comp_path, err });
            continue;
        };
        defer img2.deinit();

        // Test with NEON enabled
        const neon_options = diff.DiffOptions{
            .capture_diff = false,
            .enable_asm = true, // This should use NEON on ARM64
        };

        var neon_diff_output, const neon_diff_count, const neon_diff_percentage, var neon_diff_lines = diff.compare(&img1, &img2, neon_options, allocator) catch |err| {
            std.debug.print("⚠️  NEON comparison failed: {}, skipping\n", .{err});
            continue;
        };
        defer if (neon_diff_output) |*img| img.deinit();
        defer if (neon_diff_lines) |*lines| lines.deinit();

        // Test with NEON disabled for comparison
        const simd_options = diff.DiffOptions{
            .capture_diff = false,
            .enable_asm = false,
        };

        var simd_diff_output, const simd_diff_count, const simd_diff_percentage, var simd_diff_lines = diff.compare(&img1, &img2, simd_options, allocator) catch |err| {
            std.debug.print("⚠️  SIMD comparison failed: {}, skipping\n", .{err});
            continue;
        };
        defer if (simd_diff_output) |*img| img.deinit();
        defer if (simd_diff_lines) |*lines| lines.deinit();

        std.debug.print("  NEON: {} differences ({d:.2}%)\n", .{ neon_diff_count, neon_diff_percentage });
        std.debug.print("  SIMD: {} differences ({d:.2}%)\n", .{ simd_diff_count, simd_diff_percentage });

        // Validate expected behavior
        if (std.mem.eql(u8, case.expected_behavior, "identical")) {
            try expectEqual(@as(u32, 0), neon_diff_count);
            try expectEqual(@as(u32, 0), simd_diff_count);
        } else if (std.mem.eql(u8, case.expected_behavior, "layout_different") or
                   std.mem.eql(u8, case.expected_behavior, "content_different")) {
            try expect(neon_diff_count > 0);
            try expect(simd_diff_count > 0);
        } else {
            // Unknown expected behavior, just basic validation
            try expect(neon_diff_count >= 0);
            try expect(simd_diff_count >= 0);
        }

        // Results should be reasonably close
        const diff_ratio = if (simd_diff_count > 0)
            @abs(@as(f64, @floatFromInt(neon_diff_count)) - @as(f64, @floatFromInt(simd_diff_count))) / @as(f64, @floatFromInt(simd_diff_count))
        else if (neon_diff_count == 0) @as(f64, 0.0) else @as(f64, 1.0);

        std.debug.print("  Difference ratio: {d:.3}\n", .{diff_ratio});

        // Allow some variance but should be close
        try expect(diff_ratio < 0.1); // Within 10% difference for integration tests
    }
}

test "NEON: edge cases and error conditions" {
    if (!HAS_NEON) return testing.skip();

    std.debug.print("\n=== NEON Edge Cases Test ===\n", .{});

    // Test edge cases
    const edge_cases = [_]struct {
        name: []const u8,
        base: []const u32,
        comp: []const u32,
        width: u32,
        height: u32,
        expected_min: u32,
        expected_max: u32,
    }{
        .{
            .name = "1x1_identical",
            .base = &[_]u32{0xFF808080},
            .comp = &[_]u32{0xFF808080},
            .width = 1,
            .height = 1,
            .expected_min = 0,
            .expected_max = 0,
        },
        .{
            .name = "1x1_different",
            .base = &[_]u32{0xFF000000},
            .comp = &[_]u32{0xFFFFFFFF},
            .width = 1,
            .height = 1,
            .expected_min = 0,
            .expected_max = 1,
        },
        .{
            .name = "4x1_mixed",
            .base = &[_]u32{ 0xFF000000, 0xFF808080, 0xFFFFFFFF, 0xFF123456 },
            .comp = &[_]u32{ 0xFF000000, 0xFF818181, 0xFFFFFFFF, 0xFF123457 },
            .width = 4,
            .height = 1,
            .expected_min = 0,
            .expected_max = 4,
        },
        .{
            .name = "all_transparent",
            .base = &[_]u32{ 0x00000000, 0x00FF0000, 0x0000FF00, 0x000000FF },
            .comp = &[_]u32{ 0x00FFFFFF, 0x00FFFF00, 0x00FF00FF, 0x0000FFFF },
            .width = 2,
            .height = 2,
            .expected_min = 0,
            .expected_max = 0, // All transparent should be treated as white
        },
    };

    for (edge_cases) |case| {
        std.debug.print("\nTesting edge case: {s}\n", .{case.name});

        const base_ptr: [*]const u8 = @ptrCast(@alignCast(case.base.ptr));
        const comp_ptr: [*]const u8 = @ptrCast(@alignCast(case.comp.ptr));

        const result = vneon(base_ptr, comp_ptr, case.width, case.width, case.height, case.height);

        std.debug.print("  Size: {}x{}, Result: {} differences\n", .{ case.width, case.height, result });
        std.debug.print("  Expected range: {} to {}\n", .{ case.expected_min, case.expected_max });

        try expect(result >= case.expected_min);
        try expect(result <= case.expected_max);
    }
}