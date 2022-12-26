const std = @import("std");
const sdl = @import("sdl.zig");
const sb = @import("screenbuffer.zig");
const vm = @import("vm.zig");

pub fn main() !void {
    var graphicsContext = try sdl.newGraphicsContext();
    defer graphicsContext.deinit();

    // statically allocate our screenbuffer
    var screenBuffer = comptime sb.newScreenBuffer();

    const file = try std.fs.cwd().openFile("./games/IBM.ch8", .{ .mode = .read_only });
    defer file.close();

    var reader = file.reader();
    var machine = vm.initVM(&reader);
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
