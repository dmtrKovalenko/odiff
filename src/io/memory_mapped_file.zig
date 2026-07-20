const std = @import("std");

const Self = @This();

const builtin = @import("builtin");
const posix = std.posix;
const win = std.os.windows;
const is_windows = builtin.os.tag == .windows;

file: std.Io.File,
data: if (is_windows)
    []const u8
else
    []align(std.heap.page_size_min) const u8,

win_mapping: if (is_windows) win.HANDLE else void =
    if (is_windows) undefined else ({}),

pub fn open(file_path: []const u8) !Self {
    const io = std.Io.Threaded.global_single_threaded.io();
    const file = try std.Io.Dir.cwd().openFile(io, file_path, .{ .mode = .read_only });
    errdefer file.close(io);

    const file_size = try file.length(io);
    if (file_size == 0) return error.FileEmpty;

    const fd = file.handle;
    switch (builtin.os.tag) {
        .windows => {
            const mapping = win_aux.CreateFileMappingA(fd, null, win_aux.PAGE_READONLY, 0, 0, null) orelse return error.CreateFileMappingFailed;
            const ptr = win_aux.MapViewOfFile(mapping, win_aux.FILE_MAP_READ, 0, 0, 0) orelse return error.MapViewOfFileFailed;
            return .{
                .file = file,
                // explicitly casts to a const ptr cuz it is read-only
                .data = @as([*]const u8, @ptrCast(ptr))[0..file_size],
                .win_mapping = mapping,
            };
        },
        else => {
            const ptr = try posix.mmap(null, @intCast(file_size), .{ .READ = true }, posix.MAP{ .TYPE = .PRIVATE }, fd, 0);
            return .{
                .data = ptr,
                .file = file,
            };
        },
    }
}

pub fn close(self: Self) void {
    const io = std.Io.Threaded.global_single_threaded.io();
    switch (builtin.os.tag) {
        .windows => {
            // cast away const cuz windows api uses c and nothing is const there ffs
            _ = win_aux.UnmapViewOfFile(@ptrCast(@constCast(self.data.ptr)));
            win.CloseHandle(self.win_mapping);
        },
        else => {
            const ptr = self.data;
            posix.munmap(ptr);
        },
    }
    self.file.close(io);
}

// TODO: replace with zig std when they are available there
const win_aux = if (builtin.os.tag == .windows) struct {
    const win_h = @cImport({
        @cDefine("WIN32_LEAN_AND_MEAN", "1");
        @cInclude("windows.h");
    });
    pub const CreateFileMappingA = win_h.CreateFileMappingA;
    pub const MapViewOfFile = win_h.MapViewOfFile;
    pub const UnmapViewOfFile = win_h.UnmapViewOfFile;
    pub const FILE_MAP_READ = win_h.FILE_MAP_READ;
    pub const PAGE_READONLY = win_h.PAGE_READONLY;
} else void;
