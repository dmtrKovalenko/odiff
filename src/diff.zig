// Core image diffing algorithm - equivalent to Diff.ml
const std = @import("std");
const builtin = @import("builtin");
const image_io = @import("image_io.zig");
const color_delta = @import("color_delta.zig");
const antialiasing = @import("antialiasing.zig");

const Image = image_io.Image;
const ArrayList = std.ArrayList;

const HAS_AVX512f = std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f);
const HAS_AVX512bwvl =
    HAS_AVX512f and
    std.Target.x86.featureSetHas(builtin.cpu.features, .avx512bw) and
    std.Target.x86.featureSetHas(builtin.cpu.features, .avx512vl);
const HAS_NEON = builtin.cpu.arch == .aarch64 and std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon);
const HAS_RVV = builtin.cpu.arch == .riscv64 and std.Target.riscv.featureSetHas(builtin.cpu.features, .v);

const RED_PIXEL: u32 = 0xFF0000FF;
const WHITE_PIXEL: u32 = 0xFFFFFFFF;
const MAX_YIQ_POSSIBLE_DELTA: f64 = 35215.0;

pub const DiffLines = struct {
    lines: []u32,
    count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_height: u32) !DiffLines {
        const lines = try allocator.alloc(u32, max_height);
        return DiffLines{
            .lines = lines,
            .count = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DiffLines) void {
        self.allocator.free(self.lines);
    }

    pub fn addLine(self: *DiffLines, line: u32) void {
        // Exactly match original logic: if (lines.items.len == 0 or lines.items[lines.items.len - 1] < y)
        if (self.count == 0 or (self.count > 0 and self.lines[self.count - 1] < line)) {
            if (self.count < self.lines.len) {
                self.lines[self.count] = line;
                self.count += 1;
            }
        }
    }

    pub fn getItems(self: *const DiffLines) []const u32 {
        return self.lines[0..self.count];
    }
};

pub const DiffVariant = union(enum) {
    layout,
    pixel: struct {
        diff_output: ?Image,
        diff_count: u32,
        diff_percentage: f64,
        diff_lines: ?DiffLines,
    },
};

pub const IgnoreRegion = struct {
    x1: u32,
    y1: u32,
    x2: u32,
    y2: u32,
};

pub const DiffOptions = struct {
    antialiasing: bool = false,
    output_diff_mask: bool = false,
    diff_overlay_factor: ?f32 = null,
    diff_lines: bool = false,
    diff_pixel: u32 = RED_PIXEL,
    threshold: f64 = 0.1,
    ignore_regions: ?[]const IgnoreRegion = null,
    capture_diff: bool = true,
    fail_on_layout_change: bool = true,
    enable_asm: bool = false,
};

fn unrollIgnoreRegions(width: u32, regions: ?[]const IgnoreRegion, allocator: std.mem.Allocator) !?[]struct { u32, u32 } {
    if (regions == null) return null;
    var unrolled = try allocator.alloc(struct { u32, u32 }, regions.?.len);
    for (regions.?, 0..) |region, i| {
        const p1 = (region.y1 * width) + region.x1;
        const p2 = (region.y2 * width) + region.x2;
        unrolled[i] = .{ p1, p2 };
    }
    return unrolled;
}

fn isInIgnoreRegion(offset: u32, regions: ?[]const struct { u32, u32 }) bool {
    if (regions == null) return false;

    for (regions.?) |region| {
        if (offset >= region[0] and offset <= region[1]) {
            return true;
        }
    }
    return false;
}

