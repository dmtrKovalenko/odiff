const std = @import("std");

const c_bindings = @import("c_bindings.zig");
const zig_bindings = @import("zig_bindings.zig");

pub const ImageFormat = enum {
    png,
    jpg,
    bmp,
    tiff,
};

pub const Image = struct {
    width: u32,
    height: u32,
    /// RGBA pixels as 32-bit integers
    data: []u32,
    is_c_allocated: bool = false,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Image) void {
        if (self.is_c_allocated) {
            var alloc = self.allocator;
            c_bindings.free_image_data_ptr(self.data.ptr, &alloc, self.data.len * @sizeOf(u32));
        } else {
            self.allocator.free(self.data);
        }
    }

    pub inline fn readRawPixelAtOffset(self: *const Image, offset: usize) u32 {
        return self.data[offset];
    }

    pub fn readRawPixel(self: *const Image, x: u32, y: u32) u32 {
        const offset = y * self.width + x;
        return self.data[offset];
    }

    pub fn setImgColor(self: *Image, x: u32, y: u32, color: u32) void {
        const offset = y * self.width + x;
        self.data[offset] = color;
    }

    pub fn makeSameAsLayout(self: *const Image, allocator: std.mem.Allocator) !Image {
        const data = try allocator.alloc(u32, self.data.len);
        @memset(data, 0);
        return Image{
            .width = self.width,
            .height = self.height,
            .data = data,
            .allocator = allocator,
        };
    }
};

pub const ImageError = error{
    ImageNotLoaded,
    UnsupportedFormat,
    UnsupportedWriteFormat,
    InvalidData,
    OutOfMemory,
    WriteFailed,
};

pub fn getImageFormat(filename: []const u8) !ImageFormat {
    if (std.mem.endsWith(u8, filename, ".png")) return .png;

    if (std.mem.endsWith(u8, filename, ".jpg") or std.mem.endsWith(u8, filename, ".jpeg")) return .jpg;
    if (std.mem.endsWith(u8, filename, ".bmp")) return .bmp;
    if (std.mem.endsWith(u8, filename, ".tiff")) return .tiff;

    return error.UnsupportedFormat;
}

pub fn loadImage(filename: []const u8, allocator: std.mem.Allocator) !Image {
    const format = try getImageFormat(filename);

    const result = switch (format) {
        .png => try zig_bindings.readPNG(allocator, filename),
        .jpg => try c_bindings.readJpgFile(filename, allocator),
        .tiff => try c_bindings.readTiffFile(filename, allocator),
        .bmp => try c_bindings.readBmpFile(filename, allocator),
    };

    const unwrapped_result = result orelse return ImageError.ImageNotLoaded;

    return Image{
        .width = unwrapped_result.width,
        .height = unwrapped_result.height,
        .data = unwrapped_result.data,
        .allocator = allocator,
        .is_c_allocated = unwrapped_result.is_c_allocated,
    };
}

pub fn saveImage(image: *const Image, filename: []const u8) !void {
    const format = try getImageFormat(filename);

    switch (format) {
        .png => {
            try zig_bindings.writePNG(filename, image.width, image.height, image.data);
        },
        else => return ImageError.UnsupportedWriteFormat,
    }
}
