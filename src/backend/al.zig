pub const al = @cImport({
    @cInclude("AL/al.h");
    @cInclude("AL/alc.h");
    @cInclude("AL/alext.h");
});

pub const Attributes = struct {
    pub const HRTF = al.ALC_HRTF_SOFT;
    pub const TRUE = al.ALC_TRUE;
    pub const FALSE = al.ALC_FALSE;
};

pub const Formats = struct {
    pub const MONO8 = al.AL_FORMAT_MONO8;
    pub const MONO16 = al.AL_FORMAT_MONO16;
    pub const STEREO8 = al.AL_FORMAT_STEREO8;
    pub const STEREO16 = al.AL_FORMAT_STEREO16;

    pub const MONO_FLOAT32 = al.AL_FORMAT_MONO_FLOAT32;
    pub const STEREO_FLOAT32 = al.AL_FORMAT_STEREO_FLOAT32;
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

pub const Buffer = struct {
    al_buffer: c_uint = 0,

    pub fn init() Buffer {
        var buffer: Buffer = .{};
        al.alGenBuffers(1, &buffer.al_buffer);
        return buffer;
    }

    pub fn deinit(self: *const Buffer) void {
        al.alDeleteBuffers(1, &self.al_buffer);
    }

    pub fn buffer_data(self: *const Buffer, data: ?*const anyopaque, format: c_int, size: c_int, sample_rate: c_int) void {
        al.alBufferData(self.al_buffer, format, data, size, sample_rate);
    }
};

pub const Source = struct {
    al_source: c_uint = 0,

    pub fn init() Source {
        var source: Source = .{};
        al.alGenSources(1, &source.al_source);
        return source;
    }

    pub fn deinit(self: *const Source) void {
        // detach buffer so that doesn't cause potential issue
        al.alSourcei(self.al_source, al.AL_BUFFER, 0);
        al.alDeleteSources(1, &self.al_source);
    }

    fn bind_id(self: *const Source, buffer: c_uint) void {
        al.alSourcei(self.al_source, al.AL_BUFFER, @intCast(buffer));
    }

    pub fn bind_buffer(self: *const Source, buffer: *const Buffer) void {
        self.bind_id(buffer.al_buffer);
    }

    // TODO: buffer queueing for streaming

    fn get_state(self: *const Source) c_int {
        var state: c_int = 0;
        al.alGetSourcei(self.al_source, al.AL_SOURCE_STATE, &state);
        return state;
    }

    pub fn is_playing(self: *const Source) bool {
        return self.get_state() == al.AL_PLAYING;
    }

    pub fn play(self: *const Source) void {
        al.alSourcePlay(self.al_source);
    }

    pub fn stop(self: *const Source) void {
        al.alSourceStop(self.al_source);
    }

    pub fn pause(self: *const Source) void {
        al.alSourcePause(self.al_source);
    }

    pub fn get_time(self: *const Source) f32 {
        var seconds: f32 = undefined;
        al.alGetSourcef(self.al_source, al.AL_SEC_OFFSET, &seconds);
        return seconds;
    }

    pub fn seek(self: *const Source, seconds: f32) void {
        al.alSourcef(self.al_source, al.AL_SEC_OFFSET, seconds);
    }

    pub fn set_volume(self: *const Source, volume: f32) void {
        al.alSourcef(self.al_source, al.AL_GAIN, volume);
    }

    pub fn set_looping(self: *const Source, looping: bool) void {
        al.alSourcei(self.al_source, al.AL_LOOPING, if (looping) al.AL_TRUE else al.AL_FALSE);
    }

    pub fn set_pitch(self: *const Source, pitch: f32) void {
        al.alSourcef(self.al_source, al.AL_PITCH, pitch);
    }
};
