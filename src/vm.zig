// Virtual machine implementing the Chip8 instruction set.
// Reference: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM

const std = @import("std");
const ScreenBuffer = @import("screenbuffer.zig").ScreenBuffer;

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

pub const ExecutionResult = enum {
    Draw,
    Done,
};

pub const VM = struct {
    registers: [16]u8,
    stack: [16]u16,
    delay_reg: u8,
    sound_reg: u8,
    index_reg: u16,
    sp: u8,
    pc: u16 = 0x200,
    mem: [4096]u8,
    screenbuffer: *ScreenBuffer,

    const Self = @This();

    pub fn init(reader: *std.fs.File.Reader, screenbuffer: *ScreenBuffer) !Self {
        var result = Self{
            .registers = [_]u8{0} ** 16,
            .stack = [_]u16{0} ** 16,
            .delay_reg = 0,
            .sound_reg = 0,
            .index_reg = 0,
            .sp = 0,
            .mem = [_]u8{0} ** 4096,
            .screenbuffer = screenbuffer,
        };

        // Load font sprites
        std.mem.copy(u8, result.mem[0..font_sprites.len], &font_sprites);

        // Load program into machine memory starting at 0x200 by convention.
        // In ye olden days, the first bytes would be for the font sprites +
        // the actual CHIP-8 interpreter.
        const bytes_read = try reader.readAll(result.mem[result.pc..]);
        std.log.debug("read {} instructions into memory starting at {X}\n", .{ bytes_read / 2, result.pc });

        return result;
    }

    /// Executes instructions up until the screen needs to be repainted.
    pub fn execute_frame(self: *Self) !ExecutionResult {
        while (true) {
            // Read an instruction out of memory
            const raw_instruction = self.mem[self.pc .. self.pc + 2];
            const instruction = parseInstruction(raw_instruction);

            self.execute_instruction(instruction);

            // Loop forever:
            if (self.pc >= 0xFFE) {
                return ExecutionResult.Done;
                // self.pc = 0x200;
            } else {
                self.pc += 2;
            }

            // when we draw to the screen, defer execution back to the main
            // loop to let the graphics context handle it.
            if (instruction.type == InstructionType.DrawSprite) {
                return ExecutionResult.Draw;
            }
        }
    }

    fn execute_instruction(self: *Self, instruction: ParsedInstruction) void {
        switch (instruction.type) {
            InstructionType.Clear => {
                self.screenbuffer.clear();
            },
            InstructionType.Jump => {
                self.pc = instruction.data & 0x0FFF;
            },
            InstructionType.StoreImmediate => {
                const number = instruction.data & 0x00FF;
                self.registers[instruction.first_nibble()] = @intCast(u8, number);
            },
            InstructionType.AddImmediate => {
                const value = instruction.data & 0x00FF;
                self.registers[instruction.first_nibble()] +%= @intCast(u8, value);
            },
            InstructionType.StoreAddressInIndex => {
                const address = instruction.data & 0x0FFF;
                self.index_reg = address;
            },
            InstructionType.DrawSprite => {
                // DXYN - Draw a sprite at position VX, VY with N bytes of
                // sprite data starting at the address stored in I.  Set VF to
                // 01 if any set pixels are changed to unset, and 00 otherwise.
                //
                // Sprites are drawn to the screen using the DXYN instruction.
                // All sprites are rendered using an exclusive-or (XOR) mode;
                // when a request to draw a sprite is processed, the given
                // sprite's data is XOR'd with the current graphics data of the
                // screen. If the program attempts to draw a sprite at an x
                // coordinate greater than 0x3F, the x value will be reduced
                // modulo 64. Similarly, if the program attempts to draw at a y
                // coordinate greater than 0x1F, the y value will be reduced
                // modulo 32. Sprites that are drawn partially off-screen will
                // be clipped. Sprites are always eight pixels wide, with a
                // height ranging from one to fifteen pixels.
                var unsetPixels: u8 = 1;

                const sprite_width = 8;
                const sprite_height = instruction.third_nibble();

                const x_pos = self.registers[instruction.first_nibble()];
                const y_pos = self.registers[instruction.second_nibble()];

                var row: u8 = 0;

                while (row < sprite_height) : (row += 1) {
                    var sprite = self.mem[self.index_reg + row];

                    var col: u8 = 0;

                    while (col < sprite_width) : (col += 1) {
                        const value = (sprite & 0x80) > 0;
                        unsetPixels = @boolToInt(self.screenbuffer.setPixel(x_pos + col, y_pos + row, value));

                        // Shift the sprite left 1. This will move the next
                        // next col/bit of the sprite into the first position.
                        // Ex. 10010000 << 1 will become 0010000
                        sprite = sprite << 1;
                    }
                }

                self.registers[0xF] = unsetPixels;
            },
            else => {
                if (instruction.data != 0) {
                    std.debug.print("unhandled instruction 0x{X}\n", .{instruction.data});
                }
            },
        }
    }
};

