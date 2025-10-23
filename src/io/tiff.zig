const std = @import("std");
const Image = @import("image.zig").Image;
const c = @cImport({
    @cInclude("tiffio.h");
});

pub fn load(allocator: std.mem.Allocator, data: []const u8) !Image {
    var client_handle: TIFFClient = .{ .buf = data };
    const handle = c.TIFFClientOpen(
        "memory",
        "r",
        @ptrCast(&client_handle),
        TIFFClient.read,
        TIFFClient.write,
        TIFFClient.seek,
        TIFFClient.close,
        TIFFClient.size,
        TIFFClient.map,
        TIFFClient.unmap,
    ) orelse {
        return error.InvalidData;
    };
    defer c.TIFFClose(handle);

    var width: u32 = 0;
    var height: u32 = 0;
    if (c.TIFFGetField(handle, c.TIFFTAG_IMAGEWIDTH, &width) != 1)
        return error.InvalidData;
    if (c.TIFFGetField(handle, c.TIFFTAG_IMAGELENGTH, &height) != 1)
        return error.InvalidData;

    const result_data = try allocator.alloc(u32, width * height);
    errdefer allocator.free(result_data);

    if (c.TIFFReadRGBAImageOriented(handle, width, height, result_data.ptr, c.ORIENTATION_TOPLEFT, 0) != 1)
        return error.InvalidData;

    return Image{
        .width = width,
        .height = height,
        .data = result_data.ptr,
        .len = result_data.len,
    };
}

const TIFFClient = struct {
    buf: []const u8,
    offset: usize = 0,

    pub fn read(self_ptr: c.thandle_t, buf_ptr: ?*anyopaque, buf_len: c.tmsize_t) callconv(.c) c.tmsize_t {
        const self: *TIFFClient = @ptrCast(@alignCast(self_ptr orelse return @as(c.tmsize_t, -1)));
        if (buf_ptr == null) return @as(c.tmsize_t, -1);

        const read_size = @min(buf_len, @as(c.tmsize_t, @intCast(self.buf.len - self.offset)));
        const dest_buf = @as([*]u8, @ptrCast(buf_ptr))[0..@as(usize, @intCast(read_size))];

        @memcpy(dest_buf, self.buf[self.offset .. self.offset + @as(usize, @intCast(read_size))]);
        self.offset += @as(usize, @intCast(read_size));

        return read_size;
    }

    pub fn write(self_ptr: c.thandle_t, buf_ptr: ?*anyopaque, buf_len: c.tmsize_t) callconv(.c) c.tmsize_t {
        _ = self_ptr;
        _ = buf_ptr;
        _ = buf_len;

        return -1;
    }

    pub fn seek(self_ptr: c.thandle_t, offset: c.toff_t, whence: c_int) callconv(.c) c.toff_t {
        const self: *TIFFClient = @ptrCast(@alignCast(self_ptr orelse return 0));
        switch (whence) {
            c.SEEK_SET => self.offset = @as(usize, @intCast(offset)),
            c.SEEK_CUR => self.offset += @as(usize, @intCast(offset)),
            c.SEEK_END => self.offset = self.buf.len + @as(usize, @intCast(offset)),
            else => return 0,
        }
        return self.offset;
    }

    pub fn close(self_ptr: c.thandle_t) callconv(.c) c_int {
        _ = self_ptr;
        return 0;
    }

    pub fn size(self_ptr: c.thandle_t) callconv(.c) c.toff_t {
        const self: *TIFFClient = @ptrCast(@alignCast(self_ptr orelse return 0));
        return @as(c.toff_t, @intCast(self.buf.len));
    }

    pub fn map(self_ptr: c.thandle_t, base: [*c]?*anyopaque, sz: [*c]c.toff_t) callconv(.c) c_int {
        _ = self_ptr;
        _ = base;
        _ = sz;
        return 0; // FALSE - we don't support mapping
    }

    pub fn unmap(self_ptr: c.thandle_t, base: ?*anyopaque, sz: c.toff_t) callconv(.c) void {
        _ = self_ptr;
        _ = base;
        _ = sz;
    }
};
