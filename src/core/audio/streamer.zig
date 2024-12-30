const std = @import("std");
const al = @import("../../backend/al.zig");

const dr = @import("../../backend/dr_libs.zig");
const Opus = @import("../../backend/opus.zig");
const Vorbis = @import("../../backend/stb_vorbis.zig");

const AudioStream = @import("../../backend/audio_stream.zig");
const ReadFileError = @import("../../backend/file_reader.zig").ReadFileError;

const AudioFormat = @import("format.zig");
const BitFormat = AudioFormat.BitFormat;

const AudioStreamer = @This();

pub const BUFFER_COUNT = 6;
pub const BIT_FORMAT = BitFormat.Float32;

source: al.Source = undefined,
buffers: [BUFFER_COUNT]al.Buffer = undefined,
format: AudioFormat.SupportedFormat = .UNIDENTIFIABLE,
stream: AudioStream = undefined,
sample: usize = 0,
looping: bool = false,

pub const InitError = ReadFileError || AudioStream.DecodeError;

pub fn init(file: std.fs.File, format: AudioFormat.SupportedFormat) InitError!AudioStreamer {
    var self: AudioStreamer = .{};
    self.format = format;

    self.source = al.Source.init();
    for (0..BUFFER_COUNT) |i| {
        self.buffers[i] = al.Buffer.init();
    }

    self.stream = switch (format) {
        .OGG_OPUS => Opus.open_stream(file, std.heap.page_allocator) catch |err| return err,
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

pub fn fill_buffers(self: *AudioStreamer) AudioStream.DecodeError!void {
    for (self.buffers) |buffer| {
        self.stream_into(buffer) catch |err| return err;
    }
}

pub fn stream_into(self: *AudioStreamer, buffer: al.Buffer) AudioStream.DecodeError!void {
    const FRAME_COUNT: usize = @divFloor(self.stream.sample_rate, 10);
    const pcm: AudioStream.DecodedPCM = switch (self.format) {
        .OGG_OPUS => Opus.decode_stream(self.stream, BIT_FORMAT, FRAME_COUNT) catch |err| return err,
        else => unreachable,
    };
    defer pcm.deinit();

    if (pcm.count == 0) {
        // EOF
        if (self.looping and self.sample != 0) {
            self.seek(0.0);
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
    self.source.deinit();
    for (self.buffers) |buffer| {
        buffer.deinit();
    }

    switch (self.format) {
        .OGG_OPUS => Opus.close_stream(self.stream),
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

pub fn seek(self: *const AudioStreamer, seconds: f32) void {
    const sample: usize = @intFromFloat(@floor(seconds * @as(f32, @floatFromInt(self.stream.sample_rate))));
    switch (self.format) {
        .OGG_OPUS => Opus.seek_stream(self.stream, sample),
        else => unreachable,
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
