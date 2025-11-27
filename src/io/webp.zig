const std = @import("std");
const Image = @import("io.zig").Image;
const c = @cImport({
    @cInclude("webp/decode.h");
});

pub fn load(allocator: std.mem.Allocator, data: []const u8) !Image {
    var width: c_int = 0;
    var height: c_int = 0;

    if (c.WebPGetInfo(@ptrCast(data.ptr), @intCast(data.len), &width, &height) == 0)
        return error.DecoderFailure;

    const result_data = try allocator.alignedAlloc(u8, .of(u32), @intCast(width * height * 4));
    errdefer allocator.free(result_data);

    _ = c.WebPDecodeRGBAInto(
        @ptrCast(data.ptr),
        @intCast(data.len),
        @ptrCast(result_data.ptr),
        @intCast(result_data.len),
        @intCast(width * 4),
    ) orelse return error.DecoderFailure;

    return Image{
        .width = @intCast(width),
        .height = @intCast(height),
        .data = @ptrCast(result_data),
        .len = result_data.len / @sizeOf(u32),
    };
}