pub noinline fn compare(
    base: *const Image,
    comp: *const Image,
    options: DiffOptions,
    allocator: std.mem.Allocator,
) !struct { ?Image, u32, f64, ?DiffLines } {
    const max_delta_f64 = MAX_YIQ_POSSIBLE_DELTA * (options.threshold * options.threshold);
    const max_delta_i64: i64 = @intFromFloat(max_delta_f64 * @as(f64, @floatFromInt(1 << color_delta.COLOR_DELTA_SIMD_SHIFT)));

    var diff_output: ?Image = null;
    if (options.capture_diff) {
        if (options.diff_overlay_factor) |factor| {
            diff_output = try base.makeWithWhiteOverlay(factor, allocator);
        } else if (options.output_diff_mask) {
            diff_output = try base.makeSameAsLayout(allocator);
        } else {
            const data = try allocator.dupe(u32, base.data);
            diff_output = Image{
                .width = base.width,
                .height = base.height,
                .data = data,
                .allocator = allocator,
            };
        }
    }

    var diff_count: u32 = 0;
    var diff_lines: ?DiffLines = null;
    if (options.diff_lines) {
        const max_height = @max(base.height, comp.height);
        diff_lines = try DiffLines.init(allocator, max_height);
    }

    const ignore_regions = try unrollIgnoreRegions(base.width, options.ignore_regions, allocator);
    defer if (ignore_regions) |regions| allocator.free(regions);

    const layout_difference = base.width != comp.width or base.height != comp.height;

    // AVX diff only supports default options
    const threshold_ok = @abs(options.threshold - 0.1) < 0.0000001;
    const no_ignore_regions = options.ignore_regions == null or options.ignore_regions.?.len == 0;
    const avx_compatible = !options.antialiasing and no_ignore_regions and !options.capture_diff and !options.diff_lines and threshold_ok;

    if (options.enable_asm and HAS_AVX512bwvl and avx_compatible) {
        try compareAVX(base, comp, &diff_count);
    } else if (HAS_RVV and !options.antialiasing and (options.ignore_regions == null or options.ignore_regions.?.len == 0)) {
        try compareRVV(base, comp, &diff_output, &diff_count, if (diff_lines != null) &diff_lines.? else null, ignore_regions, max_delta_f64, options);
    } else if (layout_difference) {
        // slow path for different layout or weird widths
        try compareDifferentLayouts(base, comp, &diff_output, &diff_count, if (diff_lines != null) &diff_lines.? else null, ignore_regions, max_delta_i64, options);
    } else {
        try compareSameLayouts(base, comp, &diff_output, &diff_count, if (diff_lines != null) &diff_lines.? else null, ignore_regions, max_delta_i64, options);
    }

    const diff_percentage = 100.0 * @as(f64, @floatFromInt(diff_count)) /
        (@as(f64, @floatFromInt(base.width)) * @as(f64, @floatFromInt(base.height)));

    return .{ diff_output, diff_count, diff_percentage, diff_lines };
}

inline fn processPixelDifference(
    pixel_offset: usize,
    base_color: u32,
    comp_color: u32,
    x: u32,
    y: u32,
    base: *const Image,
    comp: *const Image,
    diff_output: *?Image,
    diff_count: *u32,
    diff_lines: ?*DiffLines,
    ignore_regions: ?[]struct { u32, u32 },
    max_delta: i64,
    options: DiffOptions,
) !void {
    const is_ignored = isInIgnoreRegion(@intCast(pixel_offset), ignore_regions);
    if (!is_ignored) {
        const delta = @call(.never_inline, color_delta.calculatePixelColorDeltaSimd, .{ base_color, comp_color });
        if (delta > max_delta) {
            var is_antialiased = false;

            if (options.antialiasing) {
                is_antialiased = antialiasing.detect(x, y, base, comp) or
                    antialiasing.detect(x, y, comp, base);
            }

            if (!is_antialiased) {
                diff_count.* += 1;
                if (diff_output.*) |*output| {
                    output.setImgColor(x, y, options.diff_pixel);
                }

                if (diff_lines) |lines| {
                    lines.addLine(y);
                }
            }
        }
    }
}

inline fn increment_coords(x: *u32, y: *u32, width: u32) void {
    x.* += 1;
    if (x.* >= width) {
        x.* = 0;
        y.* += 1;
    }
}

