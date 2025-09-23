pub fn decode(inst: u32) Error!Operation {
    const opcode: u7 = @truncate(inst & 0b111_1111);
    switch (opcode) {
        0b011_0011 => {
            // R-type arith&logic
            const func3: u3 = @truncate(inst >> 12);
            const rd: u5 = @truncate(inst >> 7);
            const rs1: u5 = @truncate(inst >> 15);
            const rs2: u5 = @truncate(inst >> 20);

            return .{ .al_R = .{
                .rd = rd,
                .rs1 = rs1,
                .rs2 = rs2,
                .op = switch (func3) {
                    0b000 => if (@as(u1, @truncate(inst >> 30)) == 0) .ADD else .SUB,
                    0b001 => .SLL,
                    0b010 => .SLT,
                    0b011 => .SLTU,
                    0b100 => .XOR,
                    0b101 => if (@as(u1, @truncate(inst >> 30)) == 0) .SRL else .SRA,
                    0b110 => .OR,
                    0b111 => .AND,
                },
            } };
        },
        0b001_0011 => {
            // I-type arith&logic
            const func3: u3 = @truncate(inst >> 12);
            const rd: u5 = @truncate(inst >> 7);
            const rs1: u5 = @truncate(inst >> 15);
            const imm: u12 = @truncate(inst >> 20);

            return .{ .al_I = .{
                .rd = rd,
                .rs1 = rs1,
                .imm = switch (func3) {
                    0b001 => blk: {
                        if ((imm >> 5) == 0) {
                            break :blk imm;
                        } else {
                            return Error.CodeIncorrect;
                        }
                    },
                    0b101 => blk: {
                        if ((imm >> 5) == 0) {
                            break :blk @as(u5, @truncate(imm));
                        } else if ((imm >> 5) == 0b010_0000) {
                            break :blk @as(u5, @truncate(imm));
                        } else {
                            return Error.CodeIncorrect;
                        }
                    },
                    else => imm,
                },
                .op = switch (func3) {
                    0b000 => .ADDI,
                    0b001 => .SLLI,
                    0b010 => .SLTI,
                    0b011 => .SLTIU,
                    0b100 => .XORI,
                    0b101 => if (@as(u1, @truncate(inst >> 30)) == 0) .SRLI else .SRAI,
                    0b110 => .ORI,
                    0b111 => .ANDI,
                },
            } };
        },
        0b111_0011 => {
            // I-type envirenmnt inst
            const func3: u3 = @truncate(inst >> 12);
            const rd: u5 = @truncate(inst >> 7);
            const rs1: u5 = @truncate(inst >> 15);
            const imm: u12 = @truncate(inst >> 20);

            switch (func3) {
                0b000 => {
                    if (rd != 0 or rs1 != 0) {
                        return Error.CodeIncorrect;
                    }
                    if (imm == 0) {
                        // ECALL
                        return .{ .env_I = .{
                            .rd = 0,
                            .rs1 = 0,
                            .imm = 0,
                            .op = .ECALL,
                        } };
                    } else if (imm == 1) {
                        // EBREAK
                        return .{ .env_I = .{
                            .rd = 0,
                            .rs1 = 0,
                            .imm = 0,
                            .op = .EBREAK,
                        } };
                    } else if (imm == 0b0011000_00010) {
                        // MRET
                        return .{ .env_I = .{
                            .rd = 0,
                            .rs1 = 0,
                            .imm = 0,
                            .op = .MRET,
                        } };
                    } else {
                        return Error.CodeIncorrect;
                    }
                },
                0b001...0b011, 0b101...0b111 => {
                    // CSR
                    return .{ .csr_I = .{
                        .rd = rd,
                        .rs1 = rs1,
                        .csr = imm,
                        .op = switch (func3) {
                            0b001 => .CSRRW,
                            0b010 => .CSRRS,
                            0b011 => .CSRRC,
                            0b101 => .CSRRWI,
                            0b110 => .CSRRSI,
                            0b111 => .CSRRCI,
                            else => unreachable,
                        },
                    } };
                },
                else => {
                    return Error.CodeIncorrect;
                },
            }
        },
        0b110_0011 => {
            // B-type brench
            const func3: u3 = @truncate(inst >> 12);
            const rs1: u5 = @truncate(inst >> 15);
            const rs2: u5 = @truncate(inst >> 20);

            const imm_12: u1 = @truncate(inst >> 31);
            const imm_11: u1 = @truncate(inst >> 7);
            const imm_h: u6 = @truncate(inst >> 25);
            const imm_l: u4 = @truncate(inst >> 8);
            const imm: u12 = @as(u12, imm_12) << 11 | @as(u12, imm_11) << 10 | @as(u12, imm_h) << 4 | @as(u12, imm_l);

            return .{ .br_B = .{
                .rs1 = rs1,
                .rs2 = rs2,
                .imm = imm,
                .op = switch (func3) {
                    0b000 => .BEQ,
                    0b001 => .BNE,
                    0b100 => .BLT,
                    0b101 => .BGE,
                    0b110 => .BLTU,
                    0b111 => .BGEU,
                    else => {
                        return Error.CodeIncorrect;
                    },
                },
            } };
        },
        0b110_1111 => {
            // J-type jal
            const rd: u5 = @truncate(inst >> 7);
            const imm_20: u1 = @truncate(inst >> 31);
            const imm_11: u1 = @truncate(inst >> 20);
            const imm_l: u10 = @truncate(inst >> 21);
            const imm_h: u8 = @truncate(inst >> 12);
            const imm: u20 = @as(u20, imm_20) << 19 | @as(u20, imm_h) << 11 | @as(u20, imm_11) << 10 | @as(u20, imm_l);
            return .{ .jp_J = .{
                .rd = rd,
                .imm = imm,
                .op = .JAL,
            } };
        },
        0b110_0111 => {
            // I-type jalr
            const func3: u3 = @truncate(inst >> 12);
            const rd: u5 = @truncate(inst >> 7);
            const rs1: u5 = @truncate(inst >> 15);
            const imm: u12 = @truncate(inst >> 20);
            if (func3 != 0) {
                return Error.CodeIncorrect;
            }
            return .{ .jp_I = .{
                .rd = rd,
                .rs1 = rs1,
                .imm = imm,
                .op = .JALR,
            } };
        },
        0b011_0111 => {
            // U-type lui
            const rd: u5 = @truncate(inst >> 7);
            const imm: u20 = @truncate(inst >> 12);
            return .{ .lu_U = .{
                .rd = rd,
                .imm = imm,
                .op = .LUI,
            } };
        },
        0b001_0111 => {
            // U-type auipc
            const rd: u5 = @truncate(inst >> 7);
            const imm: u20 = @truncate(inst >> 12);
            return .{ .pc_U = .{
                .rd = rd,
                .imm = imm,
                .op = .AUIPC,
            } };
        },

        0b000_0011 => {
            // I-type load
            const func3: u3 = @truncate(inst >> 12);
            const rd: u5 = @truncate(inst >> 7);
            const rs1: u5 = @truncate(inst >> 15);
            const imm: u12 = @truncate(inst >> 20);

            return .{ .ld_I = .{
                .rd = rd,
                .rs1 = rs1,
                .imm = imm,
                .op = switch (func3) {
                    0b000 => .LB,
                    0b001 => .LH,
                    0b010 => .LW,
                    0b100 => .LBU,
                    0b101 => .LHU,
                    else => {
                        return Error.CodeIncorrect;
                    },
                },
            } };
        },
        0b010_0011 => {
            // S-type
            const func3: u3 = @truncate(inst >> 12);
            const rs1: u5 = @truncate(inst >> 15);
            const rs2: u5 = @truncate(inst >> 20);
            const imm_l: u5 = @truncate(inst >> 7);
            const imm_h: u7 = @truncate(inst >> 25);
            const imm: u12 = (@as(u12, imm_h) << 5) | imm_l;

            return .{ .st_S = .{
                .rs1 = rs1,
                .rs2 = rs2,
                .imm = imm,
                .op = switch (func3) {
                    0b000 => .SB,
                    0b001 => .SH,
                    0b010 => .SW,
                    else => {
                        return Error.CodeIncorrect;
                    },
                },
            } };
        },
        else => {
            return Error.CodeIncorrect;
        },
    }
}

