const std = @import("std");
const AudioStream = @This();

pub const BitFormat = @import("../format.zig").BitFormat;

frame_count: usize = undefined,
channels: u32 = undefined,
sample_rate: u32 = undefined,
format_handle: ?*anyopaque = null,
file: ?std.fs.File = null,

pub const DecodeError = error{
    InvalidStream,
    AllocationError,
};

pub const DecodedPCM = struct {
    count: usize = undefined,
    format: BitFormat,
    frames: ?*anyopaque = null,

    pub fn deinit(self: *const DecodedPCM) void {
        if (self.frames != null) {
            std.c.free(self.frames);
        }
    }

    pub fn get_size(self: *const DecodedPCM) usize {
        return self.count * self.format.get_size();
    }
};