inline fn increment_coords_by(x: *u32, y: *u32, step: u32, width: u32) void {
    var remaining = step;
    while (remaining > 0) {
        const pixels_to_end_of_row = width - x.*;
        if (remaining >= pixels_to_end_of_row) {
            remaining -= pixels_to_end_of_row;
            x.* = 0;
            y.* += 1;
        } else {
            x.* += remaining;
            remaining = 0;
        }
    }
}

pub noinline fn compareSameLayouts(base: *const Image, comp: *const Image, diff_output: *?Image, diff_count: *u32, diff_lines: ?*DiffLines, ignore_regions: ?[]struct { u32, u32 }, max_delta: i64, options: DiffOptions) !void {
    var x: u32 = 0;
    var y: u32 = 0;

    const size = (base.height * base.width);
    const base_data = base.data;
    const comp_data = comp.data;

    const SIMD_SIZE = std.simd.suggestVectorLength(u32) orelse if (HAS_AVX512f) 16 else if (HAS_NEON) 8 else 4;
    const simd_end = (size / SIMD_SIZE) * SIMD_SIZE;

    var offset: usize = 0;
    while (offset < simd_end) : (offset += SIMD_SIZE) {
        const base_vec: @Vector(SIMD_SIZE, u32) = base_data[offset .. offset + SIMD_SIZE][0..SIMD_SIZE].*;
        const comp_vec: @Vector(SIMD_SIZE, u32) = comp_data[offset .. offset + SIMD_SIZE][0..SIMD_SIZE].*;

        const diff_mask = base_vec != comp_vec;
        if (!@reduce(.Or, diff_mask)) {
            increment_coords_by(&x, &y, SIMD_SIZE, base.width);
            continue;
        }

        for (0..SIMD_SIZE) |i| {
            if (diff_mask[i]) {
                const pixel_offset = offset + i;
                const base_color = base_vec[i];
                const comp_color = comp_vec[i];

                try processPixelDifference(
                    pixel_offset,
                    base_color,
                    comp_color,
                    x,
                    y,
                    base,
                    comp,
                    diff_output,
                    diff_count,
                    diff_lines,
                    ignore_regions,
                    max_delta,
                    options,
                );
            }
            increment_coords(&x, &y, base.width);
        }
    }

    // Handle remaining pixels
    while (offset < size) : (offset += 1) {
        const base_color = base_data[offset];
        const comp_color = comp_data[offset];

        if (base_color != comp_color) {
            try processPixelDifference(
                offset,
                base_color,
                comp_color,
                x,
                y,
                base,
                comp,
                diff_output,
                diff_count,
                diff_lines,
                ignore_regions,
                max_delta,
                options,
            );
        }
        increment_coords(&x, &y, base.width);
    }
}

pub fn compareDifferentLayouts(base: *const Image, comp: *const Image, maybe_diff_output: *?Image, diff_count: *u32, diff_lines: ?*DiffLines, ignore_regions: ?[]struct { u32, u32 }, max_delta: i64, options: DiffOptions) !void {
    var x: u32 = 0;
    var y: u32 = 0;
    var offset: u32 = 0;

    const size = (base.height * base.width);
    while (offset < size) : (offset += 1) {
        const base_color = base.readRawPixel(x, y);

        if (x >= comp.width or y >= comp.height) {
            const alpha = (base_color >> 24) & 0xFF;
            if (alpha != 0) {
                diff_count.* += 1;
                if (maybe_diff_output.*) |*output| {
                    output.setImgColor(x, y, options.diff_pixel);
                }

                if (diff_lines) |lines| {
                    lines.addLine(y);
                }
            }
        } else {
            const comp_color = comp.readRawPixel(x, y);

            try processPixelDifference(
                offset,
                base_color,
                comp_color,
                x,
                y,
                base,
                comp,
                maybe_diff_output,
                diff_count,
                diff_lines,
                ignore_regions,
                max_delta,
                options,
            );
        }

        increment_coords(&x, &y, base.width);
    }
}

