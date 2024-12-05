const std = @import("std");
const al = @import("al.zig");

const dr = @cImport({
    @cDefine("DR_WAV_NO_STDIO", "1");
    @cDefine("DR_WAV_NO_WCHAR", "1");
    @cInclude("dr_libs/dr_wav.h");

    @cDefine("DR_MP3_NO_STDIO", "1");
    @cDefine("DR_MP3_NO_WCHAR", "1");
    @cInclude("dr_libs/dr_mp3.h");

    @cDefine("DR_FLAC_NO_STDIO", "1");
    @cDefine("DR_FLAC_NO_WCHAR", "1");
    @cInclude("dr_libs/dr_flac.h");
});

const stb = @cImport({
    @cDefine("STB_VORBIS_NO_STDIO", "1");
    @cInclude("stb/stb_vorbis.h");
});

fn playFile(file_path: []const u8) !al.al.ALuint {
    var source: al.al.ALuint = 0;
    al.al.alGenSources(1, &source);
    al.al.alSourcei(source, al.al.AL_LOOPING, al.al.AL_FALSE);

    var buffer: al.al.ALuint = 0;
    al.al.alGenBuffers(1, &buffer);

    const start = try std.time.Instant.now();
    const file = try std.fs.cwd().openFile(file_path, .{});

    const data = try file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize));
    file.close();

    var frames: c_int = 0;
    var channels: c_int = 0;
    var rate: c_int = 0;
    var pcm: ?*c_short = null;
    frames = stb.stb_vorbis_decode_memory(@ptrCast(data), @intCast(data.len), &channels, &rate, &pcm);

    std.heap.page_allocator.free(data);

    const size: al.al.ALsizei = @intCast(frames * @sizeOf(dr.drflac_int16) * channels);
    al.al.alBufferData(buffer, al.al.AL_FORMAT_STEREO16, pcm, size, @intCast(rate));

    dr.drflac_free(pcm, null);

    al.al.alSourcei(source, al.al.AL_BUFFER, @intCast(buffer));
    al.al.alSourcef(source, al.al.AL_GAIN, 0.5);

    const now47 = try std.time.Instant.now();
    std.debug.print("took {d} ms to play\n", .{now47.since(start) / std.time.ns_per_ms});

    return source;
}

var bf: al.al.ALuint = 0;

fn loadShitter(file_path: []const u8) void {
    bf = playFile(file_path) catch return;
}

pub fn main() !void {
    const device = al.Device.init(al.Device.get_default_name());
    if (!device.is_valid()) {
        std.log.err("Failed to open default device", .{});
        return error.FailedToOpenDefaultDevice;
    }

    defer device.deinit();

    const attribs = [_]c_int{ al.Attributes.HRTF, al.Attributes.FALSE, 0 };
    const context = al.Context.init(&device, &attribs);
    defer context.deinit();

    if (!context.make_current()) {
        std.log.err("Failed to make context current", .{});
        return error.FailedToMakeContextCurrent;
    }

    const start = try std.time.Instant.now();
    _ = try std.Thread.spawn(.{}, loadShitter, .{"/home/riley/mass_storage/user/games/funkin/Marios Madness/assets/songs/unbeatable/Voices.ogg"});
    const inst = try playFile("/home/riley/mass_storage/user/games/funkin/Marios Madness/assets/songs/unbeatable/Inst.ogg");

    while (bf == 0) {
        std.time.sleep(100);
    }

    al.al.alSourcePlay(inst);
    al.al.alSourcePlay(bf);
    const now47 = try std.time.Instant.now();
    std.debug.print("took {d} ms to play SONG\n", .{now47.since(start) / std.time.ns_per_ms});

    var state: al.al.ALint = 0;
    var last = try std.time.Instant.now();
    var tps: u64 = 0;
    while (true) {
        al.al.alGetSourcei(inst, al.al.AL_SOURCE_STATE, &state);
        if (state != al.al.AL_PLAYING) {
            break;
        }

        const now = try std.time.Instant.now();
        tps += 1;
        if (now.since(last) > std.time.ns_per_s) {
            std.debug.print("\r{d} TPS", .{tps});
            tps = 0;
            last = now;
        }

        std.time.sleep(std.time.ns_per_s);
    }

    al.al.alDeleteSources(1, &inst);
    al.al.alDeleteSources(1, &bf);
}