pub fn decodeCompressed(cinst: u16) Error!Operation {
    const op: u2 = @truncate(cinst);
    const func3: u3 = @truncate(cinst >> 13);

    return switch (op) {
        0b00 => switch (func3) {
            // c.lw
            0b010 => .{ .ld_I = .{
                .op = .LW,
                .rd = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 2) | 0b01000,
                .rs1 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                .imm = blk: {
                    const b6 = bits.extract(.{ 5, 5 }, cinst);
                    const b5_3 = bits.extract(.{ 12, 10 }, cinst);
                    const b2 = bits.extract(.{ 6, 6 }, cinst);
                    break :blk bits.extendUnsigned(
                        u12,
                        bits.concat(.{ b6, b5_3, b2 }),
                    ) << 2;
                },
            } },
            // c.sw
            0b110 => .{ .st_S = .{
                .op = .SW,
                .rs1 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                .rs2 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 2) | 0b01000,
                .imm = blk: {
                    const b6 = bits.extract(.{ 5, 5 }, cinst);
                    const b5_3 = bits.extract(.{ 12, 10 }, cinst);
                    const b2 = bits.extract(.{ 6, 6 }, cinst);
                    break :blk bits.extendUnsigned(
                        u12,
                        bits.concat(.{ b6, b5_3, b2 }),
                    ) << 2;
                },
            } },
            // c.addi4spn
            0b000 => .{ .al_I = .{
                .op = .ADDI,
                .rd = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 2) | 0b01000,
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
            } },
            else => {
                return Error.CodeIncorrect;
            },
        },
        0b01 => switch (func3) {
            // c.j c.jal
            0b101, 0b001 => .{ .jp_J = .{
                .op = .JAL,
                .rd = if (func3 == 0b001) 1 else 0,
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
            } },
            // c.beqz c.bnez
            0b110, 0b111 => .{ .br_B = .{
                .op = if (func3 == 0b110) .BEQ else .BNE,
                .rs1 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
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
            } },
            // c.li
            0b010 => .{ .al_I = .{
                .op = .ADDI,
                .rd = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                .rs1 = 0,
                .imm = blk: {
                    const b5 = bits.extract(.{ 11, 11 }, cinst);
                    const b4_0: u5 = bits.extract(.{ 6, 2 }, cinst);
                    break :blk bits.extendSigned(
                        u12,
                        bits.concat(.{ b5, b4_0 }),
                    );
                },
            } },
            // c.lui c.addi16sp
            0b011 => if (bits.extract(.{ 6, 2 }, cinst) == 2) .{ .al_I = .{
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
                .rd = bits.extract(.{ 11, 7 }, cinst),
                .imm = blk: {
                    const b5: u1 = bits.extract(.{ 11, 11 }, cinst);
                    const b4_0: u5 = bits.extract(.{ 6, 2 }, cinst);

                    const uv = bits.concat(.{ b5, b4_0 });
                    if (uv == 0) {
                        return Error.CodeIncorrect;
                    }
                    break :blk bits.extendSigned(u20, uv);
                },
            } },
            // c.addi
            0b000 => .{ .al_I = .{
                .op = .ADDI,
                .rd = bits.extract(.{ 11, 7 }, cinst),
                .rs1 = bits.extract(.{ 11, 7 }, cinst),
                .imm = blk: {
                    const b5: u1 = bits.extract(.{ 12, 12 }, cinst);
                    const b4_0: u5 = bits.extract(.{ 6, 2 }, cinst);
                    break :blk bits.extendSigned(
                        u12,
                        bits.concat(.{ b5, b4_0 }),
                    );
                },
            } },

            // c.srli c.srai c.and c.or c.xor c.sub
            0b100 => out: {
                const func2: u2 = bits.extract(.{ 11, 10 }, cinst);
                const func2_: u2 = bits.extract(.{ 6, 5 }, cinst);

                break :out if (func2 != 0b11) .{ .al_I = .{
                    .op = switch (func2) {
                        0b00 => .SRLI,
                        0b01 => .SRAI,
                        0b10 => .ANDI,
                        else => {
                            return Error.CodeIncorrect;
                        },
                    },
                    .rd = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                    .rs1 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                    .imm = blk: {
                        const b5 = bits.extract(.{ 12, 12 }, cinst);
                        if (func2 != 0b10 and b5 == 1) {
                            return Error.CodeIncorrect;
                        }
                        const b4_0 = bits.extract(.{ 6, 2 }, cinst);
                        break :blk bits.extendSigned(
                            u12,
                            bits.concat(.{ b5, b4_0 }),
                        );
                    },
                } } else blk: {
                    if (bits.extract(.{ 12, 12 }, cinst) != 0) {
                        return Error.CodeIncorrect;
                    }
                    break :blk .{ .al_R = .{
                        .op = switch (func2_) {
                            0b00 => .SUB,
                            0b01 => .XOR,
                            0b10 => .OR,
                            0b11 => .AND,
                        },
                        .rd = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                        .rs1 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 7) | 0b01000,
                        .rs2 = bits.truncateAndExtendUnsigned(u5, 3, cinst >> 2) | 0b01000,
                    } };
                };
            },
        },
        0b10 => switch (func3) {
            // c.lwsp
            0b010 => .{ .ld_I = .{
                .op = .LW,
                .rd = bits.extract(.{ 11, 7 }, cinst),
                .rs1 = 2,
                .imm = blk: {
                    const b7_6: u2 = bits.extract(.{ 3, 2 }, cinst);
                    const b4_2: u3 = bits.extract(.{ 6, 4 }, cinst);
                    const b5: u1 = bits.extract(.{ 12, 12 }, cinst);
                    break :blk bits.extendUnsigned(u12, bits.concat(.{ b7_6, b5, b4_2 })) << 2;
                },
            } },
            // c.swsp
            0b110 => .{ .st_S = .{
                .op = .SW,
                .rs1 = 2,
                .rs2 = bits.extract(.{ 6, 2 }, cinst),
                .imm = blk: {
                    const b7_6: u2 = bits.extract(.{ 8, 7 }, cinst);
                    const b5_2: u2 = bits.extract(.{ 10, 9 }, cinst);
                    break :blk bits.extendUnsigned(u12, bits.concat(.{ b7_6, b5_2 })) << 2;
                },
            } },
            // c.jr c.jalr c.mv c.add
            0b100 => out: {
                const is_j = bits.extract(.{ 6, 2 }, cinst) == 0;
                break :out if (is_j) .{ .jp_I = .{
                    .op = .JALR,
                    .rs1 = blk: {
                        const rs1: u5 = bits.extract(.{ 11, 7 }, cinst);
                        if (rs1 == 0) {
                            if (bits.extract(.{ 12, 12 }, cinst) == 1) {
                                return .{ .env_I = .{
                                    .op = .EBREAK,
                                    .rd = 0,
                                    .rs1 = 0,
                                    .imm = 0,
                                } };
                            } else {
                                return Error.CodeIncorrect;
                            }
                        } else {
                            break :blk rs1;
                        }
                    },
                    .rd = if (bits.extract(.{ 12, 12 }, cinst) == 1) 1 else 0,
                    .imm = 0,
                } } else .{ .al_R = .{
                    .op = .ADD,
                    .rd = bits.extract(.{ 6, 2 }, cinst),
                    .rs1 = if (bits.extract(.{ 12, 12 }, cinst) == 1) bits.extract(.{ 11, 7 }, cinst) else 0,
                    .rs2 = bits.extract(.{ 6, 2 }, cinst),
                } };
            },
            // c.slli
            0b000 => .{ .al_I = .{
                .op = .SLLI,
                .rd = bits.extract(.{ 11, 7 }, cinst),
                .rs1 = bits.extract(.{ 11, 7 }, cinst),
                .imm = blk: {
                    const b5: u1 = bits.extract(.{ 12, 12 }, cinst);
                    if (b5 == 1) {
                        return Error.CodeIncorrect;
                    }
                    const b4_0 = bits.extract(.{ 6, 2 }, cinst);
                    break :blk bits.extendUnsigned(u12, bits.concat(.{ b5, b4_0 }));
                },
            } },
            else => {
                return Error.CodeIncorrect;
            },
        },
        0b11 => {
            return Error.CodeIncorrect;
        },
    };
}

