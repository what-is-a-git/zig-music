const std = @import("std");

const AudioContext = @import("core/audio/context.zig");
const AudioStreamer = @import("core/audio/streamer.zig");
const AudioFormat = @import("core/audio/format.zig");

const SDL3 = @import("core/gfx/backend/sdl3.zig");

var playing: bool = false;
var streamer: AudioStreamer = undefined;

fn audio_processor() void {
    while (true) {
        // we use playing as a safeguard, gotta be really careful with that
        if (playing) {
            streamer.process() catch |err| std.log.err("{}", .{err});
        }

        std.Thread.sleep(std.time.ns_per_ms * 250);
    }
}

pub fn main() !void {
    var file: std.fs.File = undefined;
    const cwd = std.fs.cwd();

    SDL3.init();
    defer SDL3.quit();

    const window = try SDL3.Window.init(800, 800, "Hey There Skibidi Sigmas!");
    defer window.close();

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
    context.set_volume(0.1);

    const audio_thread = try std.Thread.spawn(.{}, audio_processor, .{});
    defer audio_thread.detach();

    var running: bool = true;
    while (running) {
        var event: ?SDL3.Event = null;
        while (true) {
            event = SDL3.wait_event_timeout(500);
            if (event == null) {
                break;
            }

            const data = event.?;
            switch (data.type) {
                SDL3.EventType.QUIT => {
                    running = false;
                    if (playing) {
                        playing = false;
                        streamer.deinit();
                        file.close();
                    }

                    break;
                },
                SDL3.EventType.DROP_FILE => {
                    if (playing) {
                        playing = false;
                        streamer.deinit();
                        file.close();
                    }

                    const path = data.drop.data;
                    file = cwd.openFile(std.mem.span(path), .{}) catch {
                        std.debug.print("Couldn't open file for some reason. Is your file system just fucked?\n", .{});
                        break;
                    };

                    const format = AudioFormat.identify_format(std.mem.span(path));
                    if (format == .UNSUPPORTED) {
                        std.log.err("Unsupported container format at path '{s}'!", .{path});
                        break;
                    }

                    streamer = AudioStreamer.init(&file, format) catch |err| switch (err) {
                        AudioStreamer.ReadFileError.CorruptFile => {
                            std.log.err("Your file is not of the right type, try another one.", .{});
                            return;
                        },
                        AudioStreamer.DecodeError.InvalidStream => {
                            std.log.err("Failed to open valid audio stream for file, exiting.", .{});
                            return;
                        },
                    };
                    streamer.set_looping(true);
                    streamer.play();

                    playing = true;
                },
                else => {},
            }
        }
    }
}
