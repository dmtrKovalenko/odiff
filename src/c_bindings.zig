// C FFI bindings for image I/O
const std = @import("std");

// C structure definitions matching our C code
pub const CImageData = extern struct {
    width: c_int,
    height: c_int,
    data: [*]u32,
};

// Common return type for all image readers
pub const ImageResult = struct { width: u32, height: u32, data: []u32, is_c_allocated: bool = false };

// External C functions - updated to return by value
extern fn read_png_file(filename: [*:0]const u8, allocator: *anyopaque) CImageData;
extern fn write_png_file(filename: [*:0]const u8, width: c_int, height: c_int, data: [*]const u32) c_int;
extern fn read_jpg_file(filename: [*:0]const u8, allocator: *anyopaque) CImageData;
extern fn read_tiff_file(filename: [*:0]const u8, allocator: *anyopaque) CImageData;
extern fn read_webp_file(filename: [*:0]const u8, allocator: *anyopaque) CImageData;

extern fn free_image_data(data: *CImageData, allocator: *anyopaque) void;

pub extern fn free_image_data_ptr(data: [*]u32, allocator: *anyopaque, size: usize) void;

pub fn readPngFile(filename: []const u8, allocator: std.mem.Allocator) !?ImageResult {
    const c_filename = try allocator.dupeZ(u8, filename);
    defer allocator.free(c_filename);

    var alloc = allocator;
    const c_data = read_png_file(c_filename.ptr, &alloc);

    // Check if the C function failed (returned null data)
    if (@intFromPtr(c_data.data) == 0) return null;

    // Use C-allocated memory directly - no copying!
    const width: u32 = @intCast(c_data.width);
    const height: u32 = @intCast(c_data.height);
    const data_len = width * height;

    // Create a slice that points to the C-allocated memory
    const data = c_data.data[0..data_len];

    return ImageResult{
        .width = width,
        .height = height,
        .data = data,
        .is_c_allocated = true, // Pixel data is C-allocated
    };
}

pub fn writePngFile(filename: []const u8, width: u32, height: u32, data: []const u32, allocator: std.mem.Allocator) !void {
    const c_filename = try allocator.dupeZ(u8, filename);
    defer allocator.free(c_filename);

    const result = write_png_file(c_filename.ptr, @intCast(width), @intCast(height), data.ptr);
    if (result != 0) {
        std.debug.print("PNG write failed with code: {d}\n", .{result});
        return error.WriteFailed;
    }
}

pub fn readJpgFile(filename: []const u8, allocator: std.mem.Allocator) !?ImageResult {
    const c_filename = try allocator.dupeZ(u8, filename);
    defer allocator.free(c_filename);

    var alloc = allocator;
    const c_data = read_jpg_file(c_filename.ptr, &alloc);

    // Check if the C function failed (returned null data)
    if (@intFromPtr(c_data.data) == 0) return null;

    const width: u32 = @intCast(c_data.width);
    const height: u32 = @intCast(c_data.height);
    const data_len = width * height;

    const data = c_data.data[0..data_len];

    return ImageResult{
        .width = width,
        .height = height,
        .data = data,
        .is_c_allocated = true, // Pixel data is C-allocated
    };
}

pub fn readTiffFile(filename: []const u8, allocator: std.mem.Allocator) !?ImageResult {
    const c_filename = try allocator.dupeZ(u8, filename);
    defer allocator.free(c_filename);

    var alloc = allocator;
    const c_data = read_tiff_file(c_filename.ptr, &alloc);

    // Check if the C function failed (returned null data)
    if (@intFromPtr(c_data.data) == 0) return null;

    const width: u32 = @intCast(c_data.width);
    const height: u32 = @intCast(c_data.height);
    const data_len = width * height;
    const data = c_data.data[0..data_len];

    return ImageResult{
        .width = width,
        .height = height,
        .data = data,
        .is_c_allocated = true, // Pixel data is C-allocated
    };
}

const bmp_reader = @import("bmp_reader.zig");
pub fn readBmpFile(filename: []const u8, allocator: std.mem.Allocator) !?ImageResult {
    const image = try bmp_reader.loadBmp(filename, allocator);

    return ImageResult{ .width = image.width, .height = image.height, .data = image.data };
}

pub fn readWebpFile(filename: []const u8, allocator: std.mem.Allocator) !?ImageResult {
    const c_filename = try allocator.dupeZ(u8, filename);
    defer allocator.free(c_filename);

    var alloc = allocator;
    const c_data = read_webp_file(c_filename.ptr, &alloc);

    // Check if the C function failed (returned null data)
    if (@intFromPtr(c_data.data) == 0) return null;

    const width: u32 = @intCast(c_data.width);
    const height: u32 = @intCast(c_data.height);
    const data_len = width * height;
    const data = c_data.data[0..data_len];

    return ImageResult{
        .width = width,
        .height = height,
        .data = data,
        .is_c_allocated = true, // Pixel data is C-allocated
    };
}

