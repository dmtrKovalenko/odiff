const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const builtin = @import("builtin");

fn getOdiffPath(allocator: std.mem.Allocator) ![]const u8 {
    const odiff_name = if (builtin.os.tag == .windows) "odiff.exe" else "odiff";
    const installed_path = try std.fs.path.join(allocator, &[_][]const u8{ "zig-out", "bin", odiff_name });
    const cwd = std.fs.cwd();
    cwd.access(installed_path, .{}) catch {
        allocator.free(installed_path);
        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_dir_path);
        return std.fs.path.join(allocator, &[_][]const u8{ exe_dir_path, odiff_name });
    };
    return installed_path;
}

fn readLineFromPipe(file: std.fs.File, buf: []u8) ![]const u8 {
    var file_reader = file.reader(buf);
    const reader = &file_reader.interface;
    const line = try reader.takeDelimiter('\n') orelse return error.EndOfStream;
    return line;
}

test "server: end-to-end identical images match" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const odiff_path = try getOdiffPath(allocator);
    defer allocator.free(odiff_path);

    const cwd = std.fs.cwd();
    cwd.access(odiff_path, .{}) catch |err| {
        std.debug.print("odiff binary not found at {s}: {}\n", .{ odiff_path, err });
        return error.SkipZigTest;
    };

    var child = std.process.Child.init(&[_][]const u8{ odiff_path, "--server" }, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    defer _ = child.kill() catch {};

    const stdin = child.stdin.?;
    const stdout = child.stdout.?;
    const stderr = child.stderr.?;

    var ready_buf: [256]u8 = undefined;
    const ready_msg = readLineFromPipe(stdout, &ready_buf) catch |err| {
        var stderr_buf: [1024]u8 = undefined;
        const stderr_len = stderr.read(&stderr_buf) catch 0;
        std.debug.print("Failed to read ready message: {}\nstderr: {s}\n", .{ err, stderr_buf[0..stderr_len] });
        return err;
    };
    try expect(std.mem.indexOf(u8, ready_msg, "\"ready\":true") != null);

    const request =
        \\{"requestId":1,"base":"test/png/orange.png","compare":"test/png/orange.png","output":"/tmp/test_diff.png"}
        \\
    ;
    try stdin.writeAll(request);

    var response_buf: [1024]u8 = undefined;
    const response = try readLineFromPipe(stdout, &response_buf);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try expect(obj.get("requestId").?.integer == 1);
    try expect(obj.get("match").?.bool == true);
}

test "server: end-to-end different images show pixel diff" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const odiff_path = try getOdiffPath(allocator);
    defer allocator.free(odiff_path);

    const cwd = std.fs.cwd();
    cwd.access(odiff_path, .{}) catch |err| {
        std.debug.print("odiff binary not found at {s}: {}\n", .{ odiff_path, err });
        return error.SkipZigTest;
    };

    var child = std.process.Child.init(&[_][]const u8{ odiff_path, "--server" }, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    defer _ = child.kill() catch {};

    const stdin = child.stdin.?;
    const stdout = child.stdout.?;

    var ready_buf: [256]u8 = undefined;
    _ = try readLineFromPipe(stdout, &ready_buf);

    const request =
        \\{"requestId":2,"base":"test/png/orange.png","compare":"test/png/orange_changed.png","output":"/tmp/test_diff2.png","options":{"threshold":0.1}}
        \\
    ;
    try stdin.writeAll(request);

    var response_buf: [1024]u8 = undefined;
    const response = try readLineFromPipe(stdout, &response_buf);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try expect(obj.get("requestId").?.integer == 2);
    try expect(obj.get("match").?.bool == false);
    try expect(obj.get("reason") != null);
    try expect(std.mem.eql(u8, "pixel-diff", obj.get("reason").?.string));
    try expect(obj.get("diffCount").?.integer > 0);
    try expect(obj.get("diffPercentage").?.float > 0.0);
}

