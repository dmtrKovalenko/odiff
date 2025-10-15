const std = @import("std");
const diff = @import("diff.zig");
const build_options = @import("build_options");

const print = std.debug.print;

pub const CliArgs = struct {
    base_image: []const u8,
    comp_image: []const u8,
    diff_output: ?[]const u8 = null,
    threshold: f32 = 0.1,
    diff_mask: bool = false,
    diff_overlay_factor: ?f32 = null,
    fail_on_layout: bool = false,
    parsable_stdout: bool = false,
    diff_color: []const u8 = "",
    antialiasing: bool = false,
    diff_lines: bool = false,
    reduce_ram_usage: bool = false,
    enable_asm: bool = false,
    ignore_regions: std.array_list.Managed(diff.IgnoreRegion),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CliArgs {
        return CliArgs{
            .base_image = "",
            .comp_image = "",
            .ignore_regions = std.array_list.Managed(diff.IgnoreRegion).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CliArgs) void {
        self.ignore_regions.deinit();
        if (self.base_image.len > 0) self.allocator.free(self.base_image);
        if (self.comp_image.len > 0) self.allocator.free(self.comp_image);
        if (self.diff_output) |output| {
            if (output.len > 0) self.allocator.free(output);
        }
        if (self.diff_color.len > 0) self.allocator.free(self.diff_color);
    }
};

fn printUsage(program_name: []const u8) void {
    print("Usage: {s} <base_image> <comp_image> [diff_output] [options]\n", .{program_name});
    print("\nOptions:\n", .{});
    print("  -t, --threshold <value>     Color difference threshold (0.0-1.0, default: 0.1)\n", .{});
    print("  --diff-mask                 Output only changed pixels over transparent background\n", .{});
    print("  --diff-overlay <value?>     Render diff output on the white background\n", .{});
    print("  --fail-on-layout            Fail if image dimensions differ\n", .{});
    print("  --parsable-stdout           Machine-readable output format\n", .{});
    print("  --diff-color <hex string>   Color for highlighting differences (e.g., #cd2cc9)\n", .{});
    print("  --aa, --antialiasing        Ignore antialiased pixels in diff\n", .{});
    print("  --output-diff-lines         Output line numbers with differences\n", .{});
    print("  --reduce-ram-usage          Use less memory (slower)\n", .{});
    print("  --enable-asm                Enable AVX-512 optimized asm path when supported (x86_64 only)\n", .{});
    print("  -i, --ignore <regions[]>    Ignore regions (format: x1:y1-x2:y2,x3:y3-x4:y4)\n", .{});
    print("  -h, --help                  Show this help message\n", .{});
    print("  --version                   Show version\n", .{});
    print("\nExit codes:\n", .{});
    print("  0  - Images match\n", .{});
    print("  21 - Layout difference (when --fail-on-layout is used)\n", .{});
    print("  22 - Pixel differences found\n", .{});
}

fn printVersion() void {
    print("odiff {s} - SIMD first pixel-by-pixel image comparison tool\n", .{build_options.version});
}

/// Parse float argument that supports both --option=value and --option value formats
/// Updates the index pointer and returns the parsed f32 value or null if not matched
fn parseFloatArg(args: [][:0]u8, index: *usize, option_name: []const u8) ?f32 {
    if (index.* >= args.len) return null;
    const arg = args[index.*];

    // --option=value format
    if (std.mem.startsWith(u8, arg, option_name) and
        arg.len > option_name.len and
        arg[option_name.len] == '=') {

        const value_str = arg[option_name.len + 1..];
        if (value_str.len == 0) return null;

        index.* += 1;
        return std.fmt.parseFloat(f32, value_str) catch null;
    }

    // --option {value} format
    if (std.mem.eql(u8, arg, option_name)) {
        if (index.* + 1 >= args.len) return null;

        const next_arg = args[index.* + 1];

        // Check if next argument is another option (starts with '-')
        if (std.mem.startsWith(u8, next_arg, "-")) return null;

        index.* += 2;
        return std.fmt.parseFloat(f32, next_arg) catch null;
    }

    return null;
}

fn parseIgnoreRegions(input: []const u8, list: *std.array_list.Managed(diff.IgnoreRegion)) !void {
    var regions_iter = std.mem.splitSequence(u8, input, ",");
    while (regions_iter.next()) |region_str| {
        // Parse format: x1:y1-x2:y2
        var coords_iter = std.mem.splitSequence(u8, region_str, "-");
        const start_coords = coords_iter.next() orelse return error.InvalidFormat;
        const end_coords = coords_iter.next() orelse return error.InvalidFormat;

        // Parse start coordinates
        var start_iter = std.mem.splitSequence(u8, start_coords, ":");
        const x1_str = start_iter.next() orelse return error.InvalidFormat;
        const y1_str = start_iter.next() orelse return error.InvalidFormat;

        // Parse end coordinates
        var end_iter = std.mem.splitSequence(u8, end_coords, ":");
        const x2_str = end_iter.next() orelse return error.InvalidFormat;
        const y2_str = end_iter.next() orelse return error.InvalidFormat;

        const x1 = try std.fmt.parseInt(u32, x1_str, 10);
        const y1 = try std.fmt.parseInt(u32, y1_str, 10);
        const x2 = try std.fmt.parseInt(u32, x2_str, 10);
        const y2 = try std.fmt.parseInt(u32, y2_str, 10);

        try list.append(.{ .x1 = x1, .y1 = y1, .x2 = x2, .y2 = y2 });
    }
}

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

pub fn parseArgs(allocator: std.mem.Allocator) !CliArgs {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        std.process.exit(1);
    }

    var parsed_args = CliArgs.init(allocator);
    var i: usize = 1;
    var positional_count: u32 = 0;

    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage(args[0]);
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "--version")) {
            printVersion();
            std.process.exit(0);
        } else if (parseFloatArg(args, &i, "--threshold") orelse parseFloatArg(args, &i, "-t")) |value| {
            parsed_args.threshold = value;
            continue;
        } else if (std.mem.eql(u8, arg, "--diff-mask")) {
            parsed_args.diff_mask = true;
        } else if (parseFloatArg(args, &i, "--diff-overlay")) |value| {
            parsed_args.diff_overlay_factor = value;
            continue;
        } else if (std.mem.eql(u8, arg, "--diff-overlay")) {
            parsed_args.diff_overlay_factor = 0.5;
        } else if (std.mem.eql(u8, arg, "--fail-on-layout")) {
            parsed_args.fail_on_layout = true;
        } else if (std.mem.eql(u8, arg, "--parsable-stdout")) {
            parsed_args.parsable_stdout = true;
        } else if (std.mem.eql(u8, arg, "--diff-color")) {
            i += 1;
            if (i >= args.len) {
                print("Error: --diff-color requires a value\n", .{});
                std.process.exit(1);
            }
            parsed_args.diff_color = try allocator.dupe(u8, args[i]);
        } else if (std.mem.eql(u8, arg, "--aa") or std.mem.eql(u8, arg, "--antialiasing")) {
            parsed_args.antialiasing = true;
        } else if (std.mem.eql(u8, arg, "--output-diff-lines")) {
            parsed_args.diff_lines = true;
        } else if (std.mem.eql(u8, arg, "--reduce-ram-usage")) {
            parsed_args.reduce_ram_usage = true;
        } else if (std.mem.eql(u8, arg, "--enable-asm")) {
            parsed_args.enable_asm = true;
        } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--ignore")) {
            i += 1;
            if (i >= args.len) {
                print("Error: --ignore requires a value\n", .{});
                std.process.exit(1);
            }
            parseIgnoreRegions(args[i], &parsed_args.ignore_regions) catch {
                print("Error: Invalid ignore regions format\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "--ignore=")) {
            const value_str = arg["--ignore=".len..];
            parseIgnoreRegions(value_str, &parsed_args.ignore_regions) catch {
                print("Error: Invalid ignore regions format\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "--diff-color=")) {
            const value_str = arg["--diff-color=".len..];
            parsed_args.diff_color = try allocator.dupe(u8, value_str);
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            // Positional argument
            switch (positional_count) {
                0 => parsed_args.base_image = try allocator.dupe(u8, arg),
                1 => parsed_args.comp_image = try allocator.dupe(u8, arg),
                2 => parsed_args.diff_output = try allocator.dupe(u8, arg),
                else => {
                    print("Error: Too many positional arguments\n", .{});
                    std.process.exit(1);
                },
            }
            positional_count += 1;
        } else {
            print("Error: Unknown option {s}\n", .{arg});
            printUsage(args[0]);

            std.process.exit(1);
        }

        i += 1;
    }

    if (positional_count < 2) {
        print("Error: Missing required arguments\n", .{});
        printUsage(args[0]);
        std.process.exit(1);
    }

    return parsed_args;
}
