this_inst: Inst,
c_inst_buffer: u16,
c_inst_addr_buffer: ?u32 = null,

pub fn fetch(self: *Self, cpu: *const Cpu) Memory.AccessError!Inst {
    const this_inst_addr = cpu.pc;
    if (this_inst_addr & 0b1 == 1) {
        unreachable;
    }
    const is_align4_addr = (this_inst_addr & 0b11) == 0;

    if (is_align4_addr) {
        const raw_inst = try cpu.mem.readWord(this_inst_addr & ~@as(u32, 0b11));
        if (raw_inst & 0b11 == 0b11) {
            self.c_inst_addr_buffer = null;
            return .{ .inst = raw_inst };
        } else {
            self.c_inst_addr_buffer = this_inst_addr + 2;
            self.c_inst_buffer = @truncate(raw_inst >> 16);
            return .{ .cinst = @truncate(raw_inst) };
        }
    }

    // buffer is invaild
    if (self.c_inst_addr_buffer == null or self.c_inst_addr_buffer.? != this_inst_addr) {
        const raw_inst = try cpu.mem.readWord(this_inst_addr & ~@as(u32, 0b11));
        self.c_inst_buffer = @truncate(raw_inst >> 16);
        self.c_inst_addr_buffer = this_inst_addr;
    }

    if (self.c_inst_buffer & 0b11 != 0b11) {
        self.c_inst_addr_buffer = null;
        return .{ .cinst = self.c_inst_buffer };
    } else {
        const next_word_addr: u32 = (this_inst_addr +% 4) & (~@as(u32, 0b11));
        const next_word: u32 = try cpu.mem.readWord(next_word_addr);
        const raw_inst_high: u16 = @truncate(next_word);
        const i = @as(u32, raw_inst_high) << 16 | self.c_inst_buffer;
        self.c_inst_buffer = @truncate(next_word >> 16);
        self.c_inst_addr_buffer = next_word_addr + 2;
        return .{ .inst = i };
    }
}

pub const Inst = union(enum) {
    inst: u32,
    cinst: u16,
};

const Self = @This();

const core = @import("../root.zig");
const Cpu = core.Cpu;
const Memory = core.Memory;
