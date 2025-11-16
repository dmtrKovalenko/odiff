const std = @import("std");
const builtin = @import("builtin");

// Feature detection for NEON
const HAS_NEON = builtin.cpu.arch == .aarch64 and std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon);

// External NEON assembly function
extern fn vneon(
    base_rgba: [*]const u8,
    comp_rgba: [*]const u8,
    base_width: usize,
    comp_width: usize,
    base_height: usize,
    comp_height: usize,
) u32;

pub fn main() !void {
    std.debug.print("🔧 Alpha Handling Test\n", .{});

    if (!HAS_NEON) {
        std.debug.print("⚠️  NEON not available on this system\n", .{});
        return;
    }

    // Test: All transparent pixels (should be treated as white and be identical)
    const all_transparent_base = [_]u32{ 0x00000000, 0x00FF0000, 0x0000FF00, 0x000000FF };
    const all_transparent_comp = [_]u32{ 0x00FFFFFF, 0x00FFFF00, 0x00FF00FF, 0x0000FFFF };

    const base_ptr: [*]const u8 = @ptrCast(@alignCast(&all_transparent_base[0]));
    const comp_ptr: [*]const u8 = @ptrCast(@alignCast(&all_transparent_comp[0]));

    std.debug.print("Testing all transparent pixels (should become white)...\n", .{});
    const result = vneon(base_ptr, comp_ptr, 2, 2, 2, 2);
    std.debug.print("All transparent pixels: {} differences (expected: 0)\n", .{result});

    if (result == 0) {
        std.debug.print("✅ Alpha handling test PASSED\n", .{});
    } else {
        std.debug.print("❌ Alpha handling test FAILED - transparent pixels not handled correctly\n", .{});
    }

    // Test: Mixed alpha and opaque pixels
    const mixed_base = [_]u32{ 0x00000000, 0xFF808080, 0x80FFFFFF, 0xFF000000 };
    const mixed_comp = [_]u32{ 0x00FFFFFF, 0xFF808080, 0x80FFFFFF, 0xFF010101 };

    const mixed_base_ptr: [*]const u8 = @ptrCast(@alignCast(&mixed_base[0]));
    const mixed_comp_ptr: [*]const u8 = @ptrCast(@alignCast(&mixed_comp[0]));

    std.debug.print("Testing mixed alpha/opaque pixels...\n", .{});
    const mixed_result = vneon(mixed_base_ptr, mixed_comp_ptr, 2, 2, 2, 2);
    std.debug.print("Mixed pixels: {} differences (expected: 1, only last pixel different)\n", .{mixed_result});

    if (mixed_result == 1) {
        std.debug.print("✅ Mixed alpha test PASSED\n", .{});
    } else {
        std.debug.print("❌ Mixed alpha test result: {} (expected: 1)\n", .{mixed_result});
    }
}