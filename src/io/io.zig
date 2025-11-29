
            base_img.deinit(allocator);
        }
        return err;
    };

    base_thread.join();
    comp_thread.join();

    // Check for errors
    if (base_result.err) |err| {
        if (comp_result.image) |img| {
            var comp_img = img;
            comp_img.deinit(allocator);
        }
        return err;
    }

    if (comp_result.err) |err| {
        if (base_result.image) |img| {
            var base_img = img;
            base_img.deinit(allocator);
        }
        return err;
    }

    return .{
        .base = base_result.image.?,
        .compare = comp_result.image.?,
    };
}

/// Saves an image to a given file path.
/// Does not take ownership of the image data.
///
/// Also checkout `saveImageEx`
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

    switch (format) {
        .png => try png.save(img, file),
        else => return error.UnsupportedFormat,
    }
}
