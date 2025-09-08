const std = @import("std");

pub const cli = @import("cli.zig");
pub const image_io = @import("image_io.zig");
pub const diff = @import("diff.zig");
pub const color_delta = @import("color_delta.zig");
pub const antialiasing = @import("antialiasing.zig");
pub const bmp_reader = @import("bmp_reader.zig");
pub const c_bindings = @import("c_bindings.zig");

// Export allocator functions for C code to use
export fn zig_alloc(allocator_ptr: *anyopaque, size: usize) ?[*]u8 {
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_ptr));
    const memory = allocator.alloc(u8, size) catch return null;
    return memory.ptr;
}

export fn zig_free(allocator_ptr: *anyopaque, ptr: [*]u8, size: usize) void {
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_ptr));
    const memory = ptr[0..size];
    allocator.free(memory);
}
