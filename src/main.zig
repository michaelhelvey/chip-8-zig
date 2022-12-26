const std = @import("std");
const sdl = @import("sdl.zig");
const ScreenBuffer = @import("screenbuffer.zig").ScreenBuffer;
const VM = @import("vm.zig").VM;

pub fn main() !void {
    var graphicsContext = try sdl.GraphicsContext.init();
    defer graphicsContext.deinit();

    // statically allocate our screenbuffer
    var screenBuffer = ScreenBuffer.init();

    const file = try std.fs.cwd().openFile("./games/IBM.ch8", .{ .mode = .read_only });
    defer file.close();

    var reader = file.reader();
    var machine = VM.init(&reader);
    _ = machine;

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
