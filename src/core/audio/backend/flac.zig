const std = @import("std");

const BitFormat = @import("../format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");

const FileReader = @import("file_reader.zig");
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cDefine("DR_FLAC_NO_STDIO", "1");
    @cInclude("dr_libs/dr_flac.h");
});

fn read_func(data: ?*anyopaque, buffer: ?*anyopaque, size: c_ulonglong) callconv(.C) c_ulonglong {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        const ptr: [*]u8 = @ptrCast(buffer);
        return file.read(ptr[0..size]) catch return 0;
    }

    return 0;
}

fn seek_func(data: ?*anyopaque, offset: c_int, whence: c_uint) callconv(.C) c_uint {
    if (data != null) {
        const file: *std.fs.File = @alignCast(@ptrCast(data));
        switch (whence) {
            c.drflac_seek_origin_current => file.seekBy(offset) catch return 0,
            c.drflac_seek_origin_start => file.seekTo(@intCast(offset)) catch return 0,
            else => unreachable,
        }

        return 1;
    }

    return 0;
}

pub fn open_stream(file: *std.fs.File) ReadFileError!AudioStream {
    var output: AudioStream = .{};
    output.file = file;

    const drflac = c.drflac_open(read_func, seek_func, @alignCast(@ptrCast(file)), null);
    output.format_handle = @ptrCast(drflac);
    output.channels = @intCast(drflac.*.channels);
    output.sample_rate = @intCast(drflac.*.sampleRate);
    output.frame_count = @intCast(drflac.*.totalPCMFrameCount);

    return output;
}

pub fn decode_stream(stream: AudioStream, requested_format: BitFormat, count: usize) AudioStream.DecodeError!AudioStream.DecodedPCM {
    var output: AudioStream.DecodedPCM = .{ .format = requested_format };
    if (stream.format_handle == null) {
        return AudioStream.DecodeError.InvalidStream;
    }

    const output_count = count * stream.channels;
    const size = output_count * requested_format.get_size();
    switch (requested_format) {
        .SignedInt16 => {
            const frames = std.c.malloc(size);
            output.count = c.drflac_read_pcm_frames_s16(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
            output.frames = frames;
        },
        .Float32 => {
            const frames = std.c.malloc(size);
            output.count = c.drflac_read_pcm_frames_f32(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
            output.frames = frames;
        },
    }

    return output;
}

pub fn seek_stream(stream: AudioStream, frame: usize) void {
    if (stream.format_handle == null) {
        return;
    }

    _ = c.drflac_seek_to_pcm_frame(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
}

pub fn close_stream(stream: AudioStream) void {
    if (stream.format_handle != null) {
        c.drflac_close(@alignCast(@ptrCast(stream.format_handle)));
    }
}
