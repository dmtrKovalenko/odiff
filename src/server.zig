const std = @import("std");
const odiff = @import("odiff_lib");

/// Buffered JSON response writer for server mode
/// Ensures all responses are written with minimal syscalls
const ResponseWriter = struct {
    stdout: std.fs.File,
    allocator: std.mem.Allocator,

    pub fn init(stdout: std.fs.File, allocator: std.mem.Allocator) ResponseWriter {
        return .{
            .stdout = stdout,
            .allocator = allocator,
        };
    }

    pub fn writeReady(self: *ResponseWriter) !void {
        try self.stdout.writeAll("{\"ready\":true}\n");
    }

    pub fn writeError(
        self: *ResponseWriter,
        request_id: ?std.json.Value,
        error_message: []const u8,
    ) !void {
        // assume we don't have messages longer than 1024 bytes
        var buf: [1024]u8 = undefined;
        const response = if (request_id) |rid|
            try std.fmt.bufPrint(&buf, "{{\"requestId\":{d},\"error\":\"{s}\"}}\n", .{ rid.integer, error_message })
        else
            try std.fmt.bufPrint(&buf, "{{\"error\":\"{s}\"}}\n", .{error_message});
        try self.stdout.writeAll(response);
    }

    pub fn writeMatch(self: *ResponseWriter, request_id: std.json.Value) !void {
        var buf: [256]u8 = undefined;
        const response = try std.fmt.bufPrint(&buf, "{{\"requestId\":{d},\"match\":true}}\n", .{request_id.integer});
        try self.stdout.writeAll(response);
    }

    pub fn writeLayoutDiff(self: *ResponseWriter, request_id: std.json.Value) !void {
        var buf: [256]u8 = undefined;
        const response = try std.fmt.bufPrint(&buf, "{{\"requestId\":{d},\"match\":false,\"reason\":\"layout-diff\"}}\n", .{request_id.integer});
        try self.stdout.writeAll(response);
    }

    pub fn writePixelDiff(
        self: *ResponseWriter,
        request_id: std.json.Value,
        diff_count: u64,
        diff_percentage: f64,
    ) !void {
        var buf: [512]u8 = undefined;
        const response = try std.fmt.bufPrint(
            &buf,
            "{{\"requestId\":{d},\"match\":false,\"reason\":\"pixel-diff\",\"diffCount\":{d},\"diffPercentage\":{d:.2}}}\n",
            .{ request_id.integer, diff_count, diff_percentage },
        );
        try self.stdout.writeAll(response);
    }

    /// A complicated path for a buffer because it requires unknown length of array allocation
    pub fn writePixelDiffWithLines(
        self: *ResponseWriter,
        request_id: std.json.Value,
        diff_count: u64,
        diff_percentage: f64,
        diff_lines: odiff.DiffLines,
    ) !void {
        var response = try std.array_list.Managed(u8).initCapacity(self.allocator, diff_lines.count * 2);
        defer response.deinit();
        const writer = response.writer();

        try writer.print(
            "{{\"requestId\":{d},\"match\":false,\"reason\":\"pixel-diff\",\"diffCount\":{d},\"diffPercentage\":{d:.2},\"diffLines\":[",
            .{ request_id.integer, diff_count, diff_percentage },
        );

        for (diff_lines.lines, 0..) |line, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{d}", .{line});
        }
        try writer.writeAll("]}");
        try writer.writeByte('\n');

        // Single write to stdout
        try self.stdout.writeAll(response.items);
    }
};

/// Helper functions for parsing JSON options with defaults
fn parseBool(options_obj: ?std.json.ObjectMap, key: []const u8, default: bool) bool {
    if (options_obj) |o| {
        if (o.get(key)) |v| if (v == .bool) return v.bool;
    }
    return default;
}

fn parseFloat(options_obj: ?std.json.ObjectMap, key: []const u8, default: f32) f32 {
    if (options_obj) |o| {
        if (o.get(key)) |v| if (v == .float) return @floatCast(v.float);
    }
    return default;
}

fn parseString(options_obj: ?std.json.ObjectMap, key: []const u8, default: []const u8) []const u8 {
    if (options_obj) |o| {
        if (o.get(key)) |v| if (v == .string) return v.string;
    }
    return default;
}

