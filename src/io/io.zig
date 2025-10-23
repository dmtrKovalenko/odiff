const std = @import("std");
const MemoryMappedFile = @import("memory_mapped_file.zig");
const bmp = @import("bmp.zig");
const png = @import("png.zig");
const jpeg = @import("jpeg.zig");
const tiff = @import("tiff.zig");
const webp = @import("webp.zig");
const image = @import("image.zig");

const Image = image.Image;
const ImageFormat = image.ImageFormat;

/// Loads an image from a given file path.
/// Automatically detects the image format based on the file extension.
/// Image data is owned by the caller and must be freed using `allocator.free`.
/// Also checkout `loadImageWithFormat`
pub fn loadImage(allocator: std.mem.Allocator, file_path: []const u8) !Image {
    const ext = std.fs.path.extension(file_path);
    const format = ImageFormat.fromExtension(ext) orelse return error.UnsupportedFormat;
    return try loadImageWithFormat(allocator, file_path, format);
}

/// Loads an image from a given file path.
/// Image data is owned by the caller and must be freed using `allocator.free`.
///
/// Also checkout `loadImage`
pub fn loadImageWithFormat(allocator: std.mem.Allocator, file_path: []const u8, format: ImageFormat) !Image {
    const file = MemoryMappedFile.open(file_path) catch return error.ImageNotLoaded;
    defer file.close();

    return switch (format) {
        .png => try png.load(allocator, file.data),
        .jpg => try jpeg.load(allocator, file.data),
        .bmp => try bmp.load(allocator, file.data),
        .tiff => try tiff.load(allocator, file.data),
        .webp => try webp.load(allocator, file.data),
    };
}

/// Saves an image to a given file path.
/// Does not take ownership of the image data.
///
/// Also checkout `saveImageWithFormat`
pub fn saveImage(img: Image, file_path: []const u8) !void {
    const ext = std.fs.path.extension(file_path);
    const format = ImageFormat.fromExtension(ext) orelse return error.UnsupportedFormat;
    return saveImageWithFormat(img, file_path, format);
}

/// Saves an image to a given file path.
/// Does not take ownership of the image data.
///
/// Also checkout `saveImage`
pub fn saveImageWithFormat(img: Image, file_path: []const u8, format: ImageFormat) !void {
    var file = try std.fs.cwd().createFile(file_path, .{
        .truncate = true,
    });
    defer file.close();
    var buffer: [1024 * 1024]u8 = undefined;
    var file_writer = file.writer(&buffer);

    switch (format) {
        .png => try png.save(img, &file_writer.interface),
        else => return error.UnsupportedFormat,
    }

    try file_writer.interface.flush();
}
