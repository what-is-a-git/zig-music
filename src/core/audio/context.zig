const std = @import("std");
const al = @import("backend/al.zig");
const AudioContext = @This();

device: al.Device = undefined,
context: al.Context = undefined,

pub const InitError = error{
    FailedToOpenDevice,
    FailedToCreateContext,
};

/// Picks default device and starts up audio internals.
pub fn init() InitError!AudioContext {
    var self: AudioContext = .{};
    self.device = al.Device.init(al.Device.get_default_name());
    if (!self.device.is_valid()) {
        return InitError.FailedToOpenDevice;
    }

    // technically opt in (but we have it), so force off hrtf for more "correct" stereo sound on all devices
    const attribs = [_]c_int{ al.Attributes.HRTF, al.Attributes.FALSE, 0 };
    self.context = al.Context.init(&self.device, &attribs);
    if (!self.context.make_current()) {
        return InitError.FailedToCreateContext;
    }

    return self;
}

pub fn deinit(self: *const AudioContext) void {
    self.device.deinit();
    self.context.deinit();
}
