const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const win = std.os.windows;

const ImageResult = @import("c_bindings.zig").ImageResult;

const c = @cImport({
    @cInclude("spng.h");
});

/// Reads a PNG file into a slice of pixels
/// caller owns the returned data
pub fn readPNG(allocator: std.mem.Allocator, file_path: []const u8) !ImageResult {
    const file = try MemoryMappeFile.open(file_path);
    defer file.close();

    const ctx = c.spng_ctx_new(0) orelse return error.OutOfMemory;
    defer c.spng_ctx_free(ctx);
    // Ignore and don't calculate chunk CRC's for better performance
    _ = c.spng_set_crc_action(ctx, c.SPNG_CRC_USE, c.SPNG_CRC_USE);
    const limit = 1024 * 1024 * 64;
    _ = c.spng_set_chunk_limits(ctx, limit, limit);
    const result = c.spng_set_png_buffer(ctx, @ptrCast(file.data.ptr), @intCast(file.data.len));
    if (result != 0) return error.InvalidData;

    var ihdr: c.spng_ihdr = undefined;
    if (c.spng_get_ihdr(ctx, &ihdr) != 0) return error.InvalidData;

    var out_size: usize = 0;
    if (c.spng_decoded_image_size(ctx, c.SPNG_FMT_RGBA8, &out_size) != 0) return error.InvalidData;

    const result_data = try allocator.alloc(u32, out_size);
    errdefer allocator.free(result_data);

    if (c.spng_decode_image(ctx, @ptrCast(result_data.ptr), out_size, c.SPNG_FMT_RGBA8, c.SPNG_DECODE_TRNS) != 0)
        return error.InvalidData;

    return ImageResult{
        .width = ihdr.width,
        .height = ihdr.height,
        .data = result_data,
        .is_c_allocated = false,
    };
}

const MemoryMappeFile = struct {
    const Self = @This();

    data: []align(std.heap.page_size_min) const u8,
    file: std.fs.File,

    pub fn open(file_path: []const u8) !Self {
        const file = try std.fs.cwd().openFile(file_path, .{});
        errdefer file.close();

        const file_size = try file.getEndPos();
        if (file_size == 0) return error.FileEmpty;

        switch (builtin.os.tag) {
            .windows => @compileError("Not implemented"),
            // TODO: everything else is posix ig but is this right tho?
            else => {
                const fd = file.handle;
                const ptr = try posix.mmap(null, @intCast(file_size), posix.PROT.READ, posix.MAP{ .TYPE = .PRIVATE }, fd, 0);
                return .{
                    .data = ptr,
                    .file = file,
                };
            },
        }
    }

    pub fn close(self: Self) void {
        switch (builtin.os.tag) {
            .windows => @compileError("Not implemented"),
            else => {
                const ptr = self.data;
                posix.munmap(ptr);
            },
        }
        self.file.close();
    }
};
