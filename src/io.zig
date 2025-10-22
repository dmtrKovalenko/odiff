const std = @import("std");
const bmp = @import("bmp_reader.zig");
const c = @cImport({
    @cInclude("spng.h");
    @cInclude("turbojpeg.h");
});

pub const Image = extern struct {
    data: [*]u32,
    len: usize,
    width: u32,
    height: u32,

    pub fn slice(self: Image) []u32 {
        return self.data[0..self.len];
    }

    pub fn deinit(self: Image, allocator: std.mem.Allocator) void {
        allocator.free(self.slice());
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
        const data = try allocator.alloc(u32, self.len);
        @memset(data, 0);
        return Image{
            .width = self.width,
            .height = self.height,
            .data = data.ptr,
            .len = data.len,
        };
    }

    pub fn makeWithWhiteOverlay(self: *const Image, factor: f32, allocator: std.mem.Allocator) !Image {
        const data = try allocator.alloc(u32, self.len);

        const R_COEFF: u32 = 19595; // 0.29889531 * 65536
        const G_COEFF: u32 = 38469; // 0.58662247 * 65536
        const B_COEFF: u32 = 7504; // 0.11448223 * 65536
        const WHITE_SHADE_FACTOR: u32 = @intFromFloat(factor * 255); // by default 128
        const INV_SHADE_FACTOR: u32 = 255 - WHITE_SHADE_FACTOR;
        const WHITE_CONTRIBUTION: u32 = WHITE_SHADE_FACTOR * 255;
        const FULL_ALPHA: u32 = 0xFF000000;

        const SIMD_SIZE = std.simd.suggestVectorLength(u32) orelse 4;
        const simd_end = (data.len / SIMD_SIZE) * SIMD_SIZE;

        const R_COEFF_VEC: @Vector(SIMD_SIZE, u32) = @splat(R_COEFF);
        const G_COEFF_VEC: @Vector(SIMD_SIZE, u32) = @splat(G_COEFF);
        const B_COEFF_VEC: @Vector(SIMD_SIZE, u32) = @splat(B_COEFF);
        const INV_SHADE_VEC: @Vector(SIMD_SIZE, u32) = @splat(INV_SHADE_FACTOR);
        const WHITE_CONTRIB_VEC: @Vector(SIMD_SIZE, u32) = @splat(WHITE_CONTRIBUTION);
        const DIV255_VEC: @Vector(SIMD_SIZE, u32) = @splat(255);
        const MASK_VEC: @Vector(SIMD_SIZE, u32) = @splat(0xFF);
        const ALPHA_VEC: @Vector(SIMD_SIZE, u32) = @splat(FULL_ALPHA);

        var i: usize = 0;
        while (i < simd_end) : (i += SIMD_SIZE) {
            const pixels: @Vector(SIMD_SIZE, u32) = self.data[i .. i + SIMD_SIZE][0..SIMD_SIZE].*;
            const r_vec = (pixels >> @splat(16)) & MASK_VEC;
            const g_vec = (pixels >> @splat(8)) & MASK_VEC;
            const b_vec = pixels & MASK_VEC;

            const luminance_scaled = r_vec * R_COEFF_VEC + g_vec * G_COEFF_VEC + b_vec * B_COEFF_VEC;
            const luminance_vec = luminance_scaled >> @as(@Vector(SIMD_SIZE, u5), @splat(16));
            const blended_vec = (INV_SHADE_VEC * luminance_vec + WHITE_CONTRIB_VEC) / DIV255_VEC;

            const gray_masked = blended_vec & MASK_VEC;
            const result_vec = ALPHA_VEC | (gray_masked << @splat(16)) | (gray_masked << @splat(8)) | gray_masked;

            @memcpy(data[i .. i + SIMD_SIZE], @as(*const [SIMD_SIZE]u32, @ptrCast(&result_vec)));
        }

        // handle remaining pixels
        while (i < data.len) : (i += 1) {
            const pixel = self.data[i];

            const red = (pixel >> 16) & 0xFF;
            const green = (pixel >> 8) & 0xFF;
            const blue = pixel & 0xFF;

            const luminance = (red * R_COEFF + green * G_COEFF + blue * B_COEFF) >> 16;
            const gray_val = (INV_SHADE_FACTOR * luminance + WHITE_CONTRIBUTION) / 255;
            data[i] = FULL_ALPHA | (gray_val << 16) | (gray_val << 8) | gray_val;
        }

        return Image{
            .width = self.width,
            .height = self.height,
            .data = data.ptr,
            .len = data.len,
        };
    }
};

