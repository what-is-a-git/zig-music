const std = @import("std");

pub const ReadFileError = error{
    Unseekable,
    AccessDenied,
    FileTooBig,
    ZigError,
};

pub fn read_file(file: std.fs.File, allocator: std.mem.Allocator) ReadFileError![]u8 {
    file.seekTo(0) catch |err| switch (err) {
        std.posix.SeekError.Unseekable => return ReadFileError.Unseekable,
        std.posix.SeekError.AccessDenied => return ReadFileError.AccessDenied,
        else => return ReadFileError.ZigError,
    };

    return file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| switch (err) {
        else => return ReadFileError.FileTooBig,
    };
}
