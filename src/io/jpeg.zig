const std = @import("std");
const Image = @import("image.zig").Image;
const c = @cImport({
    @cInclude("turbojpeg.h");
});

pub fn load(allocator: std.mem.Allocator, data: []const u8) !Image {
    const handle = c.tjInitDecompress() orelse return error.OutOfMemory;
    defer if (c.tjDestroy(handle) != 0) {
        std.log.warn("Failed to destroy TurboJPEG decompressor", .{});
    };
    var width: c_int = 0;
    var height: c_int = 0;
    if (c.tjDecompressHeader(handle, @ptrCast(@constCast(data.ptr)), @intCast(data.len), &width, &height) != 0)
        return error.InvalidData;

    const result_data = try allocator.alignedAlloc(u8, .of(u32), @intCast(width * height * 4));
    errdefer allocator.free(result_data);

    if (c.tjDecompress2(
        handle,
        @ptrCast(data.ptr),
        @intCast(data.len),
        result_data.ptr,
        @intCast(width),
        0, // pitch
        @intCast(height),
        c.TJPF_RGBA,
        c.TJFLAG_ACCURATEDCT,
    ) != 0)
        return error.InvalidData;

    return Image{
        .width = @intCast(width),
        .height = @intCast(height),
        .data = @ptrCast(result_data),
        .len = result_data.len / @sizeOf(u32),
    };
}