/// `Operation` is a `tagged union` which contains what cpu need to do.
/// This created by `decode` from a `u32` instrutrion code.
pub const Operation = union(enum) {
    // arithmetic & logic inst operations
    // R-type
    al_R: struct {
        rd: u5,
        rs1: u5,
        rs2: u5,
        op: Op,

        const Op = enum { ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND };
    },
    // arithmetic & logic inst operations with immediate
    // I-type
    al_I: struct {
        rd: u5,
        rs1: u5,
        imm: u12,
        op: Op,

        const Op = enum { ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI };
    },
    // envirenmnet operations
    // I-type
    env_I: struct {
        rd: u5,
        rs1: u5,
        imm: u12,
        op: Op,

        const Op = enum { ECALL, EBREAK, MRET };
    },
    // brench operations
    // B-type
    br_B: struct {
        rs1: u5,
        rs2: u5,
        imm: u12,
        op: Op,

        const Op = enum { BEQ, BNE, BLT, BGE, BLTU, BGEU };
    },
    // jump operation
    // J-type
    jp_J: struct {
        rd: u5,
        imm: u20,
        op: Op,

        const Op = enum { JAL };
    },
    // jump operations
    // I-type
    jp_I: struct {
        rd: u5,
        rs1: u5,
        imm: u12,
        op: Op,

        const Op = enum { JALR };
    },
    // load large immediate number
    // U-type
    lu_U: struct {
        rd: u5,
        imm: u20,
        op: Op,

        const Op = enum { LUI };
    },
    // get PC and add imm
    // U-type
    pc_U: struct {
        rd: u5,
        imm: u20,
        op: Op,

        const Op = enum { AUIPC };
    },
    // load operations
    // I-type
    ld_I: struct {
        rd: u5,
        rs1: u5,
        imm: u12,
        op: Op,

        const Op = enum { LB, LH, LW, LBU, LHU };
    },
    // store operations
    // S-type
    st_S: struct {
        rs1: u5,
        rs2: u5,
        imm: u12,
        op: Op,

        const Op = enum { SB, SH, SW };
    },
    // csr
    // I-type
    csr_I: struct {
        rd: u5,
        rs1: u5,
        csr: u12,
        op: Op,

        const Op = enum {
            CSRRW,
            CSRRWI,
            CSRRS,
            CSRRSI,
            CSRRC,
            CSRRCI,
        };
    },
    pub fn format(
        self: *const @This(),
        writer: *Writer,
    ) !void {
        switch (self.*) {
            .al_R => |op| {
                try writer.print("{s}\tx{d},\tx{d},\tx{d}", .{ @tagName(op.op), op.rd, op.rs1, op.rs2 });
            },
            .al_I => |op| {
                try writer.print("{s}\tx{d},\tx{d},\t{d}", .{ @tagName(op.op), op.rd, op.rs1, @as(i12, @bitCast(op.imm)) });
            },
            .env_I => |op| {
                try writer.print("{s}", .{@tagName(op.op)});
            },
            .csr_I => |op| {
                try writer.print("{s}\tx{d},\t{s},\tx{d}", .{ @tagName(op.op), op.rd, @tagName(@as(Csr.Csr, @enumFromInt(op.csr))), op.rs1 });
            },
            .br_B => |op| {
                try writer.print("{s}\tx{d},\tx{d},\t{d}", .{ @tagName(op.op), op.rs1, op.rs2, @as(i12, @bitCast(op.imm)) });
            },
            .jp_J => |op| {
                try writer.print("{s}\tx{d},\t{d}", .{ @tagName(op.op), op.rd, @as(i20, @bitCast(op.imm)) });
            },
            .jp_I => |op| {
                try writer.print("{s}\tx{d},\t{d}(x{d})", .{ @tagName(op.op), op.rd, @as(i12, @bitCast(op.imm)), op.rs1 });
            },
            .lu_U => |op| {
                try writer.print("{s}\tx{d},\t0x{x}", .{ @tagName(op.op), op.rd, op.imm });
            },
            .pc_U => |op| {
                try writer.print("{s}\tx{d},\t0x{x}", .{ @tagName(op.op), op.rd, op.imm });
            },
            .ld_I => |op| {
                try writer.print("{s}\tx{d},\t{d}(x{d})", .{ @tagName(op.op), op.rd, @as(i12, @bitCast(op.imm)), op.rs1 });
            },
            .st_S => |op| {
                try writer.print("{s}\tx{d},\t{d}(x{d})", .{ @tagName(op.op), op.rs2, @as(i12, @bitCast(op.imm)), op.rs1 });
            },
        }
    }
};

pub const Error = error{CodeIncorrect};

const std = @import("std");
const Writer = std.Io.Writer;

const core = @import("../root.zig");
const Csr = core.Csr;

const bits = @import("misc").bits;
