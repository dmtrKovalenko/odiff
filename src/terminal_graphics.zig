const std = @import("std");
const builtin = @import("builtin");
const io = @import("io.zig");

const raw_chunk_size = 3072;

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
            try stdout.print("\x1b_Ga=T,f=100,m={d};{s}\x1b\\", .{ @intFromBool(has_more), encoded_chunk });
            first = false;
        } else {
            try stdout.print("\x1b_Gm={d};{s}\x1b\\", .{ @intFromBool(has_more), encoded_chunk });
        }

        offset = chunk_end;
    }

    try stdout.writeAll("\n");
    try stdout.flush();
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