pub fn compareAVX(base: *const Image, comp: *const Image, diff_count: *u32) !void {
    if (!HAS_AVX512bwvl) return error.Invalid;

    const base_ptr: [*]const u8 = @ptrCast(@alignCast(base.data.ptr));
    const comp_ptr: [*]const u8 = @ptrCast(@alignCast(comp.data.ptr));

    const base_w: usize = base.width;
    const base_h: usize = base.height;
    const comp_w: usize = comp.width;
    const comp_h: usize = comp.height;

    diff_count.* = vxdiff(base_ptr, comp_ptr, base_w, comp_w, base_h, comp_h);
}

extern fn vxdiff(
    base_rgba: [*]const u8,
    comp_rgba: [*]const u8,
    base_width: usize,
    comp_width: usize,
    base_height: usize,
    comp_height: usize,
) u32;

extern fn odiffRVV(
    basePtr: [*]const u32,
    compPtr: [*]const u32,
    size: usize,
    max_delta: f32,
    diff: ?[*]u32,
    diffcol: u32,
) u32;

pub noinline fn compareRVV(base: *const Image, comp: *const Image, diff_output: *?Image, diff_count: *u32, diff_lines: ?*DiffLines, ignore_regions: ?[]struct { u32, u32 }, max_delta: f64, options: DiffOptions) !void {
    _ = ignore_regions;
    const basePtr: [*]const u32 = @ptrCast(@alignCast(base.data.ptr));
    const compPtr: [*]const u32 = @ptrCast(@alignCast(comp.data.ptr));
    var diffPtr: ?[*]u32 = null;
    if (diff_output.*) |*out| {
        diffPtr = @ptrCast(@alignCast(out.data.ptr));
    }

    const line_by_line = base.width != comp.width or base.height != comp.height or diff_lines != null;
    if (line_by_line) {
        var y: u32 = 0;
        const minHeight = @min(base.height, comp.height);
        const minWidth = @min(base.width, comp.width);
        while (y < base.height) : (y += 1) {
            var cnt: u32 = 0;
            var x: u32 = 0;
            if (y < minHeight) {
                if (diffPtr) |ptr| {
                    cnt = odiffRVV(basePtr + y * base.width, compPtr + y * comp.width, minWidth, @floatCast(max_delta), ptr + y * base.width, options.diff_pixel);
                } else {
                    cnt = odiffRVV(basePtr + y * base.width, compPtr + y * comp.width, minWidth, @floatCast(max_delta), null, options.diff_pixel);
                }
                x = minWidth;
            }
            while (x < base.width) : (x += 1) {
                const idx = y * base.width + x;
                const alpha = (basePtr[idx] >> 24) & 0xFF;
                cnt += if (alpha != 0) 1 else 0;
                if (diffPtr) |ptr| {
                    const old = ptr[idx]; // always read/write for better autovec
                    ptr[idx] = if (alpha != 0) options.diff_pixel else old;
                }
            }
            if (diff_lines) |lines| {
                if (cnt > 0) {
                    lines.addLine(y);
                }
            }
            diff_count.* += cnt;
        }
    } else {
        diff_count.* += odiffRVV(basePtr, compPtr, base.height * base.width, @floatCast(max_delta), diffPtr, options.diff_pixel);
    }
}

pub fn diff(
    base: *const Image,
    comp: *const Image,
    options: DiffOptions,
    allocator: std.mem.Allocator,
) !DiffVariant {
    if (options.fail_on_layout_change and (base.width != comp.width or base.height != comp.height)) {
        return DiffVariant.layout;
    }

    const diff_output, const diff_count, const diff_percentage, const diff_lines = try compare(base, comp, options, allocator);
    return DiffVariant{ .pixel = .{
        .diff_output = diff_output,
        .diff_count = diff_count,
        .diff_percentage = diff_percentage,
        .diff_lines = diff_lines,
    } };
}
