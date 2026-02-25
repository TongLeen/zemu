pub fn decode(inst: u32) Error!Operation {
    const opcode: u7 = @truncate(inst);
    switch (opcode) {
        0b011_0011 => { // R-type arith&logic
            const c: code.R = @bitCast(inst);
            return .{ .al_R = .{
                .rd = c.rd,
                .rs1 = c.rs1,
                .rs2 = c.rs2,
                .op = blk: {
                    if (c.funct7 != 0 and (c.funct3 != 0b000 and c.funct3 != 0b101)) {
                        return Error.CodeNotFound;
                    }
                    break :blk switch (c.funct3) {
                        0b000 => switch (c.funct7) {
                            0 => .ADD,
                            0b010_0000 => .SUB,
                            else => {
                                return Error.CodeNotFound;
                            },
                        },
                        0b001 => .SLL,
                        0b010 => .SLT,
                        0b011 => .SLTU,
                        0b100 => .XOR,
                        0b101 => switch (c.funct7) {
                            0 => .SRL,
                            0b010_0000 => .SRA,
                            else => {
                                return Error.CodeNotFound;
                            },
                        },
                        0b110 => .OR,
                        0b111 => .AND,
                    };
                },
            } };
        },
        0b001_0011 => { // I-type arith&logic
            const c: code.I = @bitCast(inst);
            const funct7: u7 = @truncate(c.imm >> 5); // for shift code
            return .{ .al_I = .{
                .rd = c.rd,
                .rs1 = c.rs1,
                .imm = switch (c.funct3) {
                    0b001 => switch (funct7) {
                        0 => c.imm & 0b1_1111,
                        else => {
                            return Error.CodeNotFound;
                        },
                    },
                    0b101 => switch (funct7) {
                        0, 0b010_0000 => c.imm & 0b1_1111,
                        else => {
                            return Error.CodeNotFound;
                        },
                    },
                    else => c.imm,
                },
                .op = switch (c.funct3) {
                    0b000 => .ADDI,
                    0b001 => .SLLI,
                    0b010 => .SLTI,
                    0b011 => .SLTIU,
                    0b100 => .XORI,
                    0b101 => switch (funct7) {
                        0 => .SRLI,
                        0b010_0000 => .SRAI,
                        else => {
                            return Error.CodeNotFound;
                        },
                    },
                    0b110 => .ORI,
                    0b111 => .ANDI,
                },
            } };
        },
        0b111_0011 => { // I-type envirenmnt
            const c: code.I = @bitCast(inst);
            switch (c.funct3) {
                0b000 => {
                    if (!(c.rd == 0 and c.rs1 == 0)) {
                        return Error.CodeNotFound;
                    }
                    if (c.imm == 0) {
                        // ECALL
                        return .{ .env_I = .{
                            .rd = 0,
                            .rs1 = 0,
                            .imm = 0,
                            .op = .ECALL,
                        } };
                    } else if (c.imm == 1) {
                        // EBREAK
                        return .{ .env_I = .{
                            .rd = 0,
                            .rs1 = 0,
                            .imm = 0,
                            .op = .EBREAK,
                        } };
                    } else {
                        return Error.CodeNotFound;
                    }
                },
                0b001...0b011, 0b101...0b111 => {
                    // CSR
                    return .{ .csr_I = .{
                        .rd = c.rd,
                        .rs1 = c.rs1,
                        .csr = c.imm,
                        .op = switch (c.funct3) {
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
                    return Error.CodeNotFound;
                },
            }
        },
        0b110_0011 => { // B-type brench
            const c: code.B = @bitCast(inst);
            return .{ .br_B = .{
                .rs1 = c.rs1,
                .rs2 = c.rs2,
                .imm = c.imm(),
                .op = switch (c.funct3) {
                    0b000 => .BEQ,
                    0b001 => .BNE,
                    0b100 => .BLT,
                    0b101 => .BGE,
                    0b110 => .BLTU,
                    0b111 => .BGEU,
                    else => {
                        return Error.CodeNotFound;
                    },
                },
            } };
        },
        0b110_1111 => { // J-type jal
            const c: code.J = @bitCast(inst);
            return .{ .jp_J = .{
                .rd = c.rd,
                .imm = c.imm(),
                .op = .JAL,
            } };
        },
        0b110_0111 => { // I-type jalr
            const c: code.I = @bitCast(inst);
            if (c.funct3 != 0) {
                return Error.CodeNotFound;
            }
            return .{ .jp_I = .{
                .rd = c.rd,
                .rs1 = c.rs1,
                .imm = c.imm,
                .op = .JALR,
            } };
        },
        0b011_0111 => { // U-type lui
            const c: code.U = @bitCast(inst);
            return .{ .lu_U = .{
                .rd = c.rd,
                .imm = c.imm,
                .op = .LUI,
            } };
        },
        0b001_0111 => { // U-type auipc
            const c: code.U = @bitCast(inst);
            return .{ .pc_U = .{
                .rd = c.rd,
                .imm = c.imm,
                .op = .AUIPC,
            } };
        },
        0b000_0011 => { // I-type load
            const c: code.I = @bitCast(inst);
            return .{ .ld_I = .{
                .rd = c.rd,
                .rs1 = c.rs1,
                .imm = c.imm,
                .op = switch (c.funct3) {
                    0b000 => .LB,
                    0b001 => .LH,
                    0b010 => .LW,
                    0b100 => .LBU,
                    0b101 => .LHU,
                    else => {
                        return Error.CodeNotFound;
                    },
                },
            } };
        },
        0b010_0011 => { // S-type
            const c: code.S = @bitCast(inst);
            return .{ .st_S = .{
                .rs1 = c.rs1,
                .rs2 = c.rs2,
                .imm = c.imm(),
                .op = switch (c.funct3) {
                    0b000 => .SB,
                    0b001 => .SH,
                    0b010 => .SW,
                    else => {
                        return Error.CodeNotFound;
                    },
                },
            } };
        },
        else => {
            return Error.CodeNotFound;
        },
    }
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

        const Op = enum { ECALL, EBREAK };
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
            else => |op| {
                try writer.print("Unimplemented ISA: {s}", .{@tagName(op)});
            },
        }
    }
};

const std = @import("std");
const Writer = std.Io.Writer;

const bits = @import("misc").bits;

const code = @import("../code.zig");
const Error = code.Error;
