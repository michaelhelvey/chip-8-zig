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
    var vm = try VM.init(&reader, &screenBuffer);

    var quit = false;
    while (!quit) {
        const exe_result = try vm.execute_frame();

        while (sdl.getEvent()) |event| {
            switch (event) {
                .Quit => {
                    quit = true;
                },
            }
        }

        switch (exe_result) {
            .Done => {},
            .Draw => {
                graphicsContext.render(&screenBuffer.buffer);
            },
        }

        sdl.GraphicsContext.wait();
    }
}
