pub fn decode(cinst: u16) Error!Operation {
    const op: u2 = @truncate(cinst);
    return switch (op) {
        0b00 => decode_Op00(cinst),
        0b01 => decode_Op01(cinst),
        0b10 => decode_Op10(cinst),
        0b11 => {
            @panic("C extension got opcode 2'b11.");
        },
    };
}

fn decode_Op00(cinst: u16) Error!Operation {
    if (cinst == 0) {
        return Error.CodeIllegal;
    }

    const funct3: u3 = @truncate(cinst >> 13);
    switch (funct3) {
        0b000 => { // c.addi4spn
            const c: code.CIW = @bitCast(cinst);
            if (c.imm == 0) {
                return Error.CodeReserved;
            }

            return .{ .al_I = .{
                .op = .ADDI,
                .rd = @as(u5, c.rd_) | 0b01000,
                .rs1 = 2,
                .imm = blk: {
                    const b5_4 = bits.extract(.{ 12, 11 }, cinst);
                    const b9_6 = bits.extract(.{ 10, 7 }, cinst);
                    const b2 = bits.extract(.{ 6, 6 }, cinst);
                    const b3 = bits.extract(.{ 5, 5 }, cinst);
                    break :blk bits.extendUnsigned(
                        u12,
                        bits.concat(.{ b9_6, b5_4, b3, b2 }),
                    ) << 2;
                },
            } };
        },
        0b001 => { // f.fld
            return Error.CodeNotFound;
        },
        0b010 => { // c.lw
            const c: code.CL = @bitCast(cinst);

            return .{ .ld_I = .{
                .op = .LW,
                .rd = @as(u5, c.rd_) | 0b01000,
                .rs1 = @as(u5, c.rs1_) | 0b01000,
                .imm = blk: {
                    const b6 = bits.extract(.{ 5, 5 }, cinst);
                    const b5_3 = bits.extract(.{ 12, 10 }, cinst);
                    const b2 = bits.extract(.{ 6, 6 }, cinst);
                    break :blk bits.extendUnsigned(
                        u12,
                        bits.concat(.{ b6, b5_3, b2 }),
                    ) << 2;
                },
            } };
        },
        0b011 => { // c.flw
            return Error.CodeNotFound;
        },
        0b100 => {
            return Error.CodeReserved;
        },
        0b101 => { // c.fsd
            return Error.CodeNotFound;
        },
        0b110 => { // c.sw
            const c: code.CS = @bitCast(cinst);
            return .{ .st_S = .{
                .op = .SW,
                .rs1 = @as(u5, c.rs1_) | 0b01000,
                .rs2 = @as(u5, c.rs2_) | 0b01000,
                .imm = blk: {
                    const b6 = bits.extract(.{ 5, 5 }, cinst);
                    const b5_3 = bits.extract(.{ 12, 10 }, cinst);
                    const b2 = bits.extract(.{ 6, 6 }, cinst);
                    break :blk bits.extendUnsigned(
                        u12,
                        bits.concat(.{ b6, b5_3, b2 }),
                    ) << 2;
                },
            } };
        },
        0b111 => { // c.fsw
            return Error.CodeNotFound;
        },
    }
}

