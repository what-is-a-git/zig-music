const std = @import("std");
const BitFormat = @import("../core/audio/format.zig").BitFormat;

const AudioStream = @This();

allocator: std.mem.Allocator,
frame_count: usize = undefined,
channels: u32 = undefined,
sample_rate: u32 = undefined,
format_handle: ?*anyopaque = null,
file_bytes: ?[]u8 = null,

pub fn deinit(self: *const AudioStream) void {
    if (self.file_bytes != null) {
        self.allocator.free(self.file_bytes.?);
    }
}

pub const DecodeError = error{
    InvalidStream,
    AllocationError,
};

pub const DecodedPCM = struct {
    count: usize = undefined,
    format: BitFormat,
    frames: ?*anyopaque = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const DecodedPCM) void {
        if (self.frames != null) {
            std.c.free(self.frames);
        }
    }

    pub fn get_size(self: *const DecodedPCM) usize {
        return self.count * self.format.get_size();
    }
};
