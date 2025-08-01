raw: [32]u32,

pub inline fn read(self: *const Self, reg: u5) u32 {
    return self.raw[reg];
}

pub inline fn write(self: *Self, reg: u5, value: u32) void {
    self.raw[reg] = value;
    self.raw[0] = 0;
}

const Self = @This();
