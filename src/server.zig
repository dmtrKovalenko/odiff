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

    // Optimization #1: Reuse single error buffer instead of allocating in each error path
    var error_buf: [256]u8 = undefined;

    // Parse each region
    for (regions_array.items, 0..) |region_value, i| {
        if (region_value != .object) {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}] must be an object", .{i});
            try response_writer.writeError(request_id, msg);
            return error.InvalidIgnoreRegions;
        }

        const region_obj = region_value.object;

        // Optimization #2: Batch field lookups to reduce function call overhead
        // Extract all required fields
        const x1_val = region_obj.get("x1") orelse {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}]: missing required field 'x1'", .{i});
            try response_writer.writeError(request_id, msg);
            return error.MissingField;
        };
        const y1_val = region_obj.get("y1") orelse {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}]: missing required field 'y1'", .{i});
            try response_writer.writeError(request_id, msg);
            return error.MissingField;
        };
        const x2_val = region_obj.get("x2") orelse {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}]: missing required field 'x2'", .{i});
            try response_writer.writeError(request_id, msg);
            return error.MissingField;
        };
        const y2_val = region_obj.get("y2") orelse {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}]: missing required field 'y2'", .{i});
            try response_writer.writeError(request_id, msg);
            return error.MissingField;
        };

        // Validate all fields are integers
        if (x1_val != .integer) {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}].x1 must be a number", .{i});
            try response_writer.writeError(request_id, msg);
            return error.InvalidType;
        }
        if (y1_val != .integer) {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}].y1 must be a number", .{i});
            try response_writer.writeError(request_id, msg);
            return error.InvalidType;
        }
        if (x2_val != .integer) {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}].x2 must be a number", .{i});
            try response_writer.writeError(request_id, msg);
            return error.InvalidType;
        }
        if (y2_val != .integer) {
            const msg = try std.fmt.bufPrint(&error_buf, "ignoreRegions[{d}].y2 must be a number", .{i});
            try response_writer.writeError(request_id, msg);
            return error.InvalidType;
        }

        // Extract coordinate values
        ignore_regions[i] = .{
            .x1 = @intCast(x1_val.integer),
            .y1 = @intCast(y1_val.integer),
            .x2 = @intCast(x2_val.integer),
            .y2 = @intCast(y2_val.integer),
        };
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

        // Load images with color decoding strategy based on threshold
        const strategy = odiff.io.ColorDecodingStrategy.fromThreshold(threshold);
        const load_result = odiff.io.loadTwoImages(allocator, base_path, compare_path, strategy);
        const images = switch (load_result) {
            .ok => |imgs| imgs,
            .err => |load_err| {
                var msg_buf: [512]u8 = undefined;
                const msg = switch (load_err) {
                    .base_failed => try std.fmt.bufPrint(&msg_buf, "Could not load base image: {s}", .{base_path}),
                    .compare_failed => try std.fmt.bufPrint(&msg_buf, "Could not load comparison image: {s}", .{compare_path}),
                    .thread_spawn_failed => |err| try std.fmt.bufPrint(&msg_buf, "Failed to spawn thread: {s}", .{@errorName(err)}),
                };
                try response_writer.writeError(request_id, msg);
                continue;
            },
        };
        var base_img = images.base;
        defer base_img.deinit(allocator);
        var comp_img = images.compare;
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
