const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");

const FileReader = @import("file_reader.zig");
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cDefine("DR_MP3_NO_STDIO", "1");
    @cInclude("dr_libs/dr_mp3.h");
});

pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
    var output: AudioStream = .{ .allocator = allocator };

    const bytes = read_file(file, allocator) catch |err| return err;
    output.file_bytes = bytes;

    const drmp3: *c.drmp3 = @alignCast(@ptrCast(std.c.malloc(@sizeOf(c.drmp3))));
    _ = c.drmp3_init_memory(drmp3, bytes.ptr, bytes.len, null);

    output.format_handle = @ptrCast(drmp3);
    output.channels = @intCast(drmp3.channels);
    output.sample_rate = @intCast(drmp3.sampleRate);
    output.frame_count = @intCast(c.drmp3_get_pcm_frame_count(drmp3));

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
            output.count = c.drmp3_read_pcm_frames_s16(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
            output.frames = frames;
        },
        .Float32 => {
            const frames = std.c.malloc(size);
            output.count = c.drmp3_read_pcm_frames_f32(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
            output.frames = frames;
        },
    }

    return output;
}

pub fn seek_stream(stream: AudioStream, frame: usize) void {
    if (stream.format_handle == null) {
        return;
    }

    _ = c.drmp3_seek_to_pcm_frame(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
}

pub fn close_stream(stream: AudioStream) void {
    if (stream.format_handle != null) {
        c.drmp3_uninit(@alignCast(@ptrCast(stream.format_handle)));
        std.c.free(stream.format_handle);
    }

    stream.deinit();
}
