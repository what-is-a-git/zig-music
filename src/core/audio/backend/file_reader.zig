const std = @import("std");

pub const ReadFileError = error{
    Unseekable,
    AccessDenied,
    FileTooBig,
    DecodingError,
    ZigError,
};
