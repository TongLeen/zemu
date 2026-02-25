pub fn trap(cpu: anytype, cause: TrapCause) void {
    std.debug.print(color.info(.{
        "{x:0>8}:\tTrap caused by '",
        color.dye("{s}", .{ .color = .blue, .effect = .bold }),
        "''.\n",
    }), .{ cpu.pc, @tagName(cause) });

    const cause_code: u32 = @intFromEnum(cause);
    const is_interrupt = (cause_code & 0x80000000) != 0;
    // update mcause
    cpu.csr.mcause = cause_code;
    // update mepc
    cpu.csr.mepc = cpu.pc;
    // update mtval
    cpu.csr.mtval = switch (cause) {
        .illegal_instruction => switch (cpu.fetcher.this_inst) {
            .inst, .cinst => |v| v,
        },
        .breakpoint => cpu.pc,
        else => 0,
    };
    // update mstatus
    const mstatus = &cpu.csr.mstatus;
    switch (cpu.mode) {
        .M, .U => {
            mstatus.mpp = @intFromEnum(cpu.mode);
            mstatus.mpie = mstatus.mie;
            mstatus.mie = 0;
        },

        else => unreachable,
    }
    // jump to mtvec
    const mtvec_mode: u2 = @truncate(cpu.csr.mtvec);
    if (is_interrupt) {
        switch (mtvec_mode) {
            0 => {
                cpu.pc = (cpu.csr.mtvec);
            },
            1 => {
                cpu.pc = (cpu.csr.mtvec +% 4 * (cause_code & 0x7fff_ffff));
            },
            else => unreachable,
        }
    } else {
        cpu.pc = (cpu.csr.mtvec);
    }
}

const TrapCause = enum(u32) {
    // Interrupt
    supervisor_software_interrupt = 0x80000001,
    machine_software_interrupt = 0x80000003,
    supervisor_timer_interrupt = 0x80000005,
    machine_timer_interrupt = 0x80000007,
    supervisor_external_interrupt = 0x80000009,
    machine_external_interrupt = 0x800000b,
    // Exception
    instruction_address_misaligned = 0,
    instruction_access_fault,
    illegal_instruction,
    breakpoint,
    load_address_misaligned,
    load_access_fault,
    store_address_misaligned,
    store_access_fault,
    environment_call_from_umode,
    environment_call_from_smode,
    environment_call_from_hmode,
    environment_call_from_mmode,
    instruction_page_fault,
    load_page_fault,
    store_page_fault = 15,
};

const std = @import("std");
const color = @import("misc").color;
