const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");

const FileReader = @import("file_reader.zig");
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cDefine("DR_FLAC_NO_STDIO", "1");
    @cInclude("dr_libs/dr_flac.h");
});

pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
    const bytes = read_file(file, allocator) catch |err| switch (err) {
        else => return err,
    };

    var output: AudioFile = .{
        .bit_format = requested_format,
    };

    switch (requested_format) {
        .SignedInt16 => {
            output.frames = c.drflac_open_memory_and_read_pcm_frames_s16(
                bytes.ptr,
                bytes.len,
                &output.channels,
                &output.sample_rate,
                &output.frame_count,
                null,
            );
        },
        .Float32 => {
            output.frames = c.drflac_open_memory_and_read_pcm_frames_f32(
                bytes.ptr,
                bytes.len,
                &output.channels,
                &output.sample_rate,
                &output.frame_count,
                null,
            );
        },
    }

    allocator.free(bytes);
    return output;
}

pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
    var output: AudioStream = .{ .allocator = allocator };

    const bytes = read_file(file, allocator) catch |err| return err;
    output.file_bytes = bytes;

    const drflac = c.drflac_open_memory(bytes.ptr, bytes.len, null);
    output.format_handle = @ptrCast(drflac);
    output.channels = @intCast(drflac.*.channels);
    output.sample_rate = @intCast(drflac.*.sampleRate);
    output.frame_count = @intCast(drflac.*.totalPCMFrameCount);

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

    stream.deinit();
}
