const std = @import("std");
const Image = @import("io.zig").Image;
const c = @cImport({
    @cInclude("spng.h");
});

pub fn load(allocator: std.mem.Allocator, data: []const u8) !Image {
    const ctx = c.spng_ctx_new(0) orelse return error.OutOfMemory;
    defer c.spng_ctx_free(ctx);

    // Ignore and don't calculate chunk CRC's for better performance
    _ = c.spng_set_crc_action(ctx, c.SPNG_CRC_USE, c.SPNG_CRC_USE);

    const limit = 1024 * 1024 * 64;
    _ = c.spng_set_chunk_limits(ctx, limit, limit);

    if (c.spng_set_png_buffer(ctx, @ptrCast(data.ptr), @intCast(data.len)) != 0)
        return error.DecoderFailure;

    var ihdr: c.spng_ihdr = undefined;
    if (c.spng_get_ihdr(ctx, &ihdr) != 0) return error.DecoderFailure;

    var out_size: usize = 0;
    if (c.spng_decoded_image_size(ctx, c.SPNG_FMT_RGBA8, &out_size) != 0)
        return error.DecoderFailure;

    const result_data = try allocator.alignedAlloc(u8, .of(u32), out_size);
    errdefer allocator.free(result_data);

    if (c.spng_decode_image(ctx, @ptrCast(result_data.ptr), out_size, c.SPNG_FMT_RGBA8, c.SPNG_DECODE_TRNS) != 0)
        return error.DecoderFailure;

    return Image{
        .width = ihdr.width,
        .height = ihdr.height,
        .data = @ptrCast(result_data),
        .len = result_data.len / @sizeOf(u32),
    };
}

pub fn save(img: Image, file: std.fs.File) !void {
    const ctx = c.spng_ctx_new(c.SPNG_CTX_ENCODER) orelse return error.OutOfMemory;
    defer c.spng_ctx_free(ctx);

    var ihdr = c.spng_ihdr{
        .width = img.width,
        .height = img.height,
        .bit_depth = 8,
        .color_type = c.SPNG_COLOR_TYPE_TRUECOLOR_ALPHA,
        .compression_method = 0,
        .filter_method = c.SPNG_FILTER_NONE,
        .interlace_method = c.SPNG_INTERLACE_NONE,
    };
    if (c.spng_set_ihdr(ctx, &ihdr) != 0) return error.EncoderFailure;

    // Performance optimizations from libspng encode.md:
    // - Disable filtering (already fast, increases file size but maximizes speed)
    // - Set compression level to 1 (3x faster with only ~10% file size increase)
    if (c.spng_set_option(ctx, c.SPNG_FILTER_CHOICE, c.SPNG_DISABLE_FILTERING) != 0) return error.EncoderFailure;
    if (c.spng_set_option(ctx, c.SPNG_IMG_COMPRESSION_LEVEL, 1) != 0) return error.EncoderFailure;

    var buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&buffer);
    if (c.spng_set_png_stream(
        ctx,
        struct {
            pub fn writeFn(_: ?*c.spng_ctx, user_data: ?*anyopaque, src: ?*anyopaque, len: usize) callconv(.c) c_int {
                const w: *std.Io.Writer = @ptrCast(@alignCast(user_data.?));
                const src_slice = @as([*]const u8, @ptrCast(src.?))[0..len];
                w.writeAll(src_slice) catch |err| {
                    std.log.err("writePNG: failed to write data: {}", .{err});
                    return c.SPNG_IO_ERROR;
                };
                return 0;
            }
        }.writeFn,
        @ptrCast(@alignCast(&file_writer.interface)),
    ) != 0) return error.EncoderFailure;

    const u8_slice: []u8 = @ptrCast(img.slice());
    const res = c.spng_encode_image(ctx, u8_slice.ptr, u8_slice.len, c.SPNG_FMT_PNG, c.SPNG_ENCODE_FINALIZE);
    if (res != 0) {
        const err_msg = std.mem.span(c.spng_strerror(res));
        std.log.err("writePNG: failed to encode image {s}", .{err_msg});
        return error.EncoderFailure;
    }
    try file_writer.interface.flush();
}
