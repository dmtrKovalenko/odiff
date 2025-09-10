const std = @import("std");

const ImageResult = @import("c_bindings.zig").ImageResult;

const c = @cImport({
    @cInclude("spng.h");
});

/// Reads a PNG file into a slice of pixels in RGBA format.
/// caller owns the returned data
pub fn readPNG(allocator: std.mem.Allocator, file_path: []const u8) !ImageResult {
    const file = try MemoryMappeFile.open(file_path);
    defer file.close();

    const ctx = c.spng_ctx_new(0) orelse return error.OutOfMemory;
    defer c.spng_ctx_free(ctx);

    // Ignore and don't calculate chunk CRC's for better performance
    _ = c.spng_set_crc_action(ctx, c.SPNG_CRC_USE, c.SPNG_CRC_USE);

    const limit = 1024 * 1024 * 64;
    _ = c.spng_set_chunk_limits(ctx, limit, limit);

    if (c.spng_set_png_buffer(ctx, @ptrCast(file.data.ptr), @intCast(file.data.len)) != 0)
        return error.InvalidData;

    var ihdr: c.spng_ihdr = undefined;
    if (c.spng_get_ihdr(ctx, &ihdr) != 0) return error.InvalidData;

    var out_size: usize = 0;
    if (c.spng_decoded_image_size(ctx, c.SPNG_FMT_RGBA8, &out_size) != 0)
        return error.InvalidData;

    const result_data = try allocator.alignedAlloc(u8, .of(u32), out_size);
    errdefer allocator.free(result_data);

    if (c.spng_decode_image(ctx, @ptrCast(result_data.ptr), out_size, c.SPNG_FMT_RGBA8, c.SPNG_DECODE_TRNS) != 0)
        return error.InvalidData;

    return ImageResult{
        .width = ihdr.width,
        .height = ihdr.height,
        .data = @ptrCast(result_data),
        .is_c_allocated = false,
    };
}

/// Writes a PNG file to `file_path` using the SPNG library.
/// The `pixel_data` is expected to be in RGBA format.
pub fn writePNG(file_path: []const u8, width: u32, height: u32, pixel_data: []const u32) !void {
    var file = try std.fs.cwd().createFile(file_path, .{
        .truncate = true,
    });
    defer file.close();
    var buffer: [1024 * 1024]u8 = undefined;
    var file_writer = file.writer(&buffer);
    const writer_interface = &file_writer.interface;

    const ctx = c.spng_ctx_new(c.SPNG_CTX_ENCODER) orelse return error.OutOfMemory;
    defer c.spng_ctx_free(ctx);

    var ihdr = c.spng_ihdr{
        .width = width,
        .height = height,
        .bit_depth = 8,
        .color_type = c.SPNG_COLOR_TYPE_TRUECOLOR_ALPHA,
        .compression_method = 0,
        .filter_method = c.SPNG_FILTER_NONE,
        .interlace_method = c.SPNG_INTERLACE_NONE,
    };
    if (c.spng_set_ihdr(ctx, &ihdr) != 0) return error.InvalidData;

    if (c.spng_set_png_stream(
        ctx,
        struct {
            pub fn writeFn(_: ?*c.spng_ctx, user_data: ?*anyopaque, src: ?*anyopaque, len: usize) callconv(.c) c_int {
                const writer: *std.Io.Writer = @ptrCast(@alignCast(user_data.?));
                const src_slice = @as([*]const u8, @ptrCast(src.?))[0..len];
                writer.writeAll(src_slice) catch |err| {
                    std.log.err("writePNG: failed to write data: {}", .{err});
                    return c.SPNG_IO_ERROR;
                };
                return 0;
            }
        }.writeFn,
        @ptrCast(@alignCast(writer_interface)),
    ) != 0) return error.InvalidData;

    const res = c.spng_encode_image(ctx, @ptrCast(@alignCast(pixel_data.ptr)), pixel_data.len * @sizeOf(u32), c.SPNG_FMT_PNG, c.SPNG_ENCODE_FINALIZE);
    if (res != 0) {
        const err_msg = std.mem.span(c.spng_strerror(res));
        std.log.err("writePNG: failed to encode image {s}", .{err_msg});
        return error.InvalidData;
    }

    writer_interface.flush() catch |err| {
        std.log.err("writePNG: failed to flush file: {} mode {}", .{ file_writer.err orelse err, file_writer.mode });
        return error.WriteFailed;
    };
}

