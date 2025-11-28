const std = @import("std");

/// Parse hex color string (e.g., "#FF0000" or "FF0000") into RGBA u32 pixel value
/// Returns red (0xFF0000FF) as default if empty string is provided
/// Returns error.InvalidHexColor if format is invalid
pub fn parseHexColor(hex_str: []const u8) !u32 {
    if (hex_str.len == 0) return 0xFF0000FF; // Default red pixel

    var color_str = hex_str;
    if (hex_str[0] == '#') {
        color_str = hex_str[1..];
    }

    if (color_str.len != 6) return error.InvalidHexColor;

    const r = try std.fmt.parseInt(u8, color_str[0..2], 16);
    const g = try std.fmt.parseInt(u8, color_str[2..4], 16);
    const b = try std.fmt.parseInt(u8, color_str[4..6], 16);

    return (@as(u32, 255) << 24) | (@as(u32, b) << 16) | (@as(u32, g) << 8) | @as(u32, r);
}
