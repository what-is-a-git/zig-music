pub const al = @cImport({
    @cInclude("AL/al.h");
    @cInclude("AL/alc.h");
    @cInclude("AL/alext.h");
});

pub const Attributes = struct {
    pub const HRTF = al.ALC_SOFT_HRTF;
    pub const TRUE = al.ALC_TRUE;
    pub const FALSE = al.ALC_FALSE;
};

pub const Device = struct {
    al_device: ?*al.ALCdevice = null,

    pub fn get_default_name() [*c]const u8 {
        return al.alcGetString(null, al.ALC_DEFAULT_DEVICE_SPECIFIER);
    }

    pub fn is_valid(self: *const Device) bool {
        return self.al_device != null;
    }

    pub fn init(name: [*c]const u8) Device {
        const device = al.alcOpenDevice(name);
        if (device != null) {
            return .{ .al_device = device };
        }

        return .{};
    }

    pub fn deinit(self: *const Device) void {
        if (!self.is_valid()) {
            return;
        }

        _ = al.alcCloseDevice(self.al_device);
    }
};

pub const Context = struct {
    al_context: ?*al.ALCcontext = null,

    pub fn is_valid(self: *const Context) bool {
        return self.al_context != null;
    }

    pub fn init(device: *const Device, attribs: [*c]const c_int) Context {
        const context = al.alcCreateContext(device.al_device, attribs);
        if (context != null) {
            return .{ .al_context = context };
        }

        return .{};
    }

    pub fn deinit(self: *const Context) void {
        if (!self.is_valid()) {
            return;
        }

        al.alcDestroyContext(self.al_context);
    }

    pub fn make_current(self: *const Context) bool {
        if (!self.is_valid()) {
            return false;
        }

        return al.alcMakeContextCurrent(self.al_context) == al.ALC_TRUE;
    }
};
