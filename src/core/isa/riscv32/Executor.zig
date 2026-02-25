pub fn exec(cpu: anytype, operation: Operation, is_c_inst: bool) Error!void {
    switch (operation) {
        .I => |op| {
            return @errorCast(I.exec(cpu, op, is_c_inst));
        },
    }
}

pub const trap = @import("executor/trap.zig").trap;

// const Cpu = @import("../riscv32.zig").Riscv32(.{}, 0);
const Operation = @import("decoder.zig").Operation;
pub const Error = error{Ebreak};

const I = @import("executor/I.zig");
