const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub fn init() void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("SDL failed to initialize. Fuck you.", .{});
        std.process.exit(1);
    }
}

pub fn quit() void {
    c.SDL_Quit();
}

pub const Event = c.SDL_Event;

pub const EventType = struct {
    pub const QUIT = c.SDL_EVENT_QUIT;
    pub const DROP_FILE = c.SDL_EVENT_DROP_FILE;
};

pub fn poll_event() ?Event {
    var event: Event = undefined;
    if (c.SDL_PollEvent(&event)) {
        return event;
    }

    return null;
}

pub fn wait_event() ?Event {
    var event: Event = undefined;
    if (c.SDL_WaitEvent(&event)) {
        return event;
    }

    return null;
}

pub fn wait_event_timeout(timeout_ms: i32) ?Event {
    var event: Event = undefined;
    if (c.SDL_WaitEventTimeout(&event, timeout_ms)) {
        return event;
    }

    return null;
}

pub const Window = struct {
    handle: *c.SDL_Window,

    pub const InitError = error{FailedToCreate};

    pub fn init(width: u16, height: u16, title: [*c]const u8) InitError!Window {
        const handle = c.SDL_CreateWindow(title, @intCast(width), @intCast(height), c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
        if (handle == null) {
            std.log.err("SDL failed to create a window. Oopsie poopsie!", .{});
            return InitError.FailedToCreate;
        }

        return .{ .handle = handle.? };
    }

    pub fn close(self: *const Window) void {
        c.SDL_DestroyWindow(self.handle);
    }
};
