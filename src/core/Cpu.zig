context: *anyopaque,
vtable: VTable,
mem: *const Memory,
csr: *Csr,

pub fn readReg(self: Self, reg: u5) u32 {
    return self.vtable.readRegFn(self.context, reg);
}

pub fn writeReg(self: Self, reg: u5, value: u32) void {
    return self.vtable.writeRegFn(self.context, reg, value);
}

pub fn readThisInst(self: Self) u32 {
    return self.vtable.readThisInstFn(self.context);
}

pub fn readPc(self: Self) u32 {
    return self.vtable.readPcFn(self.context);
}

pub fn writePc(self: Self, value: u32) void {
    return self.vtable.writePcFn(self.context, value);
}

pub fn incPc(self: Self, value: i32) void {
    const uv: u32 = @bitCast(value);
    self.writePc(self.readPc() +% uv);
}

pub fn readMode(self: Self) u2 {
    return self.vtable.readModeFn(self.context);
}

pub fn writeMode(self: Self, mode: u2) void {
    return self.vtable.writeModeFn(self.context, mode);
}

pub fn tick(self: Self) !void {
    return self.vtable.tickFn(self.context);
}

pub fn reset(self: Self) void {
    return self.vtable.resetFn(self.context);
}

const VTable = struct {
    readRegFn: *const fn (context: *const anyopaque, reg: u5) u32,
    writeRegFn: *const fn (context: *anyopaque, reg: u5, value: u32) void,

    readThisInstFn: *const fn (context: *const anyopaque) u32,
    readPcFn: *const fn (context: *const anyopaque) u32,
    writePcFn: *const fn (context: *anyopaque, value: u32) void,
    readModeFn: *const fn (context: *const anyopaque) u2,
    writeModeFn: *const fn (context: *anyopaque, mode: u2) void,

    tickFn: *const fn (context: *anyopaque) anyerror!void,
    resetFn: *const fn (context: *anyopaque) void,
};

const Self = @This();
const Memory = @import("Memory.zig");
const Csr = @import("Csr.zig");
