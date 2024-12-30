const std = @import("std");

const audio_file = @import("audio_file.zig");
const read_file = audio_file.read_file;
const AudioFile = audio_file.AudioFile;
const ReadFileError = audio_file.ReadFileError;

const c = @cImport({
    @cInclude("opusfile.h");
});

pub fn decode_file(file: std.fs.File, requested_depth: AudioFile.BitDepth, allocator: std.mem.Allocator) ReadFileError!AudioFile {
    const bytes = read_file(file, allocator) catch |err| switch (err) {
        else => return err,
    };

    var output: AudioFile = .{
        .bit_depth = requested_depth,
    };

    const opus = c.op_open_memory(bytes.ptr, bytes.len, null);
    output.channels = @intCast(c.op_channel_count(opus, -1));
    output.sample_rate = 48_000;
    output.frame_count = @intCast(c.op_pcm_total(opus, -1));

    switch (requested_depth) {
        .Signed16 => {
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
