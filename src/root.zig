const std = @import("std");

pub const cli = @import("cli.zig");
pub const diff = @import("diff.zig");
pub const io = @import("io.zig");
pub const color_delta = @import("color_delta.zig");
pub const antialiasing = @import("antialiasing.zig");

pub const DiffOptions = diff.DiffOptions;
pub const DiffLines = diff.DiffLines;
pub const IgnoreRegion = diff.IgnoreRegion;
pub const DiffVariant = diff.DiffVariant;
