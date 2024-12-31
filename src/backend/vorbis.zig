const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");
const AudioFile = @import("audio_file.zig");

const FileReader = @import("file_reader.zig");
const read_file = FileReader.read_file;
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cInclude("vorbis/codec.h");
    @cInclude("vorbis/vorbisfile.h");
});

fn read_func(buffer: ?*anyopaque, size: c_ulonglong, count: c_ulonglong, data: ?*anyopaque) callconv(.C) c_ulonglong {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        const ptr: [*]u8 = @ptrCast(buffer);
        return file.read(ptr[0..(size * count)]) catch return 0;
    }

    return 0;
}

fn seek_func(data: ?*anyopaque, offset: c_longlong, whence: c_int) callconv(.C) c_int {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        switch (whence) {
            std.c.SEEK.CUR => file.seekBy(offset) catch return 0,
            std.c.SEEK.END => file.seekFromEnd(offset) catch return 0,
            std.c.SEEK.SET => file.seekTo(@intCast(offset)) catch return 0,
            else => unreachable,
        }
    }

    return 0;
}

fn tell_func(data: ?*anyopaque) callconv(.C) c_long {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        const current = file.getPos() catch return -1;
        const end = file.getEndPos() catch return -1;

        if (current < end) {
            return @intCast(current + 1);
        } else {
            return @intCast(end);
        }
    }

    return -1;
}

fn close_func(data: ?*anyopaque) callconv(.C) c_int {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        file.close();
    }

    return 0;
}

const zig_file_callbacks: c.ov_callbacks = .{
    .read_func = read_func,
    .seek_func = seek_func,
    .tell_func = tell_func,
    .close_func = close_func,
};

pub fn decode_file(file: std.fs.File, requested_format: BitFormat) ReadFileError!AudioFile {
    var output: AudioFile = .{
        .bit_format = requested_format,
    };

    var vorbis_file: c.OggVorbis_File = undefined;
    if (c.ov_open_callbacks(@ptrCast(@constCast(&file)), &vorbis_file, null, 0, zig_file_callbacks) < 0) {
        return ReadFileError.DecodingError;
    }

    const vorbis_info = c.ov_info(&vorbis_file, -1);
    output.channels = @intCast(vorbis_info.*.channels);
    output.sample_rate = @intCast(vorbis_info.*.rate);
    output.frame_count = @intCast(c.ov_pcm_total(&vorbis_file, -1));

    switch (requested_format) {
        .SignedInt16 => {
            const size = output.get_size();
            output.frames = std.c.malloc(size);

            var index: usize = 0;
            var bitstream: c_int = 0;
            const cursor: usize = @intFromPtr(output.frames);
            while (index < size) {
                index += @intCast(c.ov_read(
                    &vorbis_file,
                    @ptrFromInt(cursor + index),
                    @intCast(size - index),
                    0,
                    2,
                    1,
                    &bitstream,
                ));
            }
        },
        .Float32 => {
            const size = output.get_size();
            output.frames = std.c.malloc(size);
            const frames: [*]f32 = @alignCast(@ptrCast(output.frames.?));

            var index: usize = 0;
            var frame_index: usize = 0;
            var bitstream: c_int = 0;
            while (index < output.frame_count) {
                var pcm_channels: [*][*]f32 = undefined;
                const read: usize = @intCast(c.ov_read_float(
                    &vorbis_file,
                    @ptrCast(&pcm_channels),
                    @intCast(output.frame_count - index),
                    &bitstream,
                ));

                for (0..read) |i| {
                    for (0..output.channels) |channel| {
                        frames[frame_index] = pcm_channels[channel][i];
                        frame_index += 1;
                    }
                }

                index += read;
            }
        },
    }

    _ = c.ov_clear(&vorbis_file);
    return output;
}

const zig_stream_callbacks: c.ov_callbacks = .{
    .read_func = read_func,
    .seek_func = seek_func,
    .tell_func = tell_func,
    .close_func = null,
};

pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
    var output: AudioStream = .{ .allocator = allocator };
    output.file = file;

    const vorbis_file: *c.OggVorbis_File = @alignCast(@ptrCast(std.c.malloc(@sizeOf(c.OggVorbis_File))));
    if (c.ov_open_callbacks(@ptrCast(@constCast(&output.file)), vorbis_file, null, 0, zig_stream_callbacks) < 0) {
        return ReadFileError.DecodingError;
    }

    const vorbis_info = c.ov_info(vorbis_file, -1);
    output.channels = @intCast(vorbis_info.*.channels);
    output.sample_rate = @intCast(vorbis_info.*.rate);
    output.frame_count = @intCast(c.ov_pcm_total(vorbis_file, -1));
    output.format_handle = @ptrCast(vorbis_file);

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

    const vorbis_file: *c.OggVorbis_File = @alignCast(@ptrCast(stream.format_handle));
    const frame_count = count * stream.channels;
    const size = frame_count * requested_format.get_size();
    switch (requested_format) {
        .SignedInt16 => {
            output.frames = std.c.malloc(size);

            var index: usize = 0;
            var bitstream: c_int = 0;
            const cursor: usize = @intFromPtr(output.frames);
            while (index < size) {
                const read: usize = @intCast(c.ov_read(
                    vorbis_file,
                    @ptrFromInt(cursor + index),
                    @intCast(size - index),
                    0,
                    2,
                    1,
                    &bitstream,
                ));

                if (read == 0) {
                    break;
                }

                index += read;
            }

            output.count = @divFloor(index, requested_format.get_size());
        },
        .Float32 => {
            output.frames = std.c.malloc(size);
            const frames: [*]f32 = @alignCast(@ptrCast(output.frames.?));

            var index: usize = 0;
            var frame_index: usize = 0;
            var bitstream: c_int = 0;
            while (index < count) {
                var pcm_channels: [*][*]f32 = undefined;
                const read: usize = @intCast(c.ov_read_float(
                    vorbis_file,
                    @ptrCast(&pcm_channels),
                    @intCast(count - index),
                    &bitstream,
                ));

                if (read == 0) {
                    break;
                }

                for (0..read) |i| {
                    for (0..stream.channels) |channel| {
                        frames[frame_index] = pcm_channels[channel][i];
                        frame_index += 1;
                    }
                }

                index += read;
            }

            output.count = index * stream.channels;
        },
    }

    return output;
}

pub fn seek_stream(stream: AudioStream, frame: usize) void {
    if (stream.format_handle == null) {
        return;
    }

    _ = c.ov_pcm_seek(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
}

pub fn close_stream(stream: AudioStream) void {
    if (stream.format_handle != null) {
        _ = c.ov_clear(@alignCast(@ptrCast(stream.format_handle)));
        std.c.free(stream.format_handle);
    }

    stream.deinit();
}
