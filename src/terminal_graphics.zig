const std = @import("std");
const builtin = @import("builtin");
const io = @import("io.zig");

const raw_chunk_size = 3072;
const reserved_text_rows = 3;

const TerminalSize = struct {
    rows: u16,
    cols: u16,
    pixel_width: u16,
    pixel_height: u16,
};

const PlacementSize = struct {
    rows: u32,
    cols: u32,
};

pub fn isSupported() bool {
    if (!stdoutIsTty()) return false;

    if (hasEnv("KITTY_WINDOW_ID")) return true;
    if (hasEnv("WEZTERM_EXECUTABLE")) return true;
    if (hasEnv("WEZTERM_PANE")) return true;
    if (hasEnv("GHOSTTY_RESOURCES_DIR")) return true;
    if (hasEnv("ITERM_SESSION_ID")) return true;
    if (hasEnv("KONSOLE_VERSION")) return true;
    if (hasEnv("WARP_IS_LOCAL_SHELL_SESSION")) return true;

    if (envContainsAny("TERM", &.{
        "xterm-kitty",
        "wezterm",
        "ghostty",
        "konsole",
        "wayst",
        "xterm.js",
    })) return true;

    if (envContainsAny("TERM_PROGRAM", &.{
        "kitty",
        "wezterm",
        "ghostty",
        "iterm",
        "warp",
        "konsole",
        "wayst",
        "xterm.js",
    })) return true;

    return false;
}

pub fn displayImage(
    stdout: *std.Io.Writer,
    allocator: std.mem.Allocator,
    img: io.Image,
) !void {
    const png_bytes = try io.encodePngAlloc(allocator, img);
    defer allocator.free(png_bytes);

    var encoded_buffer: [4096]u8 = undefined;
    var offset: usize = 0;
    var first = true;
    while (offset < png_bytes.len) {
        const chunk_end = @min(offset + raw_chunk_size, png_bytes.len);
        const raw_chunk = png_bytes[offset..chunk_end];
        const has_more = chunk_end < png_bytes.len;

        const encoded_chunk = encoded_buffer[0..std.base64.standard.Encoder.calcSize(raw_chunk.len)];
        _ = std.base64.standard.Encoder.encode(encoded_chunk, raw_chunk);

        if (first) {
            if (placementForImage(img)) |placement| {
                try stdout.print("\x1b_Ga=T,f=100,c={d},r={d},m={d};{s}\x1b\\", .{
                    placement.cols,
                    placement.rows,
                    @intFromBool(has_more),
                    encoded_chunk,
                });
            } else {
                try stdout.print("\x1b_Ga=T,f=100,m={d};{s}\x1b\\", .{ @intFromBool(has_more), encoded_chunk });
            }
            first = false;
        } else {
            try stdout.print("\x1b_Gm={d};{s}\x1b\\", .{ @intFromBool(has_more), encoded_chunk });
        }

        offset = chunk_end;
    }

    try stdout.writeAll("\n");
    try stdout.flush();
}

fn placementForImage(img: io.Image) ?PlacementSize {
    const terminal_size = readTerminalSize() orelse return null;
    return calculatePlacementSize(img.width, img.height, terminal_size);
}

fn calculatePlacementSize(image_width: u32, image_height: u32, terminal_size: TerminalSize) ?PlacementSize {
    if (image_width == 0 or image_height == 0) return null;
    if (terminal_size.rows <= reserved_text_rows or terminal_size.cols == 0) return null;
    if (terminal_size.pixel_width == 0 or terminal_size.pixel_height == 0) return null;

    const drawable_rows = terminal_size.rows - reserved_text_rows;
    const max_pixel_width = terminal_size.pixel_width;
    const max_pixel_height = @as(u32, terminal_size.pixel_height) * drawable_rows / terminal_size.rows;

    if (max_pixel_width == 0 or max_pixel_height == 0) return null;
    if (image_width <= max_pixel_width and image_height <= max_pixel_height) return null;

    const scaled_by_width = @as(u64, max_pixel_width) * image_height <= @as(u64, max_pixel_height) * image_width;
    const target_pixel_width, const target_pixel_height = if (scaled_by_width)
        .{ max_pixel_width, ceilDivU32(image_height, max_pixel_width, image_width) }
    else
        .{ ceilDivU32(image_width, max_pixel_height, image_height), max_pixel_height };

    const cell_pixel_width = @max(1, terminal_size.pixel_width / terminal_size.cols);
    const cell_pixel_height = @max(1, terminal_size.pixel_height / terminal_size.rows);

    return .{
        .cols = @min(terminal_size.cols, @max(1, ceilDivU32(target_pixel_width, 1, cell_pixel_width))),
        .rows = @min(drawable_rows, @max(1, ceilDivU32(target_pixel_height, 1, cell_pixel_height))),
    };
}

