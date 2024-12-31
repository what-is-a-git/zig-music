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
    const file = try cwd.openFile(path, .{});
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

    const start = try std.time.Instant.now();
    const streamer = AudioStreamer.init(file, format) catch |err| switch (err) {
        AudioStreamer.ReadFileError.Unseekable => {
            std.log.err("Given file was unseekable, exiting.", .{});
            return;
        },
        AudioStreamer.ReadFileError.FileTooBig => {
            std.log.err("Given file was too big to store in memory, exiting.", .{});
            return;
        },
        AudioStreamer.ReadFileError.AccessDenied => {
            std.log.err("Given file couldn't be accessed, exiting.", .{});
            return;
        },
        AudioStreamer.ReadFileError.DecodingError => {
            std.log.err("There was an error decoding your file, try another one!", .{});
            return;
        },
        AudioStreamer.ReadFileError.ZigError => {
            std.log.err("Zig had an arbitrary error when reading the file bytes, exiting.", .{});
            return;
        },
        AudioStreamer.DecodeError.InvalidStream => {
            std.log.err("Failed to open valid audio stream for file, exiting.", .{});
            return;
        },
        AudioStreamer.DecodeError.AllocationError => {
            std.log.err("Failed to allocate data for stream decoding, exiting.", .{});
            return;
        },
    };
    defer streamer.deinit();
    streamer.set_volume(0.25);
    streamer.set_looping(true);
    streamer.play();

    const now = try std.time.Instant.now();
    std.debug.print("Took {} ms to start streaming file.\n", .{@as(f128, @floatFromInt(now.since(start))) / @as(f128, @floatFromInt(std.time.ns_per_ms))});

    while (streamer.is_playing()) {
        streamer.process() catch |err| switch (err) {
            AudioStreamer.DecodeError.AllocationError => {
                std.log.err("Failed to allocate data for stream decoding, exiting.", .{});
                return;
            },
            // You can't have an invalid stream when the stream is already properly opened.
            else => unreachable,
        };
        std.Thread.sleep(std.time.ns_per_ms * 250);
    }
}