const MemoryMappeFile = struct {
    const Self = @This();

    const builtin = @import("builtin");
    const posix = std.posix;
    const win = std.os.windows;
    const is_windows = builtin.os.tag == .windows;

    file: std.fs.File,
    data: if (is_windows)
        []const u8
    else
        []align(std.heap.page_size_min) const u8,

    win_mapping: if (is_windows) win.HANDLE else void =
        if (is_windows) undefined else ({}),

    pub fn open(file_path: []const u8) !Self {
        const file = switch (builtin.os.tag) {
            .windows => blk: {
                const win_path = try win.sliceToPrefixedFileW(std.fs.cwd().fd, file_path);
                const handle =
                    try win.OpenFile(win_path.span(), .{
                        .dir = std.fs.cwd().fd,
                        .access_mask = win.GENERIC_READ,
                        .share_access = win.FILE_SHARE_READ,
                        .creation = win.FILE_OPEN,
                    });
                break :blk std.fs.File{ .handle = handle };
            },
            else => blk: {
                const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
                break :blk file;
            },
        };
        errdefer file.close();

        const file_size = try file.getEndPos();
        if (file_size == 0) return error.FileEmpty;

        const fd = file.handle;
        switch (builtin.os.tag) {
            .windows => {
                const mapping = CreateFileMappingA(fd, null, win.PAGE_READONLY, 0, 0, null) orelse return error.CreateFileMappingFailed;
                const ptr = MapViewOfFile(mapping, WIN_FILE_MAP_READ, 0, 0, @intCast(file_size)) orelse return error.MapViewOfFileFailed;
                return .{
                    .file = file,
                    // explicitly casts to a const ptr cuz it is read-only
                    .data = @as([*]const u8, @ptrCast(ptr))[0..file_size],
                    .win_mapping = mapping,
                };
            },
            // TODO: everything else is posix ig but is this right tho?
            else => {
                const ptr = try posix.mmap(null, @intCast(file_size), posix.PROT.READ, posix.MAP{ .TYPE = .PRIVATE }, fd, 0);
                return .{
                    .data = ptr,
                    .file = file,
                };
            },
        }
    }

    pub fn close(self: Self) void {
        switch (builtin.os.tag) {
            .windows => {
                // cast away const cuz windows api uses c and nothing is const there ffs
                _ = UnmapViewOfFile(@ptrCast(@constCast(self.data.ptr)));
                win.CloseHandle(self.win_mapping);
            },
            else => {
                const ptr = self.data;
                posix.munmap(ptr);
            },
        }
        self.file.close();
    }

    // TODO: replace with zig std when they are available there
    extern "kernel32" fn CreateFileMappingA(
        hFile: win.HANDLE,
        lpFileMappingAttributes: ?*win.SECURITY_ATTRIBUTES,
        flProtect: win.DWORD,
        dwMaximumSizeHigh: win.DWORD,
        dwMaximumSizeLow: win.DWORD,
        lpName: ?win.LPCWSTR,
    ) callconv(.winapi) ?win.HANDLE;

    const WIN_FILE_MAP_READ = 0x0004;
    extern "kernel32" fn MapViewOfFile(
        hFileMappingObject: win.HANDLE,
        dwDesiredAccess: win.DWORD,
        dwFileOffsetHigh: win.DWORD,
        dwFileOffsetLow: win.DWORD,
        dwNumberOfBytesToMap: win.DWORD,
    ) callconv(.winapi) ?win.LPVOID;
    extern "kernel32" fn UnmapViewOfFile(lpBaseAddress: win.LPVOID) callconv(.winapi) win.BOOL;
};
