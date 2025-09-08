const std = @import("std");
const image_io = @import("image_io.zig");

const BMP_SIGNATURE: u16 = 19778; // "BM" in little-endian
const BYTES_PER_PIXEL_24: u8 = 3;
const BYTES_PER_PIXEL_32: u8 = 4;

const BiCompression = enum(u32) {
    BI_RGB = 0,
    BI_RLE8 = 1,
    BI_RLE4 = 2,
    BI_BITFIELDS = 3,
};

const BiBitCount = enum(u16) {
    Monochrome = 1,
    Color16 = 4,
    Color256 = 8,
    ColorRGB = 24,
    ColorRGBA = 32,
};

// BMP file header (14 bytes)
const BitmapFileHeader = packed struct {
    bf_type: u16, // File signature - must be 19778 ("BM")
    bf_size: u32, // File size in bytes
    bf_reserved1: u16, // Reserved field 1
    bf_reserved2: u16, // Reserved field 2
    bf_off_bits: u32, // Offset to pixel data
};

// BMP info header (40 bytes)
const BitmapInfoHeader = packed struct {
    bi_size: u32, // Info header size
    bi_width: i32, // Image width (can be negative)
    bi_height: i32, // Image height (can be negative)
    bi_planes: u16, // Number of color planes
    bi_bit_count: u16, // Bits per pixel
    bi_compression: u32, // Compression type
    bi_size_image: u32, // Image size
    bi_x_pels_per_meter: u32, // Horizontal resolution
    bi_y_pels_per_meter: u32, // Vertical resolution
    bi_clr_used: u32, // Number of colors used
    bi_clr_important: u32, // Number of important colors
};

pub const BmpError = error{
    InvalidSignature,
    UnsupportedBitDepth,
    UnsupportedCompression,
    InvalidDimensions,
    FileCorrupted,
    OutOfMemory,
};

// Read little-endian values with bounds checking
inline fn readU16LE(data: []const u8, offset: usize) !u16 {
    if (offset + 2 > data.len) return BmpError.FileCorrupted;
    return std.mem.readInt(u16, data[offset .. offset + 2], .little);
}

inline fn readU32LE(data: []const u8, offset: usize) !u32 {
    if (offset + 4 > data.len) return BmpError.FileCorrupted;
    return std.mem.readInt(u32, data[offset .. offset + 4], .little);
}

inline fn readI32LE(data: []const u8, offset: usize) !i32 {
    if (offset + 4 > data.len) return BmpError.FileCorrupted;
    return std.mem.readInt(i32, data[offset .. offset + 4], .little);
}

// Vectorized BGR to ARGB conversion for 24-bit BMP
inline fn convertBGR24ToARGB_Vec4(bgr_data: []const u8, argb_data: []u32, start_idx: usize) void {
    if (start_idx + 4 > argb_data.len) return;

    // Load 4 BGR pixels (12 bytes) - not perfectly aligned but we'll handle it
    const b0 = bgr_data[start_idx * 3 + 0];
    const g0 = bgr_data[start_idx * 3 + 1];
    const r0 = bgr_data[start_idx * 3 + 2];

    const b1 = bgr_data[start_idx * 3 + 3];
    const g1 = bgr_data[start_idx * 3 + 4];
    const r1 = bgr_data[start_idx * 3 + 5];

    const b2 = bgr_data[start_idx * 3 + 6];
    const g2 = bgr_data[start_idx * 3 + 7];
    const r2 = bgr_data[start_idx * 3 + 8];

    const b3 = bgr_data[start_idx * 3 + 9];
    const g3 = bgr_data[start_idx * 3 + 10];
    const r3 = bgr_data[start_idx * 3 + 11];

    // Create RGBA values (A=255, R, G, B) - fixed color order
    argb_data[start_idx + 0] = (255 << 24) | (@as(u32, r0) << 16) | (@as(u32, g0) << 8) | @as(u32, b0);
    argb_data[start_idx + 1] = (255 << 24) | (@as(u32, r1) << 16) | (@as(u32, g1) << 8) | @as(u32, b1);
    argb_data[start_idx + 2] = (255 << 24) | (@as(u32, r2) << 16) | (@as(u32, g2) << 8) | @as(u32, b2);
    argb_data[start_idx + 3] = (255 << 24) | (@as(u32, r3) << 16) | (@as(u32, g3) << 8) | @as(u32, b3);
}

// Vectorized BGRA to ARGB conversion for 32-bit BMP
inline fn convertBGRA32ToARGB_Vec4(bgra_data: []const u8, argb_data: []u32, start_idx: usize) void {
    if (start_idx + 4 > argb_data.len or start_idx * 4 + 16 > bgra_data.len) return;

    // Load 4 BGRA pixels (16 bytes) as vector
    const bgra_bytes = bgra_data[start_idx * 4 .. start_idx * 4 + 16];

    // Process 4 pixels at once
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const b = bgra_bytes[i * 4 + 0];
        const g = bgra_bytes[i * 4 + 1];
        const r = bgra_bytes[i * 4 + 2];
        const a = bgra_bytes[i * 4 + 3];

        // Convert BGRA to RGBA
        argb_data[start_idx + i] = (@as(u32, a) << 24) | (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
    }
}

inline fn calculateRowPadding(width: u32, bytes_per_pixel: u8) u32 {
    const row_size = width * bytes_per_pixel;
    return (4 - (row_size % 4)) % 4;
}

