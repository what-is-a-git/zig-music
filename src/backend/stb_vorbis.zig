const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");
const AudioFile = @import("audio_file.zig");

const FileReader = @import("file_reader.zig");
const read_file = FileReader.read_file;
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cDefine("STB_VORBIS_NO_STDIO", "1");
    @cInclude("stb/stb_vorbis.h");
});

pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
    const bytes = read_file(file, allocator) catch |err| return err;
    var output: AudioFile = .{
        .bit_format = requested_format,
    };

    const vorbis = c.stb_vorbis_open_memory(bytes.ptr, @intCast(bytes.len), null, null);
    const info = c.stb_vorbis_get_info(vorbis);
    output.channels = @intCast(info.channels);
    output.sample_rate = @intCast(info.sample_rate);
    output.frame_count = @intCast(c.stb_vorbis_stream_length_in_samples(vorbis));

    switch (requested_format) {
        .SignedInt16 => {
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

pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
    var output: AudioStream = .{ .allocator = allocator };

    const bytes = read_file(file, allocator) catch |err| return err;
    output.file_bytes = bytes;

    output.format_handle = c.stb_vorbis_open_memory(bytes.ptr, @intCast(bytes.len), null, null);

    const info = c.stb_vorbis_get_info(@ptrCast(output.format_handle));
    output.channels = @intCast(info.channels);
    output.sample_rate = info.sample_rate;
    output.frame_count = @intCast(c.stb_vorbis_stream_length_in_samples(@ptrCast(output.format_handle)));

    return output;
}

pub fn decode_stream(stream: AudioStream, requested_format: BitFormat, count: usize) AudioStream.DecodeError!AudioStream.DecodedPCM {
    var output: AudioStream.DecodedPCM = .{
        .format = requested_format,
        .allocator = stream.allocator,
    };
    if (stream.format_handle == null) {
        return AudioStream.DecodeError.InvalidStream;
    }

    const output_count = count * stream.channels;
    const size = output_count * requested_format.get_size();
    switch (requested_format) {
        .SignedInt16 => {
            const frames = std.c.malloc(size);
            const frame: u32 = @intCast(c.stb_vorbis_get_samples_short_interleaved(
                @ptrCast(stream.format_handle),
                @intCast(stream.channels),
                @alignCast(@ptrCast(frames)),
                @intCast(output_count),
            ));
            output.count = frame * stream.channels;
            output.frames = frames;
        },
        .Float32 => {
            const frames = std.c.malloc(size);
            const frame: u32 = @intCast(c.stb_vorbis_get_samples_float_interleaved(
                @ptrCast(stream.format_handle),
                @intCast(stream.channels),
                @alignCast(@ptrCast(frames)),
                @intCast(output_count),
            ));
            output.count = frame * stream.channels;
            output.frames = frames;
        },
    }

    return output;
}

pub fn seek_stream(stream: AudioStream, frame: usize) void {
    if (stream.format_handle == null) {
        return;
    }

    _ = c.stb_vorbis_seek(@ptrCast(stream.format_handle), @intCast(frame));
}

pub fn close_stream(stream: AudioStream) void {
    if (stream.format_handle != null) {
        c.stb_vorbis_close(@ptrCast(stream.format_handle));
    }

    stream.deinit();
}
