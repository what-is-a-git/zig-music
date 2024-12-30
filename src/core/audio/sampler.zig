const std = @import("std");
const al = @import("../../backend/al.zig");

const dr = @import("../../backend/dr_libs.zig");
const Opus = @import("../../backend/opus.zig");
const Vorbis = @import("../../backend/stb_vorbis.zig");

const audio_file = @import("../../backend/audio_file.zig");
const AudioFile = audio_file.AudioFile;
const ReadFileError = audio_file.ReadFileError;

const AudioFormat = @import("format.zig");

const AudioSampler = @This();

source: al.Source = undefined,
buffer: al.Buffer = undefined,

pub fn init(file: std.fs.File, format: AudioFormat.SupportedFormat) ReadFileError!AudioSampler {
    var self: AudioSampler = .{};
    self.source = al.Source.init();
    self.buffer = al.Buffer.init();

    var data: AudioFile = undefined;
    const bit_depth: AudioFile.BitDepth = AudioFile.BitDepth.Float32;
    switch (format) {
        .WAVE => data = dr.WAV.decode_file(file, bit_depth, std.heap.page_allocator) catch |err| return err,
        .FLAC => data = dr.FLAC.decode_file(file, bit_depth, std.heap.page_allocator) catch |err| return err,
        .MP3 => data = dr.MP3.decode_file(file, bit_depth, std.heap.page_allocator) catch |err| return err,
        .OGG_VORBIS => data = Vorbis.decode_file(file, bit_depth, std.heap.page_allocator) catch |err| return err,
        .OGG_OPUS => data = Opus.decode_file(file, bit_depth, std.heap.page_allocator) catch |err| return err,
        .UNIDENTIFIABLE => unreachable,
    }

    const al_format = switch (data.channels) {
        1 => switch (data.bit_depth) {
            .Signed16 => al.Formats.MONO16,
            .Float32 => al.Formats.MONO_FLOAT32,
        },
        else => switch (data.bit_depth) {
            .Signed16 => al.Formats.STEREO16,
            .Float32 => al.Formats.STEREO_FLOAT32,
        },
    };
    self.buffer.buffer_data(data.frames, al_format, @intCast(data.get_size()), @intCast(data.sample_rate));
    data.free();

    self.source.bind_buffer(&self.buffer);
    return self;
}

pub fn deinit(self: *const AudioSampler) void {
    self.source.deinit();
    self.buffer.deinit();
}

pub fn play(self: *const AudioSampler) void {
    self.source.play();
}

pub fn pause(self: *const AudioSampler) void {
    self.source.pause();
}

pub fn stop(self: *const AudioSampler) void {
    self.source.stop();
}

pub fn is_playing(self: *const AudioSampler) bool {
    return self.source.is_playing();
}

pub fn get_time(self: *const AudioSampler) f32 {
    return self.source.get_time();
}

pub fn seek(self: *const AudioSampler, seconds: f32) void {
    self.source.seek(seconds);
}

pub fn set_volume(self: *const AudioSampler, volume: f32) void {
    self.source.set_volume(volume);
}

pub fn set_looping(self: *const AudioSampler, looping: bool) void {
    self.source.set_looping(looping);
}

pub fn set_pitch(self: *const AudioSampler, pitch: f32) void {
    self.source.set_pitch(pitch);
}