pub const ImageFormat = enum(c_int) {
    png,
    jpg,
    bmp,
    tiff,
    webp,

    pub fn fromExtension(ext: []const u8) ?ImageFormat {
        if (std.mem.eql(u8, ext, ".png")) return .png;
        if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) return .jpg;
        if (std.mem.eql(u8, ext, ".bmp")) return .bmp;
        if (std.mem.eql(u8, ext, ".tiff")) return .tiff;
        if (std.mem.eql(u8, ext, ".webp")) return .webp;
        return null;
    }
};

/// Loads an image from a given file path.
/// Automatically detects the image format based on the file extension.
/// Image data is owned by the caller and must be freed using `allocator.free`.
/// Also checkout `loadImageEx`
pub fn loadImage(allocator: std.mem.Allocator, file_path: []const u8) !Image {
    const ext = std.fs.path.extension(file_path);
    const format = ImageFormat.fromExtension(ext) orelse return error.UnsupportedFormat;
    return try loadImageEx(allocator, file_path, format);
}

/// Loads an image from a given file path.
/// Image data is owned by the caller and must be freed using `allocator.free`.
///
/// Also checkout `loadImage`
pub fn loadImageEx(allocator: std.mem.Allocator, file_path: []const u8, format: ImageFormat) !Image {
    const file = MemoryMappeFile.open(file_path) catch return error.ImageNotLoaded;
    defer file.close();

    const image = switch (format) {
        .png => try loadPNG(allocator, file.data),
        .jpg => try loadJpeg(allocator, file.data),
        .bmp => try bmp.loadFromBuffer(allocator, file.data),
        else => return error.UnsupportedFormat,
    };

    return image;
}

fn loadPNG(allocator: std.mem.Allocator, data: []const u8) !Image {
    const ctx = c.spng_ctx_new(0) orelse return error.OutOfMemory;
    defer c.spng_ctx_free(ctx);

    // Ignore and don't calculate chunk CRC's for better performance
    _ = c.spng_set_crc_action(ctx, c.SPNG_CRC_USE, c.SPNG_CRC_USE);

    const limit = 1024 * 1024 * 64;
    _ = c.spng_set_chunk_limits(ctx, limit, limit);

    if (c.spng_set_png_buffer(ctx, @ptrCast(data.ptr), @intCast(data.len)) != 0)
        return error.InvalidData;

    var ihdr: c.spng_ihdr = undefined;
    if (c.spng_get_ihdr(ctx, &ihdr) != 0) return error.InvalidData;

    var out_size: usize = 0;
    if (c.spng_decoded_image_size(ctx, c.SPNG_FMT_RGBA8, &out_size) != 0)
        return error.InvalidData;

    const result_data = try allocator.alignedAlloc(u8, .of(u32), out_size);
    errdefer allocator.free(result_data);

    if (c.spng_decode_image(ctx, @ptrCast(result_data.ptr), out_size, c.SPNG_FMT_RGBA8, c.SPNG_DECODE_TRNS) != 0)
        return error.InvalidData;

    return Image{
        .width = ihdr.width,
        .height = ihdr.height,
        .data = @ptrCast(result_data),
        .len = result_data.len / @sizeOf(u32),
    };
}

