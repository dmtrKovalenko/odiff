const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const color_delta = @import("color_delta.zig");

const HAS_RVV = builtin.cpu.arch  == .riscv64 and std.Target.riscv.featureSetHas(builtin.cpu.features, .v);
extern fn calculatePixelColorDeltaRVVForTest(pixel_a: u32, pixel_b: u32,) f64;

fn calculatePixelColorDeltaUnderTest(pixel_a: u32, pixel_b: u32,) f64 {
    if (HAS_RVV) {
        return calculatePixelColorDeltaRVVForTest(pixel_a, pixel_b);
    } else {
        const fixed_i64 = color_delta.calculatePixelColorDeltaSimd(pixel_a, pixel_b);
        return @as(f64, @floatFromInt(fixed_i64)) / 4096.0;
    }
}

test "color delta: compare fixed-point vs floating-point precision" {
    const test_cases = [_]struct { u32, u32, []const u8 }{
        .{ 0xFF000000, 0xFF010101, "slight RGB difference" },
        .{ 0xFF000000, 0xFFFFFFFF, "black vs white" },
        .{ 0xFFFF0000, 0xFF00FF00, "red vs green" },
        .{ 0xFF0000FF, 0xFFFFFF00, "blue vs yellow" },
        .{ 0x80808080, 0x80818181, "semi-transparent slight difference" },
        .{ 0x00000000, 0xFF000000, "transparent vs opaque black" },
        .{ 0xFF808080, 0xFF828282, "gray slight difference" },
        .{ 0xFFFF8080, 0xFFFF8282, "pinkish slight difference" },
        .{ 0xFF123456, 0xFF123457, "minimal blue difference" },
        .{ 0xFF800000, 0xFF008000, "dark red vs dark green" },
    };

    std.debug.print("\n=== Color Delta Comparison Test ===\n", .{});
    std.debug.print("Format: Original(float) | SIMD(float) | Diff | Error%\n", .{});
    std.debug.print("-----------------------------------------------------------\n", .{});

    var max_error_percent: f64 = 0.0;
    var total_error: f64 = 0.0;

    for (test_cases) |case| {
        const original_result = color_delta.calculatePixelColorDelta(case[0], case[1]);
        const fixed_result_f64 = calculatePixelColorDeltaUnderTest(case[0], case[1]);

        const diff = @abs(original_result - fixed_result_f64);
        const error_percent = if (original_result != 0.0) (diff / original_result) * 100.0 else 0.0;

        max_error_percent = @max(max_error_percent, error_percent);
        total_error += error_percent;

        std.debug.print("{s:<25}: {d:10.6} | {d:10.6} | {d:8.6} | {d:6.3}%\n", .{
            case[2],
            original_result,
            fixed_result_f64,
            diff,
            error_percent,
        });
    }

    const avg_error_percent = total_error / @as(f64, @floatFromInt(test_cases.len));

    std.debug.print("-----------------------------------------------------------\n", .{});
    std.debug.print("Max Error: {d:.3}%  |  Average Error: {d:.3}%\n", .{ max_error_percent, avg_error_percent });

    // verify that the conversion errors are within < 0.5% difference
    try testing.expect(avg_error_percent < 0.2);
    try testing.expect(max_error_percent < 0.5);
}

test "color delta: specific pixel comparison" {
    // Test some specific cases that might be sensitive
    const pixel_a: u32 = 0xFF808080; // Gray
    const pixel_b: u32 = 0xFF818181; // Slightly different gray

    const original = color_delta.calculatePixelColorDelta(pixel_a, pixel_b);
    const fixed_f64 = calculatePixelColorDeltaUnderTest(pixel_a, pixel_b);

    std.debug.print("\nSpecific test - Gray pixels:\n", .{});
    std.debug.print("Original: {d}\n", .{original});
    std.debug.print("SIMD: {d}\n", .{fixed_f64});
    std.debug.print("Difference: {d}\n", .{@abs(original - fixed_f64)});

    // Should be very close for this simple case
    const diff = @abs(original - fixed_f64);
    try testing.expect(diff < 0.01); // Less than 1% difference
}

test "color delta: vectorized vs scalar comparison" {
    const test_cases = [_]struct { u32, u32 }{
        .{ 0xFF000000, 0xFF010101 },
        .{ 0xFF000000, 0xFFFFFFFF },
        .{ 0xFFFF0000, 0xFF00FF00 },
        .{ 0x80808080, 0x80818181 },
        .{ 0xFF123456, 0xFF123457 },
    };

    for (test_cases) |case| {
        const scalar_result = color_delta.calculatePixelColorDelta(case[0], case[1]);
        const vectorized_result = color_delta.calculatePixelColorDeltaSimd(case[0], case[1]);

        // Convert both to same type for comparison
        const vectorized_f64 = @as(f64, @floatFromInt(vectorized_result)) / 4096.0;
        const diff = @abs(scalar_result - vectorized_f64);

        // They should be very close (less than 1% difference)
        const error_percent = if (scalar_result != 0.0) (diff / scalar_result) * 100.0 else 0.0;
        try testing.expect(error_percent < 1.0);
    }
}

test "color delta: edge cases" {
    const edge_cases = [_]struct { u32, u32, []const u8 }{
        .{ 0x00000000, 0x00000000, "identical transparent" },
        .{ 0xFF000000, 0xFF000000, "identical opaque black" },
        .{ 0xFFFFFFFF, 0xFFFFFFFF, "identical white" },
        .{ 0x01010101, 0x02020202, "very small difference" },
        .{ 0xFEFEFEFE, 0xFDFDFDFD, "very small difference near white" },
    };

    for (edge_cases) |case| {
        const original = color_delta.calculatePixelColorDelta(case[0], case[1]);
        const fixed_f64 = calculatePixelColorDeltaUnderTest(case[0], case[1]);

        std.debug.print("{s}: orig={d:.6}, fixed={d:.6}, diff={d:.6}\n", .{
            case[2],
            original,
            fixed_f64,
            @abs(original - fixed_f64),
        });

        // For identical pixels, both should return 0
        if (case[0] == case[1]) {
            try testing.expectEqual(@as(f64, 0.0), fixed_f64);
            try testing.expectEqual(@as(f64, 0.0), original);
        }
    }
}

