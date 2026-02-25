pub fn Riscv32(isa: decoder.ISA_EXTENSION, entry_address: u32) type {
    return struct {
        const Decoder = decoder.Decoder(isa);
        const ENTRY_ADDRESS: u32 = entry_address;

        regs: Reg,
        pc: u32,
        mem: Memory,
        csr: Csr,
        mode: Mode,
        fetcher: Fetcher,

        pub fn init(memorys: []Memory.MemoryBlock) Self {
            return .{
                .regs = undefined,
                .pc = undefined,
                .mem = .init(memorys),
                .csr = undefined,
                .mode = undefined,
                .fetcher = .{
                    .c_inst_buffer = 0,
                    .c_inst_addr_buffer = null,
                    .this_inst = .{ .inst = 0 },
                },
            };
        }

        pub fn start(self: *Self) Error!void {
            self.restart();
            while (true) {
                try self.tick(false);
            }
        }

        pub fn tick(self: *Self) Error!void {
            const inst = self.fetcher.fetch(self) catch |e| {
                switch (e) {
                    Memory.AccessError.AddrNotAligned => Executor.trap(self, .instruction_address_misaligned),
                    Memory.AccessError.AddrOutOfRange => Executor.trap(self, .instruction_access_fault),
                    else => unreachable,
                }
                return;
            };

            const operation = switch (inst) {
                .inst, .cinst => |v| Decoder.decode(v),
            } catch |e| {
                std.debug.print("{}\n", .{e});
                return Executor.trap(self, .illegal_instruction);
            };

            std.debug.print(color.info(.{"{x:0>8}:\t{f}\n"}), .{ self.pc, operation });

            return Executor.exec(self, operation, inst == .cinst);
        }

        pub fn reset(self: *Self) void {
            self.pc = ENTRY_ADDRESS;
            self.regs.write(0, 0);
            self.mode = .M;
        }

        pub fn readReg(self: *const Self, reg: u5) u32 {
            return self.regs.read(reg);
        }

        pub fn writeReg(self: *Self, reg: u5, value: u32) void {
            return self.regs.write(reg, value);
        }

        pub fn incPc(self: *Self, value: i32) void {
            const uv: u32 = @bitCast(value);
            self.pc +%= uv;
        }

        pub fn cpu(self: *Self) Cpu {
            const typeErased = struct {
                fn tick(ctx: Ctx) anyerror!void {
                    return deerase(ctx).tick();
                }

                fn reset(ctx: Ctx) void {
                    return deerase(ctx).reset();
                }

                fn readThisInst(ctx: ConstCtx) u32 {
                    const ptr = deerase(ctx);
                    return switch (ptr.fetcher.this_inst) {
                        .inst, .cinst => |v| v,
                    };
                }

                fn readPc(ctx: ConstCtx) u32 {
                    const ptr = deerase(ctx);
                    return ptr.pc;
                }

                fn writePc(ctx: Ctx, value: u32) void {
                    const ptr = deerase(ctx);
                    ptr.pc = value;
                }

                fn readMode(ctx: ConstCtx) u2 {
                    const ptr = deerase(ctx);
                    return @intFromEnum(ptr.mode);
                }

                fn writeMode(ctx: Ctx, mode: u2) void {
                    const ptr = deerase(ctx);
                    ptr.mode = @enumFromInt(mode);
                }

                fn readReg(ctx: ConstCtx, reg: u5) u32 {
                    const ptr = deerase(ctx);
                    return ptr.regs.read(reg);
                }

                fn writeReg(ctx: Ctx, reg: u5, value: u32) void {
                    const ptr = deerase(ctx);
                    return ptr.regs.write(reg, value);
                }

                const Ctx = *anyopaque;
                const ConstCtx = *const anyopaque;
                fn deerase(ctx: anytype) t: {
                    const is_const = @typeInfo(@TypeOf(ctx)).pointer.is_const;
                    break :t if (is_const) *const Self else *Self;
                } {
                    return @ptrCast(@alignCast(ctx));
                }
            };
            return .{
                .context = @ptrCast(self),
                .vtable = .{
                    .readRegFn = typeErased.readReg,
                    .writeRegFn = typeErased.writeReg,
                    .readThisInstFn = typeErased.readThisInst,
                    .readPcFn = typeErased.readPc,
                    .writePcFn = typeErased.writePc,
                    .readModeFn = typeErased.readMode,
                    .writeModeFn = typeErased.writeMode,
                    .tickFn = typeErased.tick,
                    .resetFn = typeErased.reset,
                },
                .mem = &self.mem,
                .csr = &self.csr,
            };
        }

        const Self = @This();
    };
}

pub const Error = error{Ebreak};

const Mode = enum(u2) { U = 0, S, H, M };

const std = @import("std");

const core = @import("core");
const Reg = core.Reg;
const Csr = core.Csr;
const Cpu = core.Cpu;
const Memory = core.Memory;

pub const decoder = @import("riscv32/decoder.zig");
pub const Executor = @import("riscv32/Executor.zig");
pub const Fetcher = @import("riscv32/Fetcher.zig");

const color = @import("misc").color;
