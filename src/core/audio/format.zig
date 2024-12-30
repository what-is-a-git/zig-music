const std = @import("std");

pub const SupportedFormat = enum {
    // .wav
    WAVE,

    FLAC,
    MP3,

    // .ogg, makes a big assumption but whatever for now
    OGG_VORBIS,

    // .opus
    OGG_OPUS,

    /// This format shouldn't ever be found but
    /// it's technically possible if memory allocations
    /// on a small ascii lowercase version of the file
    /// extension fail.
    UNIDENTIFIABLE,
};

const FormatPairing = struct {
    extension: []const u8,
    format: SupportedFormat,
};

const pairings = [_]FormatPairing{
    .{ .extension = ".wav", .format = .WAVE },
    .{ .extension = ".flac", .format = .FLAC },
    .{ .extension = ".mp3", .format = .MP3 },
    .{ .extension = ".ogg", .format = .OGG_VORBIS },
    .{ .extension = ".opus", .format = .OGG_OPUS },
};

pub fn identify_format(file_path: []const u8) SupportedFormat {
    const raw_extension = std.fs.path.extension(file_path);
    const lowercase_extension = std.ascii.allocLowerString(std.heap.page_allocator, raw_extension) catch return SupportedFormat.UNIDENTIFIABLE;

    var format = SupportedFormat.UNIDENTIFIABLE;
    for (pairings) |pairing| {
        if (std.mem.eql(u8, lowercase_extension, pairing.extension)) {
            format = pairing.format;
            break;
        }
    }

    std.heap.page_allocator.free(lowercase_extension);
    return format;
}
