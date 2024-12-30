const std = @import("std");
const BitFormat = @import("../core/audio/format.zig").BitFormat;

const AudioFile = @This();

bit_format: BitFormat,
frame_count: usize = undefined,
channels: u32 = undefined,
sample_rate: u32 = undefined,
frames: ?*anyopaque = undefined,

pub fn deinit(self: *const AudioFile) void {
    if (self.frames != null) {
        std.c.free(self.frames);
    }
}

pub fn get_size(self: *const AudioFile) usize {
    switch (self.bit_format) {
        .SignedInt16 => return self.frame_count * self.channels * self.bit_format.get_size(),
        .Float32 => return self.frame_count * self.channels * self.bit_format.get_size(),
    }
}
