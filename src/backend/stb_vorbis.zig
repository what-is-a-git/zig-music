const std = @import("std");

const audio_file = @import("audio_file.zig");
const read_file = audio_file.read_file;
const AudioFile = audio_file.AudioFile;
const ReadFileError = audio_file.ReadFileError;

const c = @cImport({
    @cDefine("STB_VORBIS_NO_STDIO", "1");
    @cInclude("stb/stb_vorbis.h");
});

pub fn decode_file(file: std.fs.File, requested_depth: AudioFile.BitDepth, allocator: std.mem.Allocator) ReadFileError!AudioFile {
    const bytes = read_file(file, allocator) catch |err| switch (err) {
        else => return err,
    };

    var output: AudioFile = .{
        .bit_depth = requested_depth,
    };

    const vorbis = c.stb_vorbis_open_memory(bytes.ptr, @intCast(bytes.len), null, null);
    const info = c.stb_vorbis_get_info(vorbis);
    output.channels = @intCast(info.channels);
    output.sample_rate = @intCast(info.sample_rate);
    output.frame_count = @intCast(c.stb_vorbis_stream_length_in_samples(vorbis));

    switch (requested_depth) {
        .Signed16 => {
            output.frames = std.c.malloc(output.get_size());
            _ = c.stb_vorbis_get_samples_short_interleaved(
                vorbis,
                @intCast(output.channels),
                @alignCast(@ptrCast(output.frames)),
                @intCast(output.frame_count * output.channels),
            );
        },
        .Float32 => {
            output.frames = std.c.malloc(output.get_size());
            _ = c.stb_vorbis_get_samples_float_interleaved(
                vorbis,
                @intCast(output.channels),
                @alignCast(@ptrCast(output.frames)),
                @intCast(output.frame_count * output.channels),
            );
        },
    }

    c.stb_vorbis_close(vorbis);
    allocator.free(bytes);
    return output;
}