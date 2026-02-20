mstatus: Mstatus,
mie: u32,
mip: u32,
mtvec: u32,
mepc: u32,
mcause: u32,
mtval: u32,
mscratch: u32,
mcycle: u64,
minstret: u64,

pub fn read(self: *const Self, addr: u12, mode: u2) Error!u32 {
    const r_p: u2 = @truncate(addr >> 8);
    if (r_p > mode) {
        return Error.PermissionDenied;
    }

    return switch (addr) {
        @intFromEnum(Csr.mvendorid) => 0,
        @intFromEnum(Csr.marchid) => 0,
        @intFromEnum(Csr.mimplid) => 0,
        @intFromEnum(Csr.mhardid) => 0,

        @intFromEnum(Csr.mstatus) => self.mstatus.get(),
        @intFromEnum(Csr.mie) => self.mie,
        @intFromEnum(Csr.mtvec) => self.mtvec,
        @intFromEnum(Csr.mscratch) => self.mscratch,
        @intFromEnum(Csr.mepc) => self.mepc,
        @intFromEnum(Csr.mcause) => self.mcause,
        @intFromEnum(Csr.mtval) => self.mtval,
        @intFromEnum(Csr.mip) => self.mip,

        @intFromEnum(Csr.mcycle) => @truncate(self.mcycle),
        @intFromEnum(Csr.mcycleh) => @truncate(self.mcycle >> 32),
        @intFromEnum(Csr.minstret) => @truncate(self.minstret),
        @intFromEnum(Csr.minstreth) => @truncate(self.minstret >> 32),

        else => {
            return Error.NotImplemented;
        },
    };
}

pub fn write(self: *Self, addr: u12, value: u32, mode: u2) Error!void {
    const read_only = @as(u2, @truncate(addr >> 10)) == 0b11;
    const r_p: u2 = @truncate(addr >> 8);
    if (r_p > mode or read_only) {
        return Error.PermissionDenied;
    }
    switch (addr) {
        @intFromEnum(Csr.mvendorid),
        @intFromEnum(Csr.marchid),
        @intFromEnum(Csr.mimplid),
        @intFromEnum(Csr.mhardid),
        => unreachable,

        @intFromEnum(Csr.mstatus) => {
            self.mstatus.set(value);
        },
        @intFromEnum(Csr.mie) => {
            self.mie = value;
        },
        @intFromEnum(Csr.mtvec) => {
            self.mtvec = value;
        },
        @intFromEnum(Csr.mscratch) => {
            self.mscratch = value;
        },
        @intFromEnum(Csr.mepc) => {
            self.mepc = value;
        },
        @intFromEnum(Csr.mcause) => {
            self.mcause = value;
        },
        @intFromEnum(Csr.mtval) => {
            self.mtval = value;
        },
        @intFromEnum(Csr.mip) => {
            self.mip = value;
        },

        @intFromEnum(Csr.mcycle) => {
            self.mcycle = self.mcycle & 0xffff_ffff_0000_0000 | value;
        },
        @intFromEnum(Csr.mcycleh) => {
            self.mcycle = self.mcycle & 0xffff_ffff | (@as(u64, value) << 32);
        },
        @intFromEnum(Csr.minstret) => {
            self.minstret = self.minstret & 0xffff_ffff_0000_0000 | value;
        },
        @intFromEnum(Csr.minstreth) => {
            self.minstret = self.minstret & 0xffff_ffff | (@as(u64, value) << 32);
        },

        else => {
            return Error.NotImplemented;
        },
    }
}

pub fn reset(self: *Self) void {
    self.mstatus.set(0);
    self.mie = 0;
    self.mip = 0;
    self.mcycle = 0;
    self.minstret = 0;
}

pub const Error = error{
    NotImplemented,
    PermissionDenied,
};

pub const Csr = enum(u12) {
    // cycle = 0xc00,
    // instret = 0xc02,

    // Machine Infomation Registers
    mvendorid = 0xf11,
    marchid = 0xf12,
    mimplid = 0xf13,
    mhardid = 0xf14,

    // ?
    // mconfigptr = 0xf15,

    // Machine Trap Setup
    mstatus = 0x300,
    // misa = 0x301,
    // medeleg = 0x302,
    // mideleg = 0x303,
    mie = 0x304,
    mtvec = 0x305,
    // mcounteren = 0x306,
    // mstatush = 0x310,

    // Machine Trap Handling
    mscratch = 0x340,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mip = 0x344,
    // mtinst = 0x34a,
    // mtval2 = 0x34b,

    mcycle = 0xb00,
    mcycleh = 0xb80,
    minstret = 0xb02,
    minstreth = 0xb82,

    // tselect = 0x7a0,
    // tdata1 = 0x7a1,
};

const Mstatus = packed struct {
    uie: u1,
    sie: u1,
    hie: u1,
    mie: u1,
    upie: u1,
    spie: u1,
    hpie: u1,
    mpie: u1,
    spp: u1,
    hpp: u2,
    mpp: u2,
    fs: u2,
    xs: u2,
    mprv: u1,
    pum: u1,
    mxr: u1,
    wpri1: u4,
    vm: u5,
    wpri0: u2,
    sd: u1,

    pub fn get(self: *const @This()) u32 {
        return @bitCast(self.*);
    }

    pub fn set(self: *@This(), value: u32) void {
        self.* = @bitCast(value);
    }
};

const Self = @This();
