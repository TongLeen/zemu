this_inst: Inst,
c_inst_buffer: u16,
c_inst_addr_buffer: ?u32,

pub fn fetch(self: *Self, cpu: *Cpu) Memory.AccessError!Inst {
    if (self.c_inst_addr_buffer == cpu.pc) {
        self.this_inst = .{ .cinst = self.c_inst_buffer };
    }
    const is_align4_addr = (cpu.pc & 0b11) == 0;
    const raw_inst = try cpu.mem.readWord(cpu.pc & ~@as(u32, 0b11));

    if (is_align4_addr) {
        if (raw_inst & 0b11 == 0b11) {
            self.this_inst = .{ .inst = raw_inst };
        } else {
            self.c_inst_buffer = @truncate(raw_inst >> 16);
            self.c_inst_addr_buffer = cpu.pc + 2;
            self.this_inst = .{ .cinst = @truncate(raw_inst) };
        }
    } else {
        self.this_inst = .{ .cinst = @truncate(raw_inst >> 16) };
    }
    return self.this_inst;
}

pub const Inst = union(enum) {
    inst: u32,
    cinst: u16,
};

const Self = @This();

const core = @import("../root.zig");
const Cpu = core.Cpu;
const Memory = core.Memory;
