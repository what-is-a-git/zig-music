const std = @import("std");

pub const AudioFile = struct {
    pub const BitDepth = enum {
        Signed16,
        Float32,
    };

    bit_depth: BitDepth,
    frame_count: usize = undefined,
    channels: u32 = undefined,
    sample_rate: u32 = undefined,
    frames: ?*anyopaque = undefined,

    pub fn free(self: *const AudioFile) void {
        if (self.frames != null) {
            std.c.free(self.frames);
        }
    }

    pub fn get_bit_size(self: *const AudioFile) usize {
        switch (self.bit_depth) {
            .Signed16 => return @sizeOf(i16),
            .Float32 => return @sizeOf(f32),
        }
    }

    pub fn get_size(self: *const AudioFile) usize {
        switch (self.bit_depth) {
            .Signed16 => return self.frame_count * self.channels * self.get_bit_size(),
            .Float32 => return self.frame_count * self.channels * self.get_bit_size(),
        }
    }
};

pub const ReadFileError = error{
    Unseekable,
    AccessDenied,
    FileTooBig,
    ZigError,
};

pub fn read_file(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError![]u8 {
    file.seekTo(0) catch |err| switch (err) {
        std.posix.SeekError.Unseekable => return ReadFileError.Unseekable,
        std.posix.SeekError.AccessDenied => return ReadFileError.AccessDenied,
        else => return ReadFileError.ZigError,
    };

    return file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| switch (err) {
        else => return ReadFileError.FileTooBig,
    };
}
