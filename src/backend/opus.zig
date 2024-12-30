const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;

const AudioFile = @import("audio_file.zig");
const read_file = AudioFile.read_file;
const ReadFileError = AudioFile.ReadFileError;

const c = @cImport({
    @cInclude("opusfile.h");
});

pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
    const bytes = read_file(file, allocator) catch |err| switch (err) {
        else => return err,
    };

    var output: AudioFile = .{
        .bit_format = requested_format,
    };

    const opus = c.op_open_memory(bytes.ptr, bytes.len, null);
    output.channels = @intCast(c.op_channel_count(opus, -1));
    output.sample_rate = 48_000;
    output.frame_count = @intCast(c.op_pcm_total(opus, -1));

    switch (requested_format) {
        .SignedInt16 => {
            const size = output.get_size();
            output.frames = std.c.malloc(size);

            var index: usize = 0;
            const cursor: usize = @intFromPtr(output.frames);
            while (index < output.frame_count) {
                const offset = index * output.channels * output.get_bit_size();
                index += @intCast(c.op_read(opus, @ptrFromInt(cursor + offset), @intCast(size - offset), null));
            }
        },
        .Float32 => {
            const size = output.get_size();
            output.frames = std.c.malloc(size);

            var index: usize = 0;
            const cursor: usize = @intFromPtr(output.frames);
            while (index < output.frame_count) {
                const offset = index * output.channels * output.get_bit_size();
                index += @intCast(c.op_read_float(opus, @ptrFromInt(cursor + offset), @intCast(size - offset), null));
            }
        },
    }

    c.op_free(opus);
    allocator.free(bytes);
    return output;
}
