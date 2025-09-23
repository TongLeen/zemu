const entry = 0x8000_0000;

regs: Reg,
pc: u32,
mem: Memory,
csr: Csr,
mode: Mode,
fetcher: Fetcher,

pub fn init(allocator: Allocator) Allocator.Error!Self {
    return .{
        .regs = undefined,
        .pc = undefined,
        .mem = try Memory.init(allocator),
        .csr = undefined,
        .mode = undefined,
        .fetcher = .{ .c_inst_buffer = 0, .c_inst_addr_buffer = null, .this_inst = .{ .inst = 0 } },
    };
}

pub fn deinit(self: *Self) void {
    self.mem.deinit();
}

pub fn start(self: *Self) Error!void {
    self.restart();
    while (true) {
        try self.tick(false);
    }
}

pub fn restart(self: *Self) void {
    self.pc = entry;
    self.regs.write(0, 0);
    self.mode = .M;
}

pub fn tick(self: *Self, show_inst: bool) Error!void {
    const inst = self.fetcher.fetch(self) catch |e| {
        switch (e) {
            Memory.AccessError.AddrNotAligned => Executor.trap(self, .instruction_address_misaligned),
            Memory.AccessError.AddrOutOfRange => Executor.trap(self, .instruction_access_fault),
            else => unreachable,
        }
        return;
    };

    if (inst == .cinst) {
        std.debug.print(color.warn(.{"C Extension have not be test completely.\n"}), .{});
    }
    const operation = switch (inst) {
        .inst => |v| Decoder.decode(v),
        .cinst => |v| Decoder.decodeCompressed(v),
    } catch |e| {
        switch (e) {
            Decoder.Error.CodeIncorrect => Executor.trap(self, .illegal_instruction),
        }
        return;
    };

    if (show_inst) {
        std.debug.print(color.info(.{"{x:0>8}:\t{f}\n"}), .{ self.pc, operation });
    }

    return @errorCast(Executor.exec(self, operation, inst == .cinst));
}

pub inline fn addMemoryBlock(
    self: *Self,
    memory_block: Memory.MemoryBlock,
) !void {
    return self.mem.addMemoryBlock(memory_block);
}

pub const Error = error{Ebreak};

pub inline fn readReg(self: *const Self, reg: u5) u32 {
    return self.regs.read(reg);
}
pub inline fn writeReg(self: *Self, reg: u5, value: u32) void {
    return self.regs.write(reg, value);
}

const Self = @This();
const Mode = enum(u2) { U, S, H, M };

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const core = @import("root.zig");
const Reg = core.Reg;
const Csr = core.Csr;
const Fetcher = core.Fetcher;
const Decoder = core.Decoder;
const Executor = core.Executor;
const Memory = core.Memory;

const color = @import("misc").color;