fn decode_Op01(cinst: u16) Error!Operation {
    const funct3: u3 = @truncate(cinst >> 13);
    switch (funct3) {
        0b000 => { // c.addi
            const c: code.CI = @bitCast(cinst);
            return .{ .al_I = .{
                .op = .ADDI,
                .rd = c.rd_rs1,
                .rs1 = c.rd_rs1,
                .imm = blk: {
                    const b5: u1 = bits.extract(.{ 12, 12 }, cinst);
                    const b4_0: u5 = bits.extract(.{ 6, 2 }, cinst);
                    break :blk bits.extendSigned(
                        u12,
                        bits.concat(.{ b5, b4_0 }),
                    );
                },
            } };
        },
        0b001, 0b101 => { // c.jal c.j
            const c: code.CJ = @bitCast(cinst);
            return .{ .jp_J = .{
                .op = .JAL,
                .rd = switch (c.funct3) {
                    0b101 => 0,
                    0b001 => 1,
                    else => unreachable,
                },
                .imm = blk: {
                    const b11 = bits.extract(.{ 12, 12 }, cinst);
                    const b4 = bits.extract(.{ 11, 11 }, cinst);
                    const b9_8 = bits.extract(.{ 10, 9 }, cinst);
                    const b10 = bits.extract(.{ 8, 8 }, cinst);
                    const b6 = bits.extract(.{ 7, 7 }, cinst);
                    const b7 = bits.extract(.{ 6, 6 }, cinst);
                    const b3_1 = bits.extract(.{ 5, 3 }, cinst);
                    const b5 = bits.extract(.{ 2, 2 }, cinst);
                    const v = bits.extendSigned(
                        u20,
                        bits.concat(.{ b11, b10, b9_8, b7, b6, b5, b4, b3_1 }),
                    );
                    break :blk v;
                },
            } };
        },
        0b010 => { // c.li
            const c: code.CI = @bitCast(cinst);
            return .{ .al_I = .{
                .op = .ADDI,
                .rd = c.rd_rs1,
                .rs1 = 0,
                .imm = blk: {
                    const b5 = bits.extract(.{ 11, 11 }, cinst);
                    const b4_0: u5 = bits.extract(.{ 6, 2 }, cinst);
                    break :blk bits.extendSigned(
                        u12,
                        bits.concat(.{ b5, b4_0 }),
                    );
                },
            } };
        },
        0b011 => { // c.lui c.addi16sp
            const c: code.CI = @bitCast(cinst);
            if (c.imm0 == 0 and c.imm1 == 0) {
                return Error.CodeReserved;
            }

            return if (c.rd_rs1 == 2) .{ .al_I = .{
                .op = .ADDI,
                .rd = 2,
                .rs1 = 2,
                .imm = blk: {
                    const b9: u1 = bits.extract(.{ 12, 12 }, cinst);
                    const b8_7: u2 = bits.extract(.{ 4, 3 }, cinst);
                    const b6: u1 = bits.extract(.{ 5, 5 }, cinst);
                    const b5: u1 = bits.extract(.{ 2, 2 }, cinst);
                    const b4: u1 = bits.extract(.{ 6, 6 }, cinst);
                    break :blk bits.extendSigned(
                        u12,
                        bits.concat(.{ b9, b8_7, b6, b5, b4 }),
                    ) << 4;
                },
            } } else .{ .lu_U = .{
                .op = .LUI,
                .rd = c.rd_rs1,
                .imm = blk: {
                    const b5: u1 = bits.extract(.{ 11, 11 }, cinst);
                    const b4_0: u5 = bits.extract(.{ 6, 2 }, cinst);
                    const uv = bits.concat(.{ b5, b4_0 });
                    break :blk bits.extendSigned(u20, uv);
                },
            } };
        },
        0b100 => { // c.srli c.srai c.and c.or c.xor c.sub
            const c: code.CB = @bitCast(cinst);
            const shift_funct2: u2 = @truncate(c.offset1);
            const is_shift_code = shift_funct2 != 0b11;

            if (is_shift_code) {
                return .{
                    .al_I = .{
                        .op = switch (shift_funct2) {
                            0b00 => .SRLI,
                            0b01 => .SRAI,
                            0b10 => .ANDI,
                            else => unreachable,
                        },
                        .rd = @as(u5, c.rs1_) | 0b01000,
                        .rs1 = @as(u5, c.rs1_) | 0b01000,
                        .imm = blk: {
                            const b5: u1 = @truncate(c.offset1);
                            if (shift_funct2 != 0b10 and b5 == 1) {
                                return Error.CodeNotFound; // custum inst
                            }
                            const b4_0 = c.offset0;
                            break :blk bits.extendSigned(
                                u12,
                                bits.concat(.{ b5, b4_0 }),
                            );
                        },
                    },
                };
            }
            // logic
            if (bits.extract(.{ 12, 12 }, cinst) != 0) {
                return Error.CodeReserved;
            }

            const lc: code.CA = @bitCast(cinst);
            assert(lc.funct6 == 0b100011);

            return .{ .al_R = .{
                .op = switch (lc.funct2) {
                    0b00 => .SUB,
                    0b01 => .XOR,
                    0b10 => .OR,
                    0b11 => .AND,
                },
                .rd = @as(u5, lc.rd_rs1_) | 0b01000,
                .rs1 = @as(u5, lc.rd_rs1_) | 0b01000,
                .rs2 = @as(u5, lc.rs2_) | 0b01000,
            } };
        },
        0b110, 0b111 => { // c.beqz c.bnez
            const c: code.CB = @bitCast(cinst);
            return .{ .br_B = .{
                .op = switch (c.funct3) {
                    0b110 => .BEQ,
                    0b111 => .BNE,
                    else => unreachable,
                },
                .rs1 = @as(u5, c.rs1_) | 0b01000,
                .rs2 = 0,
                .imm = blk: {
                    const b8 = bits.extract(.{ 12, 12 }, cinst);
                    const b7_6 = bits.extract(.{ 6, 5 }, cinst);
                    const b5 = bits.extract(.{ 2, 2 }, cinst);
                    const b4_3 = bits.extract(.{ 11, 10 }, cinst);
                    const b2_1 = bits.extract(.{ 4, 3 }, cinst);
                    break :blk bits.extendSigned(
                        u12,
                        bits.concat(.{ b8, b7_6, b5, b4_3, b2_1 }),
                    );
                },
            } };
        },
    }
}

