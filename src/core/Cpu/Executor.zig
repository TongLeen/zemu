pub fn exec(cpu: *Cpu, operation: Operation, is_c_inst: bool) Error!void {
    switch (operation) {
        .al_R => |op| {
            const rs1v = cpu.readReg(op.rs1);
            const rs2v = cpu.readReg(op.rs2);
            cpu.writeReg(
                op.rd,
                switch (op.op) {
                    .ADD => rs1v +% rs2v,
                    .SUB => rs1v -% rs2v,
                    .SLL => rs1v << @as(u5, @truncate(rs2v)),
                    .SLT => @intFromBool(@as(i32, @bitCast(rs1v)) < @as(i32, @bitCast(rs2v))),
                    .SLTU => @intFromBool(rs1v < rs2v),
                    .XOR => rs1v ^ rs2v,
                    .SRL => rs1v >> @as(u5, @truncate(rs2v)),
                    .SRA => @bitCast(@as(i32, @bitCast(rs1v)) >> @as(u5, @truncate(rs2v))),
                    .OR => rs1v | rs2v,
                    .AND => rs1v & rs2v,
                },
            );
        },
        .al_I => |op| {
            const rs1v = cpu.readReg(op.rs1);
            const imm: i12 = @bitCast(op.imm);
            const imm_extended: i32 = imm;
            const imm_extended_u: u32 = @bitCast(imm_extended);
            cpu.writeReg(
                op.rd,
                switch (op.op) {
                    .ADDI => rs1v +% imm_extended_u,
                    .SLTI => blk: {
                        const v1: i32 = @bitCast(rs1v);
                        break :blk @intFromBool(v1 < imm_extended);
                    },
                    .SLTIU => @intFromBool(rs1v < imm_extended_u),
                    .XORI => rs1v ^ imm_extended_u,
                    .ORI => rs1v | imm_extended_u,
                    .ANDI => rs1v & imm_extended_u,
                    .SLLI => rs1v << @as(u5, @truncate(imm_extended_u)),
                    .SRLI => rs1v >> @as(u5, @truncate(imm_extended_u)),
                    .SRAI => @bitCast(@as(i32, @bitCast(rs1v)) >> @as(u5, @truncate(imm_extended_u))),
                },
            );
        },
        .env_I => |op| {
            switch (op.op) {
                .ECALL => {
                    trap(cpu, switch (cpu.mode) {
                        .U => .environment_call_from_umode,
                        .S => .environment_call_from_smode,
                        .H => .environment_call_from_hmode,
                        .M => .environment_call_from_mmode,
                    });
                    cpu.mode = .M;
                    return;
                },
                .EBREAK => {
                    std.debug.print(
                        color.info(.{
                            "{x:0>8}:\tBreakpoint. ",
                            color.dye(
                                "Code:{d}\n",
                                .{ .color = .blue, .effect = .bold },
                            ),
                        }),
                        .{ cpu.pc, cpu.readReg(17) },
                    );
                    cpu.pc += 4;
                    return Error.Ebreak;
                },
                .MRET => {
                    const mepc = cpu.csr.read(
                        @intFromEnum(Csr.Csr.mepc),
                        @intFromEnum(cpu.mode),
                    ) catch unreachable;
                    std.debug.print(
                        color.info(.{"{x:0>8}:\tMret. Mepc={x:0>8}\n"}),
                        .{ cpu.pc, mepc },
                    );
                    cpu.pc = mepc;
                    cpu.csr.mstatus.mie = cpu.csr.mstatus.mpie;
                    cpu.mode = @enumFromInt(cpu.csr.mstatus.mpp);
                    return;
                },
            }
        },
        .csr_I => |op| {
            var csr_v: u32 = undefined;
            const rs1_v = cpu.readReg(op.rs1);
            (swt: switch (op.op) {
                .CSRRW,
                .CSRRWI,
                => |v| {
                    if (op.rd != 0) {
                        csr_v = cpu.csr.read(
                            op.csr,
                            @intFromEnum(cpu.mode),
                        ) catch |e| {
                            break :swt e;
                        };
                    }
                    cpu.csr.write(
                        op.csr,
                        switch (v) {
                            .CSRRW => rs1_v,
                            .CSRRWI => op.rs1,
                            else => unreachable,
                        },
                        @intFromEnum(cpu.mode),
                    ) catch |e| {
                        break :swt e;
                    };
                    cpu.writeReg(op.rd, csr_v);
                },
                .CSRRS,
                .CSRRSI,
                => |v| {
                    csr_v = cpu.csr.read(
                        op.csr,
                        @intFromEnum(cpu.mode),
                    ) catch |e| {
                        break :swt e;
                    };

                    if (op.rs1 != 0) {
                        cpu.csr.write(
                            op.csr,
                            csr_v | @as(u32, switch (v) {
                                .CSRRS => rs1_v,
                                .CSRRSI => op.rs1,
                                else => unreachable,
                            }),
                            @intFromEnum(cpu.mode),
                        ) catch |e| {
                            break :swt e;
                        };
                    }
                    cpu.writeReg(op.rd, csr_v);
                },
                .CSRRC,
                .CSRRCI,
                => |v| {
                    csr_v = cpu.csr.read(
                        op.csr,
                        @intFromEnum(cpu.mode),
                    ) catch |e| {
                        break :swt e;
                    };

                    if (op.rs1 != 0) {
                        cpu.csr.write(
                            op.csr,
                            csr_v & ~@as(u32, switch (v) {
                                .CSRRC => rs1_v,
                                .CSRRCI => op.rs1,
                                else => unreachable,
                            }),
                            @intFromEnum(cpu.mode),
                        ) catch |e| {
                            break :swt e;
                        };
                    }
                    cpu.writeReg(op.rd, csr_v);
                },
            }) catch |e| switch (e) {
                Csr.Error.NotImplemented,
                Csr.Error.PermissionDenied,
                => {
                    trap(cpu, .illegal_instruction);
                    return;
                },
            };
        },
        .br_B => |op| {
            const rs1v = cpu.readReg(op.rs1);
            const rs2v = cpu.readReg(op.rs2);
            const toBrench: bool = switch (op.op) {
                .BEQ => rs1v == rs2v,
                .BNE => rs1v != rs2v,
                .BLT => blk: {
                    const v1: i32 = @bitCast(rs1v);
                    const v2: i32 = @bitCast(rs2v);
                    break :blk v1 < v2;
                },
                .BGE => blk: {
                    const v1: i32 = @bitCast(rs1v);
                    const v2: i32 = @bitCast(rs2v);
                    break :blk v1 >= v2;
                },
                .BLTU => rs1v < rs2v,
                .BGEU => rs1v >= rs2v,
            };
            if (toBrench) {
                const imm_extended: i32 = @as(i12, @bitCast(op.imm));
                const bias_by_byte: i32 = imm_extended << 1;
                cpu.pc +%= @as(u32, @bitCast(bias_by_byte));
                return;
            }
        },
        .jp_J => |op| {
            assert(op.op == .JAL);
            cpu.writeReg(op.rd, cpu.pc + @as(u32, if (is_c_inst) 2 else 4));

            const imm_extended: i32 = @as(i20, @bitCast(op.imm));
            const bias_by_byte: i32 = imm_extended << 1;
            cpu.pc +%= @as(u32, @bitCast(bias_by_byte));
            return;
        },
        .jp_I => |op| {
            assert(op.op == .JALR);
            cpu.writeReg(op.rd, cpu.pc + @as(u32, if (is_c_inst) 2 else 4));

            const rs1v = cpu.readReg(op.rs1);
            const imm_extended: i32 = @as(i12, @bitCast(op.imm));
            const bias_by_byte: i32 = imm_extended << 1;
            cpu.pc = (rs1v +% @as(u32, @bitCast(bias_by_byte))) & 0xffff_fffe;
            return;
        },
        .lu_U => |op| {
            assert(op.op == .LUI);
            const imm: u32 = @as(u32, op.imm) << 12;
            cpu.writeReg(op.rd, imm);
        },
        .pc_U => |op| {
            assert(op.op == .AUIPC);
            const imm: u32 = @as(u32, op.imm) << 12;
            const result: u32 = cpu.pc +% imm;
            cpu.writeReg(op.rd, result);
        },
        .st_S => |op| {
            const rs1v = cpu.readReg(op.rs1);
            const rs2v = cpu.readReg(op.rs2);
            const imm_extended: i32 = @as(i12, @bitCast(op.imm));

            const addr = rs1v +% @as(u32, @bitCast(imm_extended));

            (switch (op.op) {
                .SB => cpu.mem.writeByte(addr, @truncate(rs2v)),
                .SH => cpu.mem.writeHalfWord(addr, @truncate(rs2v)),
                .SW => cpu.mem.writeWord(addr, @truncate(rs2v)),
            }) catch |e| {
                switch (e) {
                    MemAccessError.AddrNotAligned,
                    => trap(cpu, .store_address_misaligned),
                    MemAccessError.AddrOutOfRange,
                    MemAccessError.NoWritePermission,
                    => trap(cpu, .store_access_fault),
                }
                return;
            };
        },
        .ld_I => |op| {
            const rs1v = cpu.readReg(op.rs1);
            const imm_extended: i32 = @as(i12, @bitCast(op.imm));
            const addr = rs1v +% @as(u32, @bitCast(imm_extended));
            (swt: switch (op.op) {
                .LB, .LBU => {
                    const v = cpu.mem.readByte(addr) catch |e| {
                        break :swt e;
                    };
                    if (op.op == .LB) {
                        const v_signed: i32 = @as(i8, @bitCast(v));
                        cpu.writeReg(op.rd, @bitCast(v_signed));
                    } else {
                        cpu.writeReg(op.rd, v);
                    }
                },
                .LH, .LHU => {
                    const v = cpu.mem.readHalfWord(addr) catch |e| {
                        break :swt e;
                    };
                    if (op.op == .LH) {
                        const v_signed: i32 = @as(i16, @bitCast(v));
                        cpu.writeReg(op.rd, @bitCast(v_signed));
                    } else {
                        cpu.writeReg(op.rd, v);
                    }
                },
                .LW => {
                    cpu.writeReg(op.rd, cpu.mem.readWord(addr) catch |e| {
                        break :swt e;
                    });
                },
            }) catch |e| {
                switch (e) {
                    MemAccessError.AddrNotAligned => trap(cpu, .load_address_misaligned),
                    MemAccessError.AddrOutOfRange => trap(cpu, .load_access_fault),
                    else => unreachable,
                }
                return;
            };
        },
    }
    cpu.pc += if (is_c_inst) 2 else 4;
}

