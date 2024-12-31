const std = @import("std");

const AudioContext = @import("core/audio/context.zig");
const AudioStreamer = @import("core/audio/streamer.zig");
const AudioFormat = @import("core/audio/format.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        std.debug.print("No file supplied\n", .{});
        return;
    }

    const cwd = std.fs.cwd();
    const path = args[1];
    var file = try cwd.openFile(path, .{});
    defer file.close();

    const format = AudioFormat.identify_format(path);
    if (format == .UNSUPPORTED) {
        std.log.err("Unsupported container format at path '{s}'!", .{path});
        return;
    }

    const context = AudioContext.init() catch |err| switch (err) {
        AudioContext.InitError.FailedToOpenDevice => {
            std.log.err("Failed to open OpenAL device!", .{});
            return;
        },
        AudioContext.InitError.FailedToCreateContext => {
            std.log.err("Failed to create OpenAL context!", .{});
            return;
        },
    };
    defer context.deinit();
    context.set_volume(0.25);

    const start = try std.time.Instant.now();
    const streamer = AudioStreamer.init(&file, format) catch |err| switch (err) {
        AudioStreamer.ReadFileError.CorruptFile => {
            std.log.err("Your file is not of the right type, try another one.", .{});
            return;
        },
        AudioStreamer.DecodeError.InvalidStream => {
            std.log.err("Failed to open valid audio stream for file, exiting.", .{});
            return;
        },
    };
    defer streamer.deinit();
    streamer.set_looping(true);
    streamer.play();

    const now = try std.time.Instant.now();
    std.debug.print("Took {d} ms to start streaming file.\n", .{@as(f128, @floatFromInt(now.since(start))) / @as(f128, @floatFromInt(std.time.ns_per_ms))});

    while (streamer.is_playing()) {
        streamer.process() catch |err| std.log.err("{}", .{err});
        std.Thread.sleep(std.time.ns_per_ms * 250);
    }
}