fn decode_Op10(cinst: u16) Error!Operation {
    const funct3: u3 = @truncate(cinst >> 13);
    switch (funct3) {
        0b000 => { // c.slli
            const c: code.CI = @bitCast(cinst);
            const b5: u1 = @truncate(cinst >> 12);
            if (b5 == 1) {
                return Error.CodeNotFound; // custom inst
            }
            return .{
                .al_I = .{
                    .op = .SLLI,
                    .rd = c.rd_rs1,
                    .rs1 = c.rd_rs1,
                    .imm = c.imm0,
                },
            };
        },
        0b001 => { // c/fldsp
            return Error.CodeNotFound;
        },
        0b010 => { // c.lwsp
            const c: code.CI = @bitCast(cinst);
            if (c.rd_rs1 == 0) {
                return Error.CodeReserved;
            }

            return .{
                .ld_I = .{
                    .op = .LW,
                    .rd = c.rd_rs1,
                    .rs1 = 2,
                    .imm = blk: {
                        const b7_6: u2 = bits.extract(.{ 3, 2 }, cinst);
                        const b4_2: u3 = bits.extract(.{ 6, 4 }, cinst);
                        const b5: u1 = bits.extract(.{ 12, 12 }, cinst);
                        break :blk bits.extendUnsigned(u12, bits.concat(.{ b7_6, b5, b4_2 })) << 2;
                    },
                },
            };
        },
        0b011 => { // c.flwsp
            return Error.CodeNotFound;
        },
        // c.jr c.jalr c.mv c.add c.ebreak
        0b100 => {
            const c: code.CR = @bitCast(cinst);
            const is_mv_or_add = c.rs2 != 0;

            if (is_mv_or_add) {
                return .{ .al_R = .{
                    .op = .ADD,
                    .rd = bits.extract(.{ 6, 2 }, cinst),
                    .rs1 = if (bits.extract(.{ 12, 12 }, cinst) == 1) bits.extract(.{ 11, 7 }, cinst) else 0,
                    .rs2 = bits.extract(.{ 6, 2 }, cinst),
                } };
            }

            assert(c.rs2 == 0);
            switch (c.funct4) {
                0b1000 => {
                    if (c.rd_rs1 == 0) {
                        return Error.CodeReserved;
                    }
                    return if (c.rs2 != 0)
                        // c.mv
                        .{ .al_R = .{
                            .op = .ADD,
                            .rd = c.rd_rs1,
                            .rs1 = c.rd_rs1,
                            .rs2 = c.rs2,
                        } }
                    else
                        // c.jr
                        .{ .jp_I = .{
                            .op = .JALR,
                            .rd = 0,
                            .rs1 = c.rd_rs1,
                            .imm = 0,
                        } };
                },
                0b1001 => {
                    if (c.rd_rs1 == 0 and c.rs2 == 0) {
                        return .{ .env_I = .{
                            .op = .EBREAK,
                            .rd = 0,
                            .rs1 = 0,
                            .imm = 0,
                        } };
                    }
                    return if (c.rs2 == 0)
                        // c.jalr
                        .{ .jp_I = .{
                            .op = .JALR,
                            .rd = 1,
                            .rs1 = c.rd_rs1,
                            .imm = 0,
                        } }
                    else
                        // c.add
                        .{ .al_R = .{
                            .op = .ADD,
                            .rd = c.rd_rs1,
                            .rs1 = c.rd_rs1,
                            .rs2 = c.rs2,
                        } };
                },
                else => unreachable,
            }
        },
        0b101 => { // c.fsdsp
            return Error.CodeNotFound;
        },
        0b110 => { // c.swsp
            const c: code.CSS = @bitCast(cinst);
            return .{ .st_S = .{
                .op = .SW,
                .rs1 = 2,
                .rs2 = c.rs2,
                .imm = blk: {
                    const b7_6: u2 = bits.extract(.{ 8, 7 }, cinst);
                    const b5_2: u2 = bits.extract(.{ 10, 9 }, cinst);
                    break :blk bits.extendUnsigned(u12, bits.concat(.{ b7_6, b5_2 })) << 2;
                },
            } };
        },
        0b111 => { // c.fswsp
            return Error.CodeNotFound;
        },
    }
}

const std = @import("std");
const assert = std.debug.assert;

const bits = @import("misc").bits;

const code = @import("../../code.zig");
const Error = code.Error;
const Operation = @import("../I.zig").Operation;
