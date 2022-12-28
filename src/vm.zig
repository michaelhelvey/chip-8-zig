// Virtual machine implementing the Chip8 instruction set.
// Reference: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM

const std = @import("std");

const font_sprites = [_]u8{
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

/// length of an instruction in bytes
const INSTRUCTION_LEN = 2;

pub const ExecutionError = error{
    InvalidInstructionLen,
};

/// A raw instruction, when read from a binary file, is represented as an array
/// of bytes.
const RawInstruction = [INSTRUCTION_LEN]u8;

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

    pub fn init(reader: *std.fs.File.Reader) Self {
        var result = Self{
            .registers = [_]u8{0} ** 16,
            .stack = [_]u16{0} ** 16,
            .delay_reg = 0,
            .sound_reg = 0,
            .index_reg = 0,
            .sp = 0,
            .mem = [_]u8{0} ** 4096,
            .reader = reader,
        };

        // Load font sprites
        std.mem.copy(u8, result.mem[0..font_sprites.len], &font_sprites);

        return result;
    }

    /// Executes instructions up until the screen needs to be repainted.
    pub fn execute_frame(self: *Self) !void {
        var buffer: RawInstruction = undefined;

        while (true) {
            const bytes_read = try self.reader.read(&buffer);

            if (bytes_read > 0 and bytes_read < INSTRUCTION_LEN) {
                return error.InvalidInstructionLen;
            }

            if (bytes_read == 0) {
                std.log.debug("Reached end of program\n", .{});
                break;
            }

            // if we reach this point, buffer should contain a valid instruction.
            const instruction = parseInstruction(&buffer);
            _ = instruction;
        }
    }
};

const InstructionType = enum {
    Sys,
    Clear,
    Return,
    Jump,
    Call,
    SkipIfEqual,
    SkipIfNotEqual,
    SkipIfRegistersEqual,
    StoreImmediate,
    AddImmediate,
    StoreRegister,
    Or,
    And,
    Xor,
    AddRegisters,
    SubstractRegistersImmutably, // subtract VY from VX only saving whether a borrow occurred
    ShiftRight,
    Minus,
    SubstractRegisters, // subtract VY from VX and save to VX
    ShiftLeft,
    SkipIfRegistersNotEqual,
    StoreAddress,
    JumpToAddressPlus,
    SetRandomMask,
    DrawSprite,
    SkipIfPressed,
    SkipIfNotPressed,
    StoreDelay,
    WaitForKeypress,
    SetDelayTimer,
    SetSoundTimer,
    AddIndexRegister,
    SetIndexToSprite,
    StoreBinaryDecimal,
    StoreAllRegisters,
    FillRegistersFromMem,
};

const ParsedInstruction = struct {
    type: InstructionType,
    // QUESTION: does endianness matter if all I am doing is casting a byte
    // array to a u16, not as in "a 16 bit number" but literally just as "16
    // bits of data in the same order that they were in in the original binary?
    // i.e. I don't give a fuck what the most significant byte is in the
    // architecture of my CPU, just that the resulting u16 reflects the bit
    // order in the original binary program.
    data: u16,

    const Self = @This();

    pub fn first_nibble(self: *const Self) u4 {
        return (self.data >> 8) & 0x0F;
    }

    pub fn second_nibble(self: *const Self) u4 {
        return (self.data >> 4) & 0x00F;
    }

    pub fn third_nibble(self: *const Self) u4 {
        return self.data & 0x000F;
    }
};

pub fn parseInstruction(buffer: *RawInstruction) ParsedInstruction {
    // the value of the first nibble determines the instruction type in chip8
    return switch (buffer[0] >> 4) {
        0 => {
            // There are a few "special" instructions starting with 0 that we need to handle
            if (buffer.* == 0x00EE) {
                return .{ .type = InstructionType.RET, .data = @bitCast(u16, buffer.*) };
            } else if (buffer.* == 0x00E0) {
                return .{ .type = InstructionType.CLS, .data = @bitCast(u16, buffer.*) };
            }
            return .{ .type = InstructionType.SYS, .data = @bitCast(u16, buffer.*) };
        },
        else => unreachable,
    };
}
