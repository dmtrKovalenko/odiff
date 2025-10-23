const std = @import("std");
const math = std.math;

pub const Pixel = struct {
    r: f64,
    g: f64,
    b: f64,
    a: f64,
};

const WHITE_PIXEL = Pixel{ .r = 255.0, .g = 255.0, .b = 255.0, .a = 0.0 };

const YIQ_Y_R_COEFF = 0.29889531;
const YIQ_Y_G_COEFF = 0.58662247;
const YIQ_Y_B_COEFF = 0.11448223;

const YIQ_I_R_COEFF = 0.59597799;
const YIQ_I_G_COEFF = -0.27417610;
const YIQ_I_B_COEFF = -0.32180189;

const YIQ_Q_R_COEFF = 0.21147017;
const YIQ_Q_G_COEFF = -0.52261711;
const YIQ_Q_B_COEFF = 0.31114694;

const YIQ_Y_WEIGHT = 0.5053;
const YIQ_I_WEIGHT = 0.299;
const YIQ_Q_WEIGHT = 0.1957;

inline fn blendChannelWhite(color: f64, alpha: f64) f64 {
    return 255.0 + ((color - 255.0) * alpha);
}

pub inline fn blendSemiTransparentPixel(pixel: Pixel) Pixel {
    if (pixel.a == 0.0) return WHITE_PIXEL;
    if (pixel.a == 255.0) return Pixel{ .r = pixel.r, .g = pixel.g, .b = pixel.b, .a = 1.0 };
    if (pixel.a < 255.0) {
        const normalized_alpha = pixel.a / 255.0;
        return Pixel{
            .r = blendChannelWhite(pixel.r, normalized_alpha),
            .g = blendChannelWhite(pixel.g, normalized_alpha),
            .b = blendChannelWhite(pixel.b, normalized_alpha),
            .a = normalized_alpha,
        };
    }
    unreachable; // Alpha > 255
}

pub inline fn decodeRawPixel(raw_pixel: u32) Pixel {
    const a: f64 = @floatFromInt((raw_pixel >> 24) & 0xFF);
    const b: f64 = @floatFromInt((raw_pixel >> 16) & 0xFF);
    const g: f64 = @floatFromInt((raw_pixel >> 8) & 0xFF);
    const r: f64 = @floatFromInt(raw_pixel & 0xFF);

    return Pixel{ .r = r, .g = g, .b = b, .a = a };
}

inline fn rgb2y(pixel: Pixel) f64 {
    return (pixel.r * YIQ_Y_R_COEFF) + (pixel.g * YIQ_Y_G_COEFF) + (pixel.b * YIQ_Y_B_COEFF);
}

inline fn rgb2i(pixel: Pixel) f64 {
    return (pixel.r * YIQ_I_R_COEFF) + (pixel.g * YIQ_I_G_COEFF) + (pixel.b * YIQ_I_B_COEFF);
}

inline fn rgb2q(pixel: Pixel) f64 {
    return (pixel.r * YIQ_Q_R_COEFF) + (pixel.g * YIQ_Q_G_COEFF) + (pixel.b * YIQ_Q_B_COEFF);
}

pub fn calculatePixelColorDelta(pixel_a: u32, pixel_b: u32) f64 {
    const decoded_a = blendSemiTransparentPixel(decodeRawPixel(pixel_a));
    const decoded_b = blendSemiTransparentPixel(decodeRawPixel(pixel_b));

    const y = rgb2y(decoded_a) - rgb2y(decoded_b);
    const i = rgb2i(decoded_a) - rgb2i(decoded_b);
    const q = rgb2q(decoded_a) - rgb2q(decoded_b);

    return (YIQ_Y_WEIGHT * y * y) + (YIQ_I_WEIGHT * i * i) + (YIQ_Q_WEIGHT * q * q);
}

pub fn calculatePixelBrightnessDelta(pixel_a: u32, pixel_b: u32) f64 {
    const decoded_a = blendSemiTransparentPixel(decodeRawPixel(pixel_a));
    const decoded_b = blendSemiTransparentPixel(decodeRawPixel(pixel_b));

    return rgb2y(decoded_a) - rgb2y(decoded_b);
}

// SIMD version of the same algorithm based on the shifted integer arithmetic
pub const COLOR_DELTA_SIMD_SHIFT = 12;
const SHIFTED_1 = 1 << COLOR_DELTA_SIMD_SHIFT;

const VEC_2X_SHIFT: @Vector(2, i64) = @splat(COLOR_DELTA_SIMD_SHIFT);
const VEC_2X_SHIFTED_ONE: @Vector(2, i64) = @splat(SHIFTED_1);

