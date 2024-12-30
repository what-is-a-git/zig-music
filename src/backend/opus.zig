const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;

const AudioStream = @import("audio_stream.zig");

const AudioFile = @import("audio_file.zig");

const FileReader = @import("file_reader.zig");
const read_file = FileReader.read_file;
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cInclude("opusfile.h");
});

pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
    const bytes = read_file(file, allocator) catch |err| return err;
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

pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
    var output: AudioStream = .{ .allocator = allocator };

    const bytes = read_file(file, allocator) catch |err| return err;
    output.file_bytes = bytes;

    output.format_handle = c.op_open_memory(bytes.ptr, bytes.len, null);
    output.channels = @intCast(c.op_channel_count(@ptrCast(output.format_handle), -1));
    output.sample_rate = 48_000;
    output.frame_count = @intCast(c.op_pcm_total(@ptrCast(output.format_handle), -1));

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

            var index: usize = 0;
            const cursor: usize = @intFromPtr(frames);
            while (index < count) {
                const offset = index * stream.channels;
                const frame: usize = @intCast(c.op_read(
                    @ptrCast(stream.format_handle),
                    @ptrFromInt(cursor + (offset * requested_format.get_size())),
                    // the name _buf_size is misleading, since this parameter is actually
                    // the COUNT of shorts that fit in the buffer :]
                    @intCast(output_count - offset),
                    null,
                ));

                index += frame;
                if (frame <= 0) {
                    break;
                }
            }

            output.count = index * stream.channels;
            output.frames = frames;
        },
        .Float32 => {
            const frames = std.c.malloc(size);

            var index: usize = 0;
            const cursor: usize = @intFromPtr(frames);
            while (index < count) {
                const offset = index * stream.channels;
                const frame: usize = @intCast(c.op_read_float(
                    @ptrCast(stream.format_handle),
                    @ptrFromInt(cursor + (offset * requested_format.get_size())),
                    // the name _buf_size is misleading, since this parameter is actually
                    // the COUNT of floats that fit in the buffer :]
                    @intCast(output_count - offset),
                    null,
                ));

                index += frame;
                if (frame <= 0) {
                    break;
                }
            }

            output.count = index * stream.channels;
            output.frames = frames;
        },
    }

    return output;
}

pub fn seek_stream(stream: AudioStream, frame: usize) void {
    if (stream.format_handle == null) {
        return;
    }

    _ = c.op_pcm_seek(@ptrCast(stream.format_handle), @intCast(frame));
}

pub fn close_stream(stream: AudioStream) void {
    if (stream.format_handle != null) {
        c.op_free(@ptrCast(stream.format_handle));
    }

    stream.deinit();
}
