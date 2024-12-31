const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");

const FileReader = @import("file_reader.zig");
const ReadFileError = FileReader.ReadFileError;

const c = @cImport({
    @cDefine("DR_WAV_NO_STDIO", "1");
    @cInclude("dr_libs/dr_wav.h");
});

pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
    var output: AudioStream = .{ .allocator = allocator };

    const bytes = read_file(file, allocator) catch |err| return err;
    output.file_bytes = bytes;

    const drwav: *c.drwav = @alignCast(@ptrCast(std.c.malloc(@sizeOf(c.drwav))));
    _ = c.drwav_init_memory(drwav, bytes.ptr, bytes.len, null);

    output.format_handle = @ptrCast(drwav);
    output.channels = @intCast(drwav.channels);
    output.sample_rate = @intCast(drwav.sampleRate);
    output.frame_count = @intCast(drwav.totalPCMFrameCount);

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
            output.count = c.drwav_read_pcm_frames_s16(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
            output.frames = frames;
        },
        .Float32 => {
            const frames = std.c.malloc(size);
            output.count = c.drwav_read_pcm_frames_f32(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
            output.frames = frames;
        },
    }

    return output;
}

pub fn seek_stream(stream: AudioStream, frame: usize) void {
    if (stream.format_handle == null) {
        return;
    }

    _ = c.drwav_seek_to_pcm_frame(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
}

pub fn close_stream(stream: AudioStream) void {
    if (stream.format_handle != null) {
        _ = c.drwav_uninit(@alignCast(@ptrCast(stream.format_handle)));
        std.c.free(stream.format_handle);
    }

    stream.deinit();
}
