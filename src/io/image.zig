const std = @import("std");

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
