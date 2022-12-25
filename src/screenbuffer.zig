// Virtual screenbuffer representing a 64x32 grid of virtual pixels that can be
// projected onto a screen using any graphics library.
const std = @import("std");

/// Width of the emulated device in virtual pixels
pub const V_WIDTH = 64;
/// Height of the emulated device in virtual pixels
pub const V_HEIGHT = 32;

pub const InternalBuffer = [V_HEIGHT][V_WIDTH]bool;

pub const ScreenBuffer = struct {
    buffer: InternalBuffer,

    const Self = @This();

    /// Clears the screen
    pub fn clear(self: *Self) void {
        self.buffer = std.mem.zeroes(InternalBuffer);
    }

    /// Turns a pixel on or off at a given point in the grid.  Returns true if
    /// this operation unsets a previous set pixel.  Returns false otherwise.
    /// C.f. http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#Dxyn
    pub fn setPixel(self: *Self, x: u32, y: u32, value: bool) bool {
        const previouslySet = self.buffer[y][x];
        self.buffer[y][x] = value;

        if ((value == false) and (previouslySet == true)) {
            return true;
        }

        return false;
    }
};

/// Creates and initializes a new ScreenBuffer
pub fn newScreenBuffer() ScreenBuffer {
    return .{
        .buffer = std.mem.zeroes(InternalBuffer),
    };
}