fn loadJpeg(allocator: std.mem.Allocator, data: []const u8) !Image {
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

/// Saves an image to a given file path.
/// Does not take ownership of the image data.
///
/// Also checkout `saveImageEx`
pub fn saveImage(img: Image, file_path: []const u8) !void {
    const ext = std.fs.path.extension(file_path);
    const format = ImageFormat.fromExtension(ext) orelse return error.UnsupportedFormat;
    return saveImageEx(img, file_path, format);
}

/// Saves an image to a given file path.
/// Does not take ownership of the image data.
///
/// Also checkout `saveImage`
pub fn saveImageEx(img: Image, file_path: []const u8, format: ImageFormat) !void {
    var file = try std.fs.cwd().createFile(file_path, .{
        .truncate = true,
    });
    defer file.close();
    var buffer: [1024 * 1024]u8 = undefined;
    var file_writer = file.writer(&buffer);

    switch (format) {
        .png => try savePNG(img, &file_writer.interface),
        else => return error.UnsupportedFormat,
    }

    try file_writer.interface.flush();
}

fn savePNG(img: Image, writer: *std.Io.Writer) !void {
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
    if (c.spng_set_ihdr(ctx, &ihdr) != 0) return error.InvalidData;

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
        @ptrCast(@alignCast(writer)),
    ) != 0) return error.InvalidData;

    const pixel_data = img.slice();
    const res = c.spng_encode_image(ctx, @ptrCast(@alignCast(pixel_data.ptr)), pixel_data.len * @sizeOf(u32), c.SPNG_FMT_PNG, c.SPNG_ENCODE_FINALIZE);
    if (res != 0) {
        const err_msg = std.mem.span(c.spng_strerror(res));
        std.log.err("writePNG: failed to encode image {s}", .{err_msg});
        return error.InvalidData;
    }
}

const MemoryMappeFile = struct {
    const Self = @This();

    const builtin = @import("builtin");
    const posix = std.posix;
    const win = std.os.windows;
    const is_windows = builtin.os.tag == .windows;

    file: std.fs.File,
    data: if (is_windows)
        []const u8
    else
        []align(std.heap.page_size_min) const u8,

    win_mapping: if (is_windows) win.HANDLE else void =
        if (is_windows) undefined else ({}),

    pub fn open(file_path: []const u8) !Self {
        const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
        errdefer file.close();

        const file_size = try file.getEndPos();
        if (file_size == 0) return error.FileEmpty;

        const fd = file.handle;
        switch (builtin.os.tag) {
            .windows => {
                const mapping = win_aux.CreateFileMappingA(fd, null, win.PAGE_READONLY, 0, 0, null) orelse return error.CreateFileMappingFailed;
                const ptr = win_aux.MapViewOfFile(mapping, win_aux.FILE_MAP_READ, 0, 0, 0) orelse return error.MapViewOfFileFailed;
                return .{
                    .file = file,
                    // explicitly casts to a const ptr cuz it is read-only
                    .data = @as([*]const u8, @ptrCast(ptr))[0..file_size],
                    .win_mapping = mapping,
                };
            },
            else => {
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
            .windows => {
                // cast away const cuz windows api uses c and nothing is const there ffs
                _ = win_aux.UnmapViewOfFile(@ptrCast(@constCast(self.data.ptr)));
                win.CloseHandle(self.win_mapping);
            },
            else => {
                const ptr = self.data;
                posix.munmap(ptr);
            },
        }
        self.file.close();
    }

    // TODO: replace with zig std when they are available there
    const win_aux = if (builtin.os.tag == .windows) struct {
        const win_h = @cImport({
            @cDefine("WIN32_LEAN_AND_MEAN", "1");
            @cInclude("windows.h");
        });
        pub const CreateFileMappingA = win_h.CreateFileMappingA;
        pub const MapViewOfFile = win_h.MapViewOfFile;
        pub const UnmapViewOfFile = win_h.UnmapViewOfFile;
        pub const FILE_MAP_READ = win_h.FILE_MAP_READ;
    } else void;
};
