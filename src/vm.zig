// Virtual machine implementing the Chip8 instruction set.
// Reference: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM

const std = @import("std");

const sprites = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

/// Represents the internal memory state of the virtual machine.
pub const VM = struct {
    registers: [16]u8,
    stack: [16]u16,
    delay_reg: u8,
    sound_reg: u8,
    index_reg: u8,
    sp: u8,
    pc: u16 = 0x200,
    mem: [4096]u8,
    reader: *std.fs.File.Reader,

    const Self = @This();
};

// This is inline so that we effectively just allocate everything in main's
// stack rather than having to do a heap allocation.  I haven't had a good
// night's sleep in weeks plus I suck at zig so this is probably fucking
// stupid, idk.
pub inline fn initVM(reader: *std.fs.File.Reader) VM {
    const registers: [16]u8 = undefined;
    var mem: [4096]u8 = undefined;
    const stack: [16]u16 = undefined;

    // Load our pixel font into memory:
    std.mem.copy(u8, mem[0..sprites.len], &sprites);

    return .{
        .registers = registers,
        .stack = stack,
        .delay_reg = 0,
        .sound_reg = 0,
        .index_reg = 0,
        .sp = 0,
        .mem = mem,
        .reader = reader,
    };
}
