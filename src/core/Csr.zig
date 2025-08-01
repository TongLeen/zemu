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

const Mstatus = struct {
    sd: u1,
    wpri0: u2,
    vm: u5,
    wpri1: u4,
    mxr: u1,
    pum: u1,
    mprv: u1,
    xs: u2,
    fs: u2,
    mpp: u2,
    hpp: u2,
    spp: u1,
    mpie: u1,
    hpie: u1,
    spie: u1,
    upie: u1,
    mie: u1,
    hie: u1,
    sie: u1,
    uie: u1,

    pub fn get(self: *const @This()) u32 {
        return ((@as(u32, self.sd) << 31) | (@as(u32, self.wpri0) << 29) | (@as(u32, self.vm) << 24) | (@as(u32, self.wpri1) << 20) | (@as(u32, self.mxr) << 19) | (@as(u32, self.pum) << 18) | (@as(u32, self.mprv) << 17) | (@as(u32, self.xs) << 15) | (@as(u32, self.fs) << 13) | (@as(u32, self.mpp) << 11) | (@as(u32, self.hpp) << 9) | (@as(u32, self.spp) << 8) | (@as(u32, self.mpie) << 7) | (@as(u32, self.hpie) << 6) | (@as(u32, self.spie) << 5) | (@as(u32, self.upie) << 4) | (@as(u32, self.mie) << 3) | (@as(u32, self.mie) << 2) | (@as(u32, self.mie) << 1) | (@as(u32, self.mie) << 0));
    }

    pub fn set(self: *@This(), value: u32) void {
        self.sd = @truncate(value >> 31);
        self.wpri0 = @truncate(value >> 29);
        self.vm = @truncate(value >> 24);
        self.wpri1 = @truncate(value >> 20);
        self.mxr = @truncate(value >> 19);
        self.pum = @truncate(value >> 18);
        self.mprv = @truncate(value >> 17);
        self.xs = @truncate(value >> 15);
        self.fs = @truncate(value >> 13);
        self.mpp = @truncate(value >> 11);
        self.hpp = @truncate(value >> 9);
        self.spp = @truncate(value >> 8);
        self.mpie = @truncate(value >> 7);
        self.hpie = @truncate(value >> 6);
        self.spie = @truncate(value >> 5);
        self.upie = @truncate(value >> 4);
        self.mie = @truncate(value >> 3);
        self.hie = @truncate(value >> 2);
        self.sie = @truncate(value >> 1);
        self.uie = @truncate(value >> 0);
    }
};

const Self = @This();
