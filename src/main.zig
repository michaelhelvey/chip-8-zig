const std = @import("std");
const sdl = @import("sdl.zig");
const sb = @import("screenbuffer.zig");

pub fn main() !void {
    var graphicsContext = try sdl.newGraphicsContext();
    defer graphicsContext.deinit();

    var screenBuffer = comptime sb.newScreenBuffer();

    // TODO: create our virtual machine that will handle instructions
    var quit = false;
    while (!quit) {
        while (sdl.getEvent()) |event| {
            switch (event) {
                .Quit => {
                    quit = true;
                },
            }
        }

        graphicsContext.render(&screenBuffer.buffer);
    }
}
