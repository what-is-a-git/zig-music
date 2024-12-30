const std = @import("std");
const al = @import("backend/al.zig");
const dr = @import("backend/dr_libs.zig");
const Opus = @import("backend/opus.zig");
const Vorbis = @import("backend/stb_vorbis.zig");
const AudioFile = @import("backend/audio_file.zig").AudioFile;

var device: al.Device = undefined;
var context: al.Context = undefined;

pub fn main() !void {
    const cwd = std.fs.cwd();

    device = al.Device.init(al.Device.get_default_name());
    if (!device.is_valid()) {
        std.log.err("Failed to open default device", .{});
        return;
    }

    defer device.deinit();

    // technically opt in (but we have it), so force off hrtf for more "correct" stereo sound on all devices
    const attribs = [_]c_int{ al.Attributes.HRTF, al.Attributes.FALSE, 0 };
    context = al.Context.init(&device, &attribs);
    defer context.deinit();

    if (!context.make_current()) {
        std.log.err("Failed to make context current", .{});
        return;
    }

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        std.debug.print("No file supplied\n", .{});
        return;
    }

    const path = args[1];
    const ext = std.fs.path.extension(path);
    const zig_file = cwd.openFile(path, .{}) catch |err| switch (err) {
        std.fs.File.OpenError.FileNotFound => {
            std.log.err("Couldn't find unbeatable.wav in current directory.", .{});
            return;
        },
        else => {
            std.log.err("Unhandled error: {}", .{err});
            return;
        },
    };

    const start = std.time.nanoTimestamp();

    const bit_depth: AudioFile.BitDepth = AudioFile.BitDepth.Float32;
    var loading_file: ?AudioFile = null;
    const ext_lower = try std.ascii.allocLowerString(std.heap.page_allocator, ext);
    if (std.mem.eql(u8, ext_lower, ".mp3")) {
        loading_file = try dr.MP3.decode_file(zig_file, bit_depth, std.heap.page_allocator);
    } else if (std.mem.eql(u8, ext_lower, ".flac")) {
        loading_file = try dr.FLAC.decode_file(zig_file, bit_depth, std.heap.page_allocator);
    } else if (std.mem.eql(u8, ext_lower, ".wav")) {
        loading_file = try dr.WAV.decode_file(zig_file, bit_depth, std.heap.page_allocator);
    } else if (std.mem.eql(u8, ext_lower, ".ogg")) {
        loading_file = try Vorbis.decode_file(zig_file, bit_depth, std.heap.page_allocator);
    } else if (std.mem.eql(u8, ext_lower, ".opus")) {
        loading_file = try Opus.decode_file(zig_file, bit_depth, std.heap.page_allocator);
    }

    if (loading_file == null) {
        std.log.err("Couldn't find decoder for extension '{s}'!", .{ext_lower});
        std.heap.page_allocator.free(ext_lower);
        return;
    }

    const file = loading_file.?;

    std.heap.page_allocator.free(ext_lower);
    std.debug.print("took {} ms\n", .{@divFloor(std.time.nanoTimestamp() - start, 1_000_000)});

    const source = al.Source.init();
    defer source.deinit();

    source.set_volume(0.1);

    const buffer = al.Buffer.init();
    defer buffer.deinit();

    const format = switch (file.channels) {
        1 => switch (file.bit_depth) {
            .Signed16 => al.Formats.MONO16,
            .Float32 => al.Formats.MONO_FLOAT32,
        },
        else => switch (file.bit_depth) {
            .Signed16 => al.Formats.STEREO16,
            .Float32 => al.Formats.STEREO_FLOAT32,
        },
    };

    buffer.buffer_data(file.frames, format, @intCast(file.get_size()), @intCast(file.sample_rate));
    file.free();

    source.bind_buffer(&buffer);
    source.play();

    while (source.is_playing()) {
        std.time.sleep(1_000_000_000);
    }
}