fn parseDiffOverlay(options_obj: ?std.json.ObjectMap, key: []const u8) ?f32 {
    if (options_obj) |o| {
        if (o.get(key)) |v| {
            return switch (v) {
                .bool => |b| if (b) @as(f32, 0.5) else null,
                .float => |f| @floatCast(f),
                .integer => |i| @floatCast(@as(f64, @floatFromInt(i))),
                else => null,
            };
        }
    }
    return null;
}

fn parseIgnoreRegions(
    options_obj: ?std.json.ObjectMap,
    allocator: std.mem.Allocator,
    response_writer: *ResponseWriter,
    request_id: std.json.Value,
) ![]odiff.IgnoreRegion {
    // If ignoreRegions field is not present, return empty slice
    const regions_value = if (options_obj) |o| o.get("ignoreRegions") else null;
    if (regions_value == null) {
        return &[_]odiff.IgnoreRegion{};
    }

    // Validate it's an array
    if (regions_value.? != .array) {
        try response_writer.writeError(request_id, "ignoreRegions must be an array");
        return error.InvalidIgnoreRegions;
    }

    const regions_array = regions_value.?.array;
    if (regions_array.items.len == 0) {
        return &[_]odiff.IgnoreRegion{};
    }

    // Allocate array for regions
    const ignore_regions = try allocator.alloc(odiff.IgnoreRegion, regions_array.items.len);
    errdefer allocator.free(ignore_regions);

    // Parse each region
    for (regions_array.items, 0..) |region_value, i| {
        if (region_value != .object) {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "ignoreRegions[{d}] must be an object", .{i});
            try response_writer.writeError(request_id, msg);
            return error.InvalidIgnoreRegions;
        }

        const region_obj = region_value.object;

        // Helper to get required field
        const get_coord = struct {
            fn get(obj: std.json.ObjectMap, field: []const u8, index: usize, writer: *ResponseWriter, rid: std.json.Value) !u32 {
                const val = obj.get(field) orelse {
                    var buf: [256]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "ignoreRegions[{d}]: missing required field '{s}'", .{ index, field });
                    try writer.writeError(rid, msg);
                    return error.MissingField;
                };

                if (val != .integer) {
                    var buf: [256]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "ignoreRegions[{d}].{s} must be a number", .{ index, field });
                    try writer.writeError(rid, msg);
                    return error.InvalidType;
                }

                return @intCast(val.integer);
            }
        }.get;

        const x1 = try get_coord(region_obj, "x1", i, response_writer, request_id);
        const y1 = try get_coord(region_obj, "y1", i, response_writer, request_id);
        const x2 = try get_coord(region_obj, "x2", i, response_writer, request_id);
        const y2 = try get_coord(region_obj, "y2", i, response_writer, request_id);

        ignore_regions[i] = .{ .x1 = x1, .y1 = y1, .x2 = x2, .y2 = y2 };
    }

    return ignore_regions;
}

fn parsePath(obj: std.json.ObjectMap, key: []const u8, response_writer: *ResponseWriter, request_id: std.json.Value) ![]const u8 {
    const value = obj.get(key) orelse {
        var buf: [128]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "Missing {s} path", .{key});
        try response_writer.writeError(request_id, msg);
        return error.MissingPath;
    };
    if (value != .string) {
        try response_writer.writeError(request_id, "Path must be a string");
        return error.InvalidPath;
    }
    return value.string;
}

