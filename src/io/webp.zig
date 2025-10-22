const std = @import("std");
const Image = @import("io.zig").Image;
const c = @cImport({
    @cInclude("webp/decode.h");
});

pub fn load(allocator: std.mem.Allocator, data: []const u8) !Image {
    var width: c_int = 0;
    var height: c_int = 0;

    // Get image dimensions first
    if (c.WebPGetInfo(@ptrCast(data.ptr), @intCast(data.len), &width, &height) == 0)
        return error.InvalidData;

    // Allocate memory for RGBA output
    const result_data = try allocator.alignedAlloc(u8, .of(u32), @intCast(width * height * 4));
    errdefer allocator.free(result_data);

    // Decode the WebP image to RGBA format
    const decoded_data = c.WebPDecodeRGBA(
        @ptrCast(data.ptr),
        @intCast(data.len),
        &width,
        &height,
    ) orelse return error.InvalidData;

    // Copy the decoded data to our allocated buffer
    @memcpy(result_data, decoded_data[0..@intCast(width * height * 4)]);

    // Free the temporary buffer allocated by libwebp
    c.WebPFree(decoded_data);

    return Image{
        .width = @intCast(width),
        .height = @intCast(height),
        .data = @ptrCast(result_data),
        .len = result_data.len / @sizeOf(u32),
    };
}