fn ceilDivU32(value: u32, numerator: u32, denominator: u32) u32 {
    const result = (@as(u64, value) * numerator + denominator - 1) / denominator;
    return @intCast(result);
}

fn readTerminalSize() ?TerminalSize {
    return switch (builtin.os.tag) {
        .windows => null,
        else => {
            var winsize: std.posix.winsize = .{
                .row = 0,
                .col = 0,
                .xpixel = 0,
                .ypixel = 0,
            };

            const err = std.posix.system.ioctl(std.fs.File.stdout().handle, std.posix.T.IOCGWINSZ, @intFromPtr(&winsize));
            if (std.posix.errno(err) != .SUCCESS) return null;
            if (winsize.row == 0 or winsize.col == 0 or winsize.xpixel == 0 or winsize.ypixel == 0) return null;

            return .{
                .rows = winsize.row,
                .cols = winsize.col,
                .pixel_width = winsize.xpixel,
                .pixel_height = winsize.ypixel,
            };
        },
    };
}

fn stdoutIsTty() bool {
    return switch (builtin.os.tag) {
        .windows => true,
        else => std.c.isatty(std.fs.File.stdout().handle) == 1,
    };
}

fn hasEnv(name: [:0]const u8) bool {
    return envValue(name) != null;
}

fn envContainsAny(name: [:0]const u8, needles: []const []const u8) bool {
    const value = envValue(name) orelse return false;

    for (needles) |needle| {
        if (std.ascii.indexOfIgnoreCase(value, needle) != null) return true;
    }

    return false;
}

fn envValue(name: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(name.ptr) orelse return null;
    return std.mem.span(value);
}

test "raw chunk size encodes to kitty's 4096 byte maximum" {
    try std.testing.expectEqual(@as(usize, 4096), std.base64.standard.Encoder.calcSize(raw_chunk_size));
}

test "placement is omitted when image fits" {
    const terminal_size = TerminalSize{ .rows = 40, .cols = 100, .pixel_width = 1000, .pixel_height = 800 };
    try std.testing.expect(calculatePlacementSize(500, 300, terminal_size) == null);
}

test "placement scales down wide image" {
    const terminal_size = TerminalSize{ .rows = 40, .cols = 100, .pixel_width = 1000, .pixel_height = 800 };
    const placement = calculatePlacementSize(2000, 400, terminal_size).?;
    try std.testing.expectEqual(@as(u32, 100), placement.cols);
    try std.testing.expectEqual(@as(u32, 10), placement.rows);
}

test "placement scales down tall image and reserves text row" {
    const terminal_size = TerminalSize{ .rows = 40, .cols = 100, .pixel_width = 1000, .pixel_height = 800 };
    const placement = calculatePlacementSize(400, 1200, terminal_size).?;
    try std.testing.expectEqual(@as(u32, 25), placement.cols);
    try std.testing.expectEqual(@as(u32, 37), placement.rows);
}

test "placement clamps to at least one cell" {
    const terminal_size = TerminalSize{ .rows = 4, .cols = 1, .pixel_width = 10, .pixel_height = 40 };
    const placement = calculatePlacementSize(10000, 10000, terminal_size).?;
    try std.testing.expectEqual(@as(u32, 1), placement.cols);
    try std.testing.expectEqual(@as(u32, 1), placement.rows);
}
