const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;
const AudioStream = @import("audio_stream.zig");
const AudioFile = @import("audio_file.zig");

const FileReader = @import("file_reader.zig");
const read_file = FileReader.read_file;
const ReadFileError = FileReader.ReadFileError;

const wav = @cImport({
    @cDefine("DR_WAV_NO_STDIO", "1");
    @cInclude("dr_libs/dr_wav.h");
});

const mp3 = @cImport({
    @cDefine("DR_MP3_NO_STDIO", "1");
    @cInclude("dr_libs/dr_mp3.h");
});

const flac = @cImport({
    @cDefine("DR_FLAC_NO_STDIO", "1");
    @cInclude("dr_libs/dr_flac.h");
});

pub const WAV = struct {
    pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
        const bytes = read_file(file, allocator) catch |err| return err;
        var output: AudioFile = .{
            .bit_format = requested_format,
        };

        switch (requested_format) {
            .SignedInt16 => {
                output.frames = wav.drwav_open_memory_and_read_pcm_frames_s16(
                    bytes.ptr,
                    bytes.len,
                    &output.channels,
                    &output.sample_rate,
                    &output.frame_count,
                    null,
                );
            },
            .Float32 => {
                output.frames = wav.drwav_open_memory_and_read_pcm_frames_f32(
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

        const drwav: *wav.drwav = @alignCast(@ptrCast(std.c.malloc(@sizeOf(wav.drwav))));
        _ = wav.drwav_init_memory(drwav, bytes.ptr, bytes.len, null);

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
                output.count = wav.drwav_read_pcm_frames_s16(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
                output.frames = frames;
            },
            .Float32 => {
                const frames = std.c.malloc(size);
                output.count = wav.drwav_read_pcm_frames_f32(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
                output.frames = frames;
            },
        }

        return output;
    }

    pub fn seek_stream(stream: AudioStream, frame: usize) void {
        if (stream.format_handle == null) {
            return;
        }

        _ = wav.drwav_seek_to_pcm_frame(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
    }

    pub fn close_stream(stream: AudioStream) void {
        if (stream.format_handle != null) {
            _ = wav.drwav_uninit(@alignCast(@ptrCast(stream.format_handle)));
            std.c.free(stream.format_handle);
        }

        stream.deinit();
    }
};

pub const MP3 = struct {
    pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
        const bytes = read_file(file, allocator) catch |err| switch (err) {
            else => return err,
        };

        var output: AudioFile = .{
            .bit_format = requested_format,
        };

        var mp3_config: mp3.drmp3_config = .{ .channels = undefined, .sampleRate = undefined };
        switch (requested_format) {
            .SignedInt16 => {
                output.frames = mp3.drmp3_open_memory_and_read_pcm_frames_s16(
                    bytes.ptr,
                    bytes.len,
                    &mp3_config,
                    &output.frame_count,
                    null,
                );
            },
            .Float32 => {
                output.frames = mp3.drmp3_open_memory_and_read_pcm_frames_f32(
                    bytes.ptr,
                    bytes.len,
                    &mp3_config,
                    &output.frame_count,
                    null,
                );
            },
        }

        output.channels = mp3_config.channels;
        output.sample_rate = mp3_config.sampleRate;

        allocator.free(bytes);
        return output;
    }

    pub fn open_stream(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError!AudioStream {
        var output: AudioStream = .{ .allocator = allocator };

        const bytes = read_file(file, allocator) catch |err| return err;
        output.file_bytes = bytes;

        const drmp3: *mp3.drmp3 = @alignCast(@ptrCast(std.c.malloc(@sizeOf(mp3.drmp3))));
        _ = mp3.drmp3_init_memory(drmp3, bytes.ptr, bytes.len, null);

        output.format_handle = @ptrCast(drmp3);
        output.channels = @intCast(drmp3.channels);
        output.sample_rate = @intCast(drmp3.sampleRate);
        output.frame_count = @intCast(mp3.drmp3_get_pcm_frame_count(drmp3));

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
                output.count = mp3.drmp3_read_pcm_frames_s16(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
                output.frames = frames;
            },
            .Float32 => {
                const frames = std.c.malloc(size);
                output.count = mp3.drmp3_read_pcm_frames_f32(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
                output.frames = frames;
            },
        }

        return output;
    }

    pub fn seek_stream(stream: AudioStream, frame: usize) void {
        if (stream.format_handle == null) {
            return;
        }

        _ = mp3.drmp3_seek_to_pcm_frame(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
    }

    pub fn close_stream(stream: AudioStream) void {
        if (stream.format_handle != null) {
            mp3.drmp3_uninit(@alignCast(@ptrCast(stream.format_handle)));
            std.c.free(stream.format_handle);
        }

        stream.deinit();
    }
};

pub const FLAC = struct {
    pub fn decode_file(file: std.fs.File, requested_format: BitFormat, allocator: std.mem.Allocator) ReadFileError!AudioFile {
        const bytes = read_file(file, allocator) catch |err| switch (err) {
            else => return err,
        };

        var output: AudioFile = .{
            .bit_format = requested_format,
        };

        switch (requested_format) {
            .SignedInt16 => {
                output.frames = flac.drflac_open_memory_and_read_pcm_frames_s16(
                    bytes.ptr,
                    bytes.len,
                    &output.channels,
                    &output.sample_rate,
                    &output.frame_count,
                    null,
                );
            },
            .Float32 => {
                output.frames = flac.drflac_open_memory_and_read_pcm_frames_f32(
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

        const drflac = flac.drflac_open_memory(bytes.ptr, bytes.len, null);
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
                output.count = flac.drflac_read_pcm_frames_s16(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
                output.frames = frames;
            },
            .Float32 => {
                const frames = std.c.malloc(size);
                output.count = flac.drflac_read_pcm_frames_f32(@alignCast(@ptrCast(stream.format_handle)), count, @alignCast(@ptrCast(frames))) * stream.channels;
                output.frames = frames;
            },
        }

        return output;
    }

    pub fn seek_stream(stream: AudioStream, frame: usize) void {
        if (stream.format_handle == null) {
            return;
        }

        _ = flac.drflac_seek_to_pcm_frame(@alignCast(@ptrCast(stream.format_handle)), @intCast(frame));
    }

    pub fn close_stream(stream: AudioStream) void {
        if (stream.format_handle != null) {
            flac.drflac_close(@alignCast(@ptrCast(stream.format_handle)));
        }

        stream.deinit();
    }
};
