const std = @import("std");

const BitFormat = @import("../core/audio/format.zig").BitFormat;

const AudioFile = @import("audio_file.zig");
const read_file = AudioFile.read_file;
const ReadFileError = AudioFile.ReadFileError;

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
        const bytes = read_file(file, allocator) catch |err| switch (err) {
            else => return err,
        };

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
};