// Server mode: Read JSON requests from stdin, output JSON responses to stdout
pub fn runServerMode(allocator: std.mem.Allocator) !void {
    const stdin = std.fs.File.stdin();
    const stdout = std.fs.File.stdout();

    var response_writer = ResponseWriter.init(stdout, allocator);
    try response_writer.writeReady();

    // Use buffered reader for efficient line-by-line reading
    var stdin_buffer: [8192]u8 = undefined;
    var file_reader = stdin.reader(&stdin_buffer);
    const reader = &file_reader.interface;

    while (true) {
        const line = try reader.takeDelimiter('\n') orelse return; // EOF
        if (line.len == 0) continue;

        const parsed = std.json.parseFromSlice(
            std.json.Value,
            allocator,
            line,
            .{},
        ) catch {
            try response_writer.writeError(null, "Invalid JSON");
            continue;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) {
            try response_writer.writeError(null, "Expected JSON object");
            continue;
        }

        const obj = root.object;

        // request_id is mandatory
        const request_id = obj.get("requestId") orelse {
            try response_writer.writeError(null, "Missing requestId field");
            continue;
        };
        if (request_id != .integer) {
            try response_writer.writeError(null, "requestId must be an integer");
            continue;
        }

        const base_path = parsePath(obj, "base", &response_writer, request_id) catch continue;
        const compare_path = parsePath(obj, "compare", &response_writer, request_id) catch continue;
        const output_path = parsePath(obj, "output", &response_writer, request_id) catch continue;

        const options_obj = if (obj.get("options")) |opt| opt.object else null;

        const threshold = parseFloat(options_obj, "threshold", 0.1);
        const fail_on_layout = parseBool(options_obj, "failOnLayoutDiff", false);
        const antialiasing = parseBool(options_obj, "antialiasing", false);
        const capture_diff_lines = parseBool(options_obj, "captureDiffLines", false);
        const output_diff_mask = parseBool(options_obj, "outputDiffMask", false);

        const diff_color_str = parseString(options_obj, "diffColor", "");
        const diff_pixel = odiff.utils.parseHexColor(diff_color_str) catch {
            try response_writer.writeError(request_id, "Invalid diffColor hex format");
            continue;
        };

        const diff_overlay_factor = parseDiffOverlay(options_obj, "diffOverlay");

        const ignore_regions = parseIgnoreRegions(options_obj, allocator, &response_writer, request_id) catch continue;
        defer if (ignore_regions.len > 0) allocator.free(ignore_regions);

        var base_img = odiff.io.loadImage(allocator, base_path) catch {
            var msg_buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&msg_buf, "Could not load base image: {s}", .{base_path});
            try response_writer.writeError(request_id, msg);
            continue;
        };
        defer base_img.deinit(allocator);

        var comp_img = odiff.io.loadImage(allocator, compare_path) catch {
            var msg_buf: [512]u8 = undefined;
            const msg = try std.fmt.bufPrint(&msg_buf, "Could not load compare image: {s}", .{compare_path});
            try response_writer.writeError(request_id, msg);
            continue;
        };
        defer comp_img.deinit(allocator);

        const result = odiff.diff.diff(&base_img, &comp_img, odiff.DiffOptions{
            .output_diff_mask = output_diff_mask,
            .diff_overlay_factor = diff_overlay_factor,
            .threshold = threshold,
            .diff_pixel = diff_pixel,
            .fail_on_layout_change = fail_on_layout,
            .antialiasing = antialiasing,
            .diff_lines = capture_diff_lines,
            .ignore_regions = ignore_regions,
            .capture_diff = true,
            .enable_asm = true,
        }, allocator) catch |err| {
            var msg_buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&msg_buf, "Diff failed: {s}", .{@errorName(err)});
            try response_writer.writeError(request_id, msg);
            continue;
        };

        switch (result) {
            .layout => {
                try response_writer.writeLayoutDiff(request_id);
            },
            .pixel => |pixel_result| {
                defer {
                    if (pixel_result.diff_output) |*output| {
                        var img = output.*;
                        img.deinit(allocator);
                    }
                    if (pixel_result.diff_lines) |lines| {
                        var mutable_lines = lines;
                        mutable_lines.deinit();
                    }
                }

                if (pixel_result.diff_count == 0) {
                    try response_writer.writeMatch(request_id);
                    continue;
                }

                if (pixel_result.diff_output) |output_img| {
                    odiff.io.saveImage(output_img, output_path) catch {
                        try response_writer.writeError(request_id, "Failed to save diff output");
                        continue;
                    };
                }

                if (capture_diff_lines and pixel_result.diff_lines != null) {
                    try response_writer.writePixelDiffWithLines(
                        request_id,
                        pixel_result.diff_count,
                        pixel_result.diff_percentage,
                        pixel_result.diff_lines.?,
                    );
                } else {
                    try response_writer.writePixelDiff(
                        request_id,
                        pixel_result.diff_count,
                        pixel_result.diff_percentage,
                    );
                }
            },
        }
    }
}
