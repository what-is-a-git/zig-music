const std = @import("std");

const AudioStream = @import("audio_stream.zig");
const BitFormat = AudioStream.BitFormat;

const FileReader = @import("file_reader.zig");
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cInclude("opusfile.h");
});

fn read_func(data: ?*anyopaque, buffer: [*c]u8, size: c_int) callconv(.C) c_int {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        return @intCast(file.read(buffer[0..@intCast(size)]) catch return -1);
    }

    return -1;
}

fn seek_func(data: ?*anyopaque, offset: i64, whence: c_int) callconv(.C) c_int {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        switch (whence) {
            std.c.SEEK.CUR => file.seekBy(offset) catch return -1,
            std.c.SEEK.END => file.seekFromEnd(offset) catch return -1,
            std.c.SEEK.SET => file.seekTo(@intCast(offset)) catch return -1,
            else => unreachable,
        }
    }

    return 0;
}

fn tell_func(data: ?*anyopaque) callconv(.C) i64 {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        return @intCast(file.getPos() catch return -1);
    }

    return -1;
}

fn close_func(data: ?*anyopaque) callconv(.C) c_int {
    _ = data;
    return 0;
}

const zig_file_callbacks: c.OpusFileCallbacks = .{
    .read = read_func,
    .seek = seek_func,
    .tell = tell_func,
    .close = close_func,
};

pub fn open_stream(file: std.fs.File) ReadFileError!AudioStream {
    var output: AudioStream = .{};
    output.file = file;

    output.format_handle = c.op_open_callbacks(@ptrCast(@constCast(&output.file)), &zig_file_callbacks, null, 0, null);
    output.channels = @intCast(c.op_channel_count(@ptrCast(output.format_handle), -1));
    output.sample_rate = 48_000;
    output.frame_count = @intCast(c.op_pcm_total(@ptrCast(output.format_handle), -1));

    return output;
}

pub fn decode_stream(stream: AudioStream, requested_format: BitFormat, count: usize) AudioStream.DecodeError!AudioStream.DecodedPCM {
    var output: AudioStream.DecodedPCM = .{
        .format = requested_format,
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
