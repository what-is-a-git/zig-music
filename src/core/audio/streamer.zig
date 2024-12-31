const std = @import("std");
const al = @import("backend/al.zig");

const WAV = @import("backend/wav.zig");
const FLAC = @import("backend/flac.zig");
const MP3 = @import("backend/mp3.zig");
const Opus = @import("backend/opus.zig");
const Vorbis = @import("backend/vorbis.zig");

const AudioStream = @import("backend/audio_stream.zig");

const AudioFormat = @import("format.zig");
const BitFormat = AudioFormat.BitFormat;

const AudioStreamer = @This();

pub const BUFFER_COUNT = 6;
pub const BIT_FORMAT = BitFormat.Float32;
pub const SAMPLE_RATE_DIVISION = 4;

pub const DecodeError = AudioStream.DecodeError;
pub const ReadFileError = @import("backend/file_reader.zig").ReadFileError;
pub const InitError = ReadFileError || DecodeError;

source: al.Source = undefined,
buffers: [BUFFER_COUNT]al.Buffer = undefined,
format: AudioFormat.ContainerFormat = .UNSUPPORTED,
stream: AudioStream = undefined,
sample: usize = 0,
looping: bool = false,

pub fn init(file: *std.fs.File, format: AudioFormat.ContainerFormat) InitError!AudioStreamer {
    var self: AudioStreamer = .{};
    self.format = format;

    self.source = al.Source.init();
    for (0..BUFFER_COUNT) |i| {
        self.buffers[i] = al.Buffer.init();
    }

    self.stream = switch (format) {
        .WAV => WAV.open_stream(file) catch |err| return err,
        .FLAC => FLAC.open_stream(file) catch |err| return err,
        .MP3 => MP3.open_stream(file) catch |err| return err,
        .OGG_OPUS => Opus.open_stream(file) catch |err| return err,
        .OGG_VORBIS => Vorbis.open_stream(file) catch |err| return err,
        else => unreachable,
    };

    self.fill_buffers() catch |err| return err;
    return self;
}

pub fn process(self: *const AudioStreamer) AudioStream.DecodeError!void {
    var casted: *AudioStreamer = @constCast(self);
    return casted.process_buffers();
}

pub fn process_buffers(self: *AudioStreamer) AudioStream.DecodeError!void {
    var ready_count: i32 = self.source.get_processed_buffer_count();
    while (ready_count > 0) {
        self.stream_into(self.source.unqueue_buffer()) catch |err| return err;
        ready_count -= 1;
    }
}

pub fn clear_buffers(self: *AudioStreamer) void {
    var ready_count: i32 = self.source.get_processed_buffer_count();
    while (ready_count > 0) {
        _ = self.source.unqueue_buffer();
        ready_count -= 1;
    }
}

pub fn fill_buffers(self: *AudioStreamer) AudioStream.DecodeError!void {
    for (self.buffers) |buffer| {
        self.stream_into(buffer) catch |err| return err;
    }
}

pub fn stream_into(self: *AudioStreamer, buffer: al.Buffer) AudioStream.DecodeError!void {
    const FRAME_COUNT: usize = @divFloor(self.stream.sample_rate, SAMPLE_RATE_DIVISION);
    const pcm: AudioStream.DecodedPCM = switch (self.format) {
        .WAV => WAV.decode_stream(self.stream, BIT_FORMAT, FRAME_COUNT) catch |err| return err,
        .FLAC => FLAC.decode_stream(self.stream, BIT_FORMAT, FRAME_COUNT) catch |err| return err,
        .MP3 => MP3.decode_stream(self.stream, BIT_FORMAT, FRAME_COUNT) catch |err| return err,
        .OGG_OPUS => Opus.decode_stream(self.stream, BIT_FORMAT, FRAME_COUNT) catch |err| return err,
        .OGG_VORBIS => Vorbis.decode_stream(self.stream, BIT_FORMAT, FRAME_COUNT) catch |err| return err,
        else => unreachable,
    };
    defer pcm.deinit();

    if (pcm.count == 0) {
        // we use raw_seek here because we aren't replaying the file
        // and we are just looping the start data into a new buffer basically
        // for (mostly) perfect looping :p
        if (self.looping and self.sample != 0) {
            self.raw_seek(0.0);
            return self.stream_into(buffer);
        }

        // not sure if there's any problems with this case, if there is then take a look ig
        return;
    }

    self.sample += pcm.count;
    buffer.buffer_data(
        pcm.frames,
        BIT_FORMAT.to_al(self.stream.channels),
        @intCast(pcm.get_size()),
        @intCast(self.stream.sample_rate),
    );

    self.source.queue_buffer(&buffer);
}

pub fn deinit(self: *const AudioStreamer) void {
    self.stop();

    self.source.deinit();
    for (self.buffers) |buffer| {
        buffer.deinit();
    }

    switch (self.format) {
        .WAV => WAV.close_stream(self.stream),
        .FLAC => FLAC.close_stream(self.stream),
        .MP3 => MP3.close_stream(self.stream),
        .OGG_OPUS => Opus.close_stream(self.stream),
        .OGG_VORBIS => Vorbis.close_stream(self.stream),
        else => unreachable,
    }
}

pub fn play(self: *const AudioStreamer) void {
    self.source.play();
}

pub fn pause(self: *const AudioStreamer) void {
    self.source.pause();
}

pub fn stop(self: *const AudioStreamer) void {
    self.source.stop();
}

pub fn is_playing(self: *const AudioStreamer) bool {
    return self.source.is_playing();
}

pub fn get_time(self: *const AudioStreamer) f32 {
    return @as(f32, @floatCast(self.sample)) / @as(f32, @floatCast(self.stream.sample_rate));
}

fn raw_seek(self: *const AudioStreamer, seconds: f32) void {
    const sample: usize = @intFromFloat(@floor(seconds * @as(f32, @floatFromInt(self.stream.sample_rate))));
    switch (self.format) {
        .WAV => WAV.seek_stream(self.stream, sample),
        .FLAC => FLAC.seek_stream(self.stream, sample),
        .MP3 => MP3.seek_stream(self.stream, sample),
        .OGG_OPUS => Opus.seek_stream(self.stream, sample),
        .OGG_VORBIS => Vorbis.seek_stream(self.stream, sample),
        else => unreachable,
    }
}

pub fn seek(self: *const AudioStreamer, seconds: f32) void {
    if (seconds < 0.0) {
        seconds = 0.0;
    }

    const was_playing = self.is_playing();
    self.stop();
    self.raw_seek(seconds);
    self.clear_buffers();
    self.fill_buffers();

    if (was_playing) {
        self.play();
    }
}

pub fn set_volume(self: *const AudioStreamer, volume: f32) void {
    self.source.set_volume(volume);
}

pub fn set_looping(self: *const AudioStreamer, looping: bool) void {
    var casted: *AudioStreamer = @constCast(self);
    casted.looping = looping;
}

pub fn set_pitch(self: *const AudioStreamer, pitch: f32) void {
    self.source.set_pitch(pitch);
}