pub fn trap(cpu: *Cpu, cause: TrapCause) void {
    std.debug.print(color.info(.{
        "0x{x:0>8}:\tTrap caused by '",
        color.dye("{s}", .{ .color = .blue, .effect = .bold }),
        "''.\n",
    }), .{ cpu.pc, @tagName(cause) });
    if (cause == .breakpoint) {
        std.debug.print(color.warn(.{"$pc is the address of next instruction, instead of ebreak.\n"}), .{});
    }
    const cause_code: u32 = @intFromEnum(cause);
    const is_interrupt = (cause_code & 0x80000000) != 0;
    // update mcause
    cpu.csr.mcause = cause_code;
    // update mepc
    cpu.csr.mepc = cpu.pc;
    // update mtval
    cpu.csr.mtval = switch (cause) {
        .illegal_instruction => switch (cpu.fetcher.this_inst) {
            .inst => |v| v,
            .cinst => |v| v,
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
                cpu.pc = cpu.csr.mtvec;
            },
            1 => {
                cpu.pc = cpu.csr.mtvec +% 4 * (cause_code & 0x7fff_ffff);
            },
            else => unreachable,
        }
    } else {
        cpu.pc = cpu.csr.mtvec;
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

pub const Error = error{Ebreak};

const std = @import("std");
const assert = std.debug.assert;

const core = @import("../root.zig");
const Cpu = core.Cpu;
const Operation = core.Decoder.Operation;
const Csr = core.Csr;
const MemAccessError = core.Memory.AccessError;

const color = @import("misc").color;