test "server: ignore regions support" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const odiff_path = try getOdiffPath(allocator);
    defer allocator.free(odiff_path);

    const cwd = std.fs.cwd();
    cwd.access(odiff_path, .{}) catch |err| {
        std.debug.print("odiff binary not found at {s}: {}\n", .{ odiff_path, err });
        return error.SkipZigTest;
    };

    var child = std.process.Child.init(&[_][]const u8{ odiff_path, "--server" }, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    defer _ = child.kill() catch {};

    const stdin = child.stdin.?;
    const stdout = child.stdout.?;

    var ready_buf: [256]u8 = undefined;
    _ = try readLineFromPipe(stdout, &ready_buf);

    // Use the same ignore regions as in test_core.zig that cover all differences
    const request =
        \\{"requestId":3,"base":"test/png/orange.png","compare":"test/png/orange_changed.png","output":"/tmp/test_diff3.png","options":{"ignoreRegions":[{"x1":150,"y1":30,"x2":310,"y2":105},{"x1":20,"y1":175,"x2":105,"y2":200}]}}
        \\
    ;
    try stdin.writeAll(request);

    var response_buf: [1024]u8 = undefined;
    const response = try readLineFromPipe(stdout, &response_buf);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try expect(obj.get("requestId").?.integer == 3);
    try expect(obj.get("match").?.bool == true); // All diffs are in ignored regions
}

test "server: empty ignore regions array works correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const odiff_path = try getOdiffPath(allocator);
    defer allocator.free(odiff_path);

    const cwd = std.fs.cwd();
    cwd.access(odiff_path, .{}) catch |err| {
        std.debug.print("odiff binary not found at {s}: {}\n", .{ odiff_path, err });
        return error.SkipZigTest;
    };

    var child = std.process.Child.init(&[_][]const u8{ odiff_path, "--server" }, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    defer _ = child.kill() catch {};

    const stdin = child.stdin.?;
    const stdout = child.stdout.?;

    var ready_buf: [256]u8 = undefined;
    _ = try readLineFromPipe(stdout, &ready_buf);

    const request =
        \\{"requestId":4,"base":"test/png/orange.png","compare":"test/png/orange_changed.png","output":"/tmp/test_diff4.png","options":{"ignoreRegions":[]}}
        \\
    ;
    try stdin.writeAll(request);

    var response_buf: [1024]u8 = undefined;
    const response = try readLineFromPipe(stdout, &response_buf);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try expect(obj.get("requestId").?.integer == 4);
    try expect(obj.get("match").?.bool == false); // Should behave like normal diff
    try expect(obj.get("diffCount").?.integer > 0);
}

test "server: invalid ignore regions return error" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const odiff_path = try getOdiffPath(allocator);
    defer allocator.free(odiff_path);

    const cwd = std.fs.cwd();
    cwd.access(odiff_path, .{}) catch |err| {
        std.debug.print("odiff binary not found at {s}: {}\n", .{ odiff_path, err });
        return error.SkipZigTest;
    };

    var child = std.process.Child.init(&[_][]const u8{ odiff_path, "--server" }, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
    defer _ = child.kill() catch {};

    const stdin = child.stdin.?;
    const stdout = child.stdout.?;

    var ready_buf: [256]u8 = undefined;
    _ = try readLineFromPipe(stdout, &ready_buf);

    // Test missing required field (y2)
    const request =
        \\{"requestId":5,"base":"test/png/orange.png","compare":"test/png/orange_changed.png","output":"/tmp/test_diff5.png","options":{"ignoreRegions":[{"x1":10,"y1":20,"x2":30}]}}
        \\
    ;
    try stdin.writeAll(request);

    var response_buf: [1024]u8 = undefined;
    const response = try readLineFromPipe(stdout, &response_buf);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, response, .{});
    defer parsed.deinit();

    const obj = parsed.value.object;
    try expect(obj.get("requestId").?.integer == 5);
    try expect(obj.get("error") != null);
    const error_msg = obj.get("error").?.string;
    try expect(std.mem.indexOf(u8, error_msg, "missing required field") != null);
}
