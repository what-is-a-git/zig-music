const std = @import("std");

pub const ReadFileError = error{
    CorruptFile,
};
