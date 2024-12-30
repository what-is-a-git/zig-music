const std = @import("std");

const AudioFile = @import("backend/audio_file.zig");
const ReadFileError = AudioFile.ReadFileError;

const AudioFormat = @import("core/audio/format.zig");
const AudioSampler = @import("core/audio/sampler.zig");
const AudioContext = @import("core/audio/context.zig");
const InitError = AudioContext.InitError;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    if (args.len < 2) {
        std.debug.print("No file supplied\n", .{});
        return;
    }

    const cwd = std.fs.cwd();
    const path = args[1];
    const file = try cwd.openFile(path, .{});
    const format = AudioFormat.identify_format(path);
    if (format == .UNIDENTIFIABLE) {
        std.log.err("Couldn't identify format from path '{s}'!", .{path});
        return;
    }

    const context = AudioContext.init() catch |err| switch (err) {
        InitError.FailedToOpenDevice => {
            std.log.err("Failed to open OpenAL device!", .{});
            return;
        },
        InitError.FailedToCreateContext => {
            std.log.err("Failed to create OpenAL context!", .{});
            return;
        },
    };
    defer context.deinit();

    const start = try std.time.Instant.now();
    const sampler = AudioSampler.init(file, format) catch |err| switch (err) {
        ReadFileError.Unseekable => {
            std.log.err("Given file was unseekable, exiting.", .{});
            return;
        },
        ReadFileError.FileTooBig => {
            std.log.err("Given file was too big to store in memory, exiting.", .{});
            return;
        },
        ReadFileError.AccessDenied => {
            std.log.err("Given file couldn't be accessed, exiting.", .{});
            return;
        },
        ReadFileError.ZigError => {
            std.log.err("Zig had an arbitrary error when decoding the audio file, exiting.", .{});
            return;
        },
    };
    sampler.set_volume(0.25);
    sampler.play();

    const now = try std.time.Instant.now();
    std.debug.print("Took {} ms to decode file.\n", .{now.since(start) / std.time.ns_per_ms});

    while (sampler.is_playing()) {
        std.Thread.sleep(std.time.ns_per_s);
    }
}