const VEC_YIQ_Y_R_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_Y_R_COEFF * SHIFTED_1)));
const VEC_YIQ_Y_G_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_Y_G_COEFF * SHIFTED_1)));
const VEC_YIQ_Y_B_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_Y_B_COEFF * SHIFTED_1)));

const VEC_YIQ_I_R_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_I_R_COEFF * SHIFTED_1)));
const VEC_YIQ_I_G_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_I_G_COEFF * SHIFTED_1)));
const VEC_YIQ_I_B_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_I_B_COEFF * SHIFTED_1)));

const VEC_YIQ_Q_R_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_Q_R_COEFF * SHIFTED_1)));
const VEC_YIQ_Q_G_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_Q_G_COEFF * SHIFTED_1)));
const VEC_YIQ_Q_B_COEFF: @Vector(2, i64) = @splat(@as(i64, @intFromFloat(YIQ_Q_B_COEFF * SHIFTED_1)));

inline fn blendChannelSimd(
    channel_vec: @Vector(2, i64),
    vec_alpha: @Vector(2, i64),
) @Vector(2, i64) {
    const VEC_2X_255: @Vector(2, i64) = @splat(255);
    const VEC_2X_0: @Vector(2, i64) = @splat(0);
    const VEC_2X_WHITE_SHIFTED = comptime VEC_2X_255 << VEC_2X_SHIFT;

    const alpha_zero = vec_alpha == VEC_2X_0;
    const alpha_full = vec_alpha == VEC_2X_255;

    const opaque_value = channel_vec << VEC_2X_SHIFT;
    const blended = VEC_2X_WHITE_SHIFTED + @divTrunc((channel_vec - VEC_2X_255) * vec_alpha * VEC_2X_SHIFTED_ONE, VEC_2X_255);

    return @select(i64, alpha_zero, VEC_2X_WHITE_SHIFTED, @select(i64, alpha_full, opaque_value, blended));
}

pub fn calculatePixelColorDeltaSimd(pixel_a: u32, pixel_b: u32) i64 {
    const pixels: @Vector(2, u32) = .{ pixel_a, pixel_b };
    const mask_ff: @Vector(2, u32) = comptime @splat(0xFF);

    const vec_r_u32 = pixels & mask_ff;
    const vec_g_u32 = (pixels >> @as(@Vector(2, u5), @splat(8))) & mask_ff;
    const vec_b_u32 = (pixels >> @as(@Vector(2, u5), @splat(16))) & mask_ff; const vec_alpha_u32 = (pixels >> @as(@Vector(2, u5), @splat(24))) & mask_ff;

    const vec_r: @Vector(2, i64) = @intCast(vec_r_u32);
    const vec_g: @Vector(2, i64) = @intCast(vec_g_u32);
    const vec_b: @Vector(2, i64) = @intCast(vec_b_u32);
    const vec_alpha: @Vector(2, i64) = @intCast(vec_alpha_u32);

    const blended_r = blendChannelSimd(vec_r, vec_alpha);
    const blended_g = blendChannelSimd(vec_g, vec_alpha);
    const blended_b = blendChannelSimd(vec_b, vec_alpha);

    const vec_y = (blended_r * VEC_YIQ_Y_R_COEFF + blended_g * VEC_YIQ_Y_G_COEFF + blended_b * VEC_YIQ_Y_B_COEFF) >> VEC_2X_SHIFT;
    const vec_i = (blended_r * VEC_YIQ_I_R_COEFF + blended_g * VEC_YIQ_I_G_COEFF + blended_b * VEC_YIQ_I_B_COEFF) >> VEC_2X_SHIFT;
    const vec_q = (blended_r * VEC_YIQ_Q_R_COEFF + blended_g * VEC_YIQ_Q_G_COEFF + blended_b * VEC_YIQ_Q_B_COEFF) >> VEC_2X_SHIFT;

    const y_diff = vec_y[0] - vec_y[1];
    const i_diff = vec_i[0] - vec_i[1];
    const q_diff = vec_q[0] - vec_q[1];

    const Y_WEIGHT = comptime @as(i64, @intFromFloat(YIQ_Y_WEIGHT * SHIFTED_1));
    const I_WEIGHT = comptime @as(i64, @intFromFloat(YIQ_I_WEIGHT * SHIFTED_1));
    const Q_WEIGHT = comptime @as(i64, @intFromFloat(YIQ_Q_WEIGHT * SHIFTED_1));

    return (y_diff * y_diff * Y_WEIGHT + i_diff * i_diff * I_WEIGHT + q_diff * q_diff * Q_WEIGHT) >> (2 * COLOR_DELTA_SIMD_SHIFT);
}
