// Graphics operations implemented using SDL2
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const screen = @import("screenbuffer.zig");

// ****************************************************************************
// Configuration Flags
// ****************************************************************************

const SDL_INIT_FLAGS = c.SDL_INIT_VIDEO;
const SDL_WINDOW_FLAGS = 0;
const SDL_RENDERER_FLAGS = c.SDL_RENDERER_ACCELERATED;

/// The scale by which the virtual pixels are multipled to map the buffer onto
/// a real display.
const SCALE = 20;

// const BG_COLOR = 0x6080FF;
const BG_COLOR = 0x000000;
const FG_COLOR = 0xFFFFFF;

const FRAME_RATE = 10;

// ****************************************************************************
// Graphics Context
// ****************************************************************************

pub const SDLError = error{
    SDLInitFailed,
    SDLCreateWindowFailed,
    SDLCreateRendererFailed,
};

pub const GraphicsContext = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,

    const Self = @This();

    pub fn init() SDLError!Self {
        if (c.SDL_Init(SDL_INIT_FLAGS) != 0) {
            c.SDL_Log("SDL_Init error: %s\n", c.SDL_GetError());
            return SDLError.SDLInitFailed;
        }

        const window = c.SDL_CreateWindow("Chip8", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, screen.V_WIDTH * SCALE, screen.V_HEIGHT * SCALE, SDL_WINDOW_FLAGS) orelse {
            c.SDL_Log("SDL_CreateWindow error: %s\n", c.SDL_GetError());
            return SDLError.SDLCreateWindowFailed;
        };

        const renderer = c.SDL_CreateRenderer(window, -1, SDL_RENDERER_FLAGS) orelse {
            c.SDL_Log("SDL_CreateRenderer error: %s\n", c.SDL_GetError());
            return SDLError.SDLCreateRendererFailed;
        };

        return .{
            .window = window,
            .renderer = renderer,
        };
    }

    /// Projects and flushes a virtualized screen buffer onto the real screen
    pub fn render(self: *const Self, buffer: *screen.InternalBuffer) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, red(BG_COLOR), green(BG_COLOR), blue(BG_COLOR), 255);
        _ = c.SDL_RenderClear(self.renderer);

        // read through the framebuffer and render out each virtual pixel:
        var x: u32 = 0;
        var y: u32 = 0;

        while (y < screen.V_HEIGHT) {
            x = 0;
            while (x < screen.V_WIDTH) {
                if (buffer.*[y][x]) {
                    const rect = c.SDL_Rect{ .x = @intCast(c_int, x * SCALE), .y = @intCast(c_int, y * SCALE), .w = SCALE, .h = SCALE };
                    _ = c.SDL_SetRenderDrawColor(self.renderer, red(FG_COLOR), green(FG_COLOR), blue(FG_COLOR), 255);
                    _ = c.SDL_RenderFillRect(self.renderer, &rect);
                    _ = c.SDL_SetRenderDrawColor(self.renderer, red(BG_COLOR), green(BG_COLOR), blue(BG_COLOR), 255);
                    _ = c.SDL_RenderDrawRect(self.renderer, &rect);
                }
                x += 1;
            }
            y += 1;
        }

        c.SDL_RenderPresent(self.renderer);
    }

    pub fn wait() void {
        c.SDL_Delay(1000 / FRAME_RATE);
    }

    pub fn deinit(self: *const Self) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};

/// The subset of events that we want to be able to handle.
pub const UserEvent = enum {
    Quit,
};

/// Polls for events, and if it's an event that we handle, returns it.
pub fn getEvent() ?UserEvent {
    var event: c.SDL_Event = undefined;
    const hasEvents = c.SDL_PollEvent(&event);

    if (hasEvents == 1) {
        return switch (event.type) {
            c.SDL_QUIT => UserEvent.Quit,
            else => null,
        };
    }

    return null;
}

// ****************************************************************************
// Internal Utilities
// ****************************************************************************
//
fn red(color: u32) u8 {
    return @intCast(u8, (color & 0xFF0000) >> 16);
}

fn green(color: u32) u8 {
    return @intCast(u8, (color & 0x00FF00) >> 8);
}

fn blue(color: u32) u8 {
    return @intCast(u8, color & 0x0000FF);
}