fn loadImage24Data(data: []const u8, offset: usize, width: u32, height: u32, allocator: std.mem.Allocator) ![]u32 {
    const pixel_count = width * height;
    const argb_data = try allocator.alloc(u32, pixel_count);
    errdefer allocator.free(argb_data);

    const row_padding = (4 - (width * 3 % 4)) & 3;
    var data_offset = offset;

    // BMP stores pixels bottom-up
    var y: i32 = @as(i32, @intCast(height)) - 1;
    while (y >= 0) : (y -= 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            if (data_offset + 3 > data.len) return BmpError.FileCorrupted;

            const b_byte = data[data_offset + 0];
            const g_byte = data[data_offset + 1];
            const r_byte = data[data_offset + 2];

            const r = (@as(u32, r_byte) & 255) << 16; // Red to bits 16-23
            const g = (@as(u32, g_byte) & 255) << 8; // Green to bits 8-15
            const b = (@as(u32, b_byte) & 255) << 0; // Blue to bits 0-7
            const a = comptime @as(u32, 255) << 24;

            const pixel_index = (@as(u32, @intCast(y)) * width) + x;
            argb_data[pixel_index] = a | b | g | r;

            data_offset += 3;
        }

        data_offset += row_padding;
    }

    return argb_data;
}

fn loadImage32Data(data: []const u8, offset: usize, width: u32, height: u32, allocator: std.mem.Allocator) ![]u32 {
    const pixel_count = width * height;
    const argb_data = try allocator.alloc(u32, pixel_count);
    errdefer allocator.free(argb_data);

    var data_offset = offset;

    var y: i32 = @as(i32, @intCast(height)) - 1;
    while (y >= 0) : (y -= 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            if (data_offset + 4 > data.len) return BmpError.FileCorrupted;

            const b_byte = data[data_offset + 0];
            const g_byte = data[data_offset + 1];
            const r_byte = data[data_offset + 2];
            const a_byte = data[data_offset + 3];

            const r = (@as(u32, r_byte) & 255) << 16; // Red to bits 16-23
            const g = (@as(u32, g_byte) & 255) << 8; // Green to bits 8-15
            const b = (@as(u32, b_byte) & 255) << 0; // Blue to bits 0-7
            const a = (@as(u32, a_byte) & 255) << 24; // Alpha to bits 24-31

            const pixel_index = (@as(u32, @intCast(y)) * width) + x;
            argb_data[pixel_index] = a | b | g | r;

            data_offset += 4;
        }
    }

    return argb_data;
}

pub fn loadBmp(file_path: []const u8, allocator: std.mem.Allocator) !image_io.Image {
    const file_data = std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize)) catch |err| switch (err) {
        error.FileNotFound => return BmpError.FileCorrupted,
        else => return err,
    };
    defer allocator.free(file_data);

    if (file_data.len < @sizeOf(BitmapFileHeader) + @sizeOf(BitmapInfoHeader)) {
        return BmpError.FileCorrupted;
    }

    // Read file header
    const file_header = BitmapFileHeader{
        .bf_type = try readU16LE(file_data, 0),
        .bf_size = try readU32LE(file_data, 2),
        .bf_reserved1 = try readU16LE(file_data, 6),
        .bf_reserved2 = try readU16LE(file_data, 8),
        .bf_off_bits = try readU32LE(file_data, 10),
    };

    // Validate BMP signature
    if (file_header.bf_type != BMP_SIGNATURE) {
        return BmpError.InvalidSignature;
    }

    // Read info header
    const info_header = BitmapInfoHeader{
        .bi_size = try readU32LE(file_data, 14),
        .bi_width = try readI32LE(file_data, 18),
        .bi_height = try readI32LE(file_data, 22),
        .bi_planes = try readU16LE(file_data, 26),
        .bi_bit_count = try readU16LE(file_data, 28),
        .bi_compression = try readU32LE(file_data, 30),
        .bi_size_image = try readU32LE(file_data, 34),
        .bi_x_pels_per_meter = try readU32LE(file_data, 38),
        .bi_y_pels_per_meter = try readU32LE(file_data, 42),
        .bi_clr_used = try readU32LE(file_data, 46),
        .bi_clr_important = try readU32LE(file_data, 50),
    };

    // Validate dimensions
    if (info_header.bi_width <= 0 or info_header.bi_height == 0) {
        return BmpError.InvalidDimensions;
    }

    // Support uncompressed BMPs and BITFIELDS (for 32-bit BMPs)
    if (info_header.bi_compression != @intFromEnum(BiCompression.BI_RGB) and
        info_header.bi_compression != @intFromEnum(BiCompression.BI_BITFIELDS))
    {
        return BmpError.UnsupportedCompression;
    }

    // Get absolute dimensions (handle negative height)
    const width = @as(u32, @intCast(@abs(info_header.bi_width)));
    const height = @as(u32, @intCast(@abs(info_header.bi_height)));

    // Use the pixel data offset from the file header
    const pixel_offset = file_header.bf_off_bits;

    // Load pixel data based on bit depth
    const pixel_data = switch (info_header.bi_bit_count) {
        24 => try loadImage24Data(file_data, pixel_offset, width, height, allocator),
        32 => try loadImage32Data(file_data, pixel_offset, width, height, allocator),
        else => return BmpError.UnsupportedBitDepth,
    };

    return image_io.Image{
        .width = width,
        .height = height,
        .data = pixel_data,
        .allocator = allocator,
    };
}
