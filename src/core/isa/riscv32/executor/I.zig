pub fn exec(cpu: anytype, operation: Operation, is_c_inst: bool) Error!void {
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
                    cpu.incPc(if (is_c_inst) 2 else 4);
                    return Error.Ebreak;
                },
            }
        },
        .csr_I => {
            return exec_csr(cpu, operation);
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
                cpu.incPc(bias_by_byte);
                return;
            }
        },
        .jp_J => |op| {
            assert(op.op == .JAL);
            cpu.writeReg(op.rd, cpu.pc + @as(u32, if (is_c_inst) 2 else 4));

            const imm_extended: i32 = @as(i20, @bitCast(op.imm));
            const bias_by_byte: i32 = imm_extended << 1;
            cpu.incPc(bias_by_byte);
            return;
        },
        .jp_I => |op| {
            assert(op.op == .JALR);
            const rs1v = cpu.readReg(op.rs1);
            const imm_extended: i32 = @as(i12, @bitCast(op.imm));
            cpu.writeReg(op.rd, cpu.pc + @as(u32, if (is_c_inst) 2 else 4));
            cpu.pc = ((rs1v +% @as(u32, @bitCast(imm_extended))) & 0xffff_fffe);
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
    cpu.incPc(if (is_c_inst) 2 else 4);
}

fn exec_csr(cpu: anytype, operation: Operation) Error!void {
    assert(operation == .csr_I);
    const op = operation.csr_I;
    const rs1_v = cpu.readReg(op.rs1);
    switch (op.op) {
        .CSRRW,
        .CSRRWI,
        => |v| {
            if (op.rd != 0) {
                const csr_v = cpu.csr.read(
                    op.csr,
                    @intFromEnum(cpu.mode),
                ) catch |e| {
                    std.debug.print("CSRRW failed: {s}.", .{@errorName(e)});
                    return trap(cpu, .illegal_instruction);
                };
                cpu.writeReg(op.rd, csr_v);
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
                std.debug.print("CSRRW failed: {s}.", .{@errorName(e)});
                return trap(cpu, .illegal_instruction);
            };
        },
        .CSRRS,
        .CSRRSI,
        => |v| {
            const csr_v = cpu.csr.read(
                op.csr,
                @intFromEnum(cpu.mode),
            ) catch |e| {
                std.debug.print("CSRRS failed: {s}.", .{@errorName(e)});
                return trap(cpu, .illegal_instruction);
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
                    std.debug.print("CSRRS failed: {s}.", .{@errorName(e)});
                    return trap(cpu, .illegal_instruction);
                };
            }
            cpu.writeReg(op.rd, csr_v);
        },
        .CSRRC,
        .CSRRCI,
        => |v| {
            const csr_v = cpu.csr.read(
                op.csr,
                @intFromEnum(cpu.mode),
            ) catch |e| {
                std.debug.print("CSRRC failed: {s}.", .{@errorName(e)});
                return trap(cpu, .illegal_instruction);
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
                    std.debug.print("CSRRC failed: {s}.", .{@errorName(e)});
                    return trap(cpu, .illegal_instruction);
                };
            }
            cpu.writeReg(op.rd, csr_v);
        },
    }
}

pub const Error = error{Ebreak};

const std = @import("std");
const assert = std.debug.assert;

const decoder = @import("../decoder.zig");
const Operation = decoder.I.Operation;
const trap = @import("trap.zig").trap;

const core = @import("core");
const Csr = core.Csr;
const Memory = core.Memory;
const MemAccessError = Memory.AccessError;

// const Cpu = @import("../../riscv32.zig").Riscv32(.{}, 0);

const color = @import("misc").color;