/// All 35 instructions in the CHIP-8 instruction set.  NNN refers to a
/// hexadecial memory address.  NN refers to a hexadecimal byte.  N refers to a
/// hexadecimal nibble.  X and Y refer to registers.
const InstructionType = enum {
    // 0NNN - Execute machine language subroutine at address NNN
    Sys,
    // 00E0 - Clear the screen
    Clear,
    // 00EE - Return from a subroutine
    Return,
    // 1NNN - Jump to address NNN
    Jump,
    // 2NNN - Execute subroutine starting at address NNN
    Call,
    // 3XNN - Skip the following instruction if the value of register VX equals NN
    SkipIfEqual,
    // 4XNN - Skip the following instruction if the value of register VX is not equal
    // to NN
    SkipIfNotEqual,
    // 5XY0 - Skip the following instruction if the value of register VX is equal to
    // the value of register VY
    SkipIfRegistersEqual,
    // 6XNN - Store number NN in register VX
    StoreImmediate,
    // 7XNN - Add the value NN to register VX
    AddImmediate,
    // 8XY0 - Store the value of register VY in register VX
    StoreRegister,
    // 8XY1 - Set VX to VX OR VY
    Or,
    // 8XY2 - Set VX to VX AND VY
    And,
    // 8XY3 - Set VX to VX XOR VY
    Xor,
    // 8XY4 - Add the value of register VY to register VX; set VF to 01 if a carry
    // occurs.  Set VF to 00 if a carry does not occur.
    AddRegisters,
    // 8XY5 - Subtract the value of register VY from register VX; Set VF to 00 if a
    // borrow occurs; Set VF to 01 if a borrow does not occur.
    SubstractRegistersImmutably,
    // 8XY6 - Store the value of register VY shifted right one bit in register
    // VX; Set register VF to the least significant bit prior to the shift; VY
    // is unchanged.
    ShiftRight,
    // 8XY7 - Set register VX to the value of VY minus VX.  Set VF to 00 if a
    // borrow occurs.  Set VF to 01 if a borrow does not occur.
    SubstractRegisters,
    // 8XYE - Store the value of register VY shifted left one bit in register
    // VX.  Set register VF to the most significant bit prior to the shirt.  VY
    // is unchanged.0
    ShiftLeft,
    // 9XY0 - Skip the following instruction if the value of register VX is not
    // equal to the value of register VY.
    SkipIfRegistersNotEqual,
    // ANNN - Store memory address NNN in register I
    StoreAddressInIndex,
    // BNNN - Jump to address NNN + V0
    JumpToAddressPlus,
    // CXNN - Set VX to a random number with a mask of NN
    SetRandomMask,
    // DXYN - Draw a sprite at position VX, VY with N bytes of sprite data
    // starting at the address stored in I.  Set VF to 01 if any set pixels are
    // changed to unset, and 00 otherwise.
    DrawSprite,
    // EX9E - Skip the following instruction if the key corresponding to the
    // hext value currently stored in reigster VX is pressed.
    SkipIfPressed,
    // EXA1 - Skip the following instruction if the key corresponding to the
    // hex value currently stored in register VX is not pressed.
    SkipIfNotPressed,
    // FX07 - Store the current value of the delay timer in register VX.
    StoreDelay,
    // FX0A - Wait for a keypress and store the result in the register VX
    WaitForKeypress,
    // FX15 - Set the delay timer to the value of register VX.
    SetDelayTimer,
    // FX18 - Set the sound timer to the value of register VX.
    SetSoundTimer,
    // FX1E - Add the value stored in register VX to register I.
    AddIndexRegister,
    // FX29 - Set I to the memory address of the sprite data corresponding to
    // the hexadecimal digit stored in register VX.
    SetIndexToSprite,
    // FX33 - Store the binary-coded decimal equivalent of the value stored in
    // register VX at address I, I + 1, and I + 2
    StoreBinaryDecimal,
    // FX55 - Store the values of registers V0 to VX inclusive in memory
    // starting at address I.  I is set to I + X + 1 after operation.
    StoreAllRegisters,
    // FX65 - Fill registers V0 to VX inclusive with the values stored in
    // memory starting address I.  I is set to I + X + 1 after operation.
    FillRegistersFromMem,
    TODO,
};

const ParsedInstruction = struct {
    type: InstructionType,
    // QUESTION(Michael): does endianness matter if all I am doing is casting a byte
    // array to a u16, not as in "a 16 bit number" but literally just as "16
    // bits of data in the same order that they were in in the original binary?
    // i.e. I don't give a fuck what the most significant byte is in the
    // architecture of my CPU, just that the resulting u16 reflects the bit
    // order in the original binary program.
    data: u16,

    const Self = @This();

    pub fn first_nibble(self: *const Self) u4 {
        return @intCast(u4, (self.data >> 8) & 0x0F);
    }

    pub fn second_nibble(self: *const Self) u4 {
        return @intCast(u4, (self.data >> 4) & 0x00F);
    }

    pub fn third_nibble(self: *const Self) u4 {
        return @intCast(u4, self.data & 0x000F);
    }
};

pub fn parseInstruction(buffer: []u8) ParsedInstruction {
    // FIXME(Michael): determine the most ziggy way to deal with this whole
    // "raw instruction as slice into memory buffer" thing.
    // Note that we have to handle endianness by reversing buffer 1 and buffer
    // 0 on my ARM64 system.
    const data = @bitCast(u16, [2]u8{ buffer[1], buffer[0] });
    // the value of the first nibble determines the instruction type in chip8
    return switch (buffer[0] >> 4) {
        0 => {
            if (data == 0x00EE) {
                return .{ .type = InstructionType.Return, .data = data };
            } else if (data == 0x00E0) {
                return .{ .type = InstructionType.Clear, .data = data };
            }
            return .{ .type = InstructionType.Sys, .data = data };
        },
        1 => .{ .type = InstructionType.Jump, .data = data },
        6 => .{ .type = InstructionType.StoreImmediate, .data = data },
        7 => .{ .type = InstructionType.AddImmediate, .data = data },
        0xA => .{ .type = InstructionType.StoreAddressInIndex, .data = data },
        0xD => .{ .type = InstructionType.DrawSprite, .data = data },
        else => .{ .type = InstructionType.TODO, .data = data },
    };
}
