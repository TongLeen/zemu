memory_block_list: MemoryBlockList,

pub fn init(allocator: Allocator) Allocator.Error!Self {
    return .{
        .memory_block_list = MemoryBlockList.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.memory_block_list.deinit();
}

pub fn addMemoryBlock(self: *Self, block: MemoryBlock) (MemoryBlockError || Allocator.Error)!void {
    const ok = self.ensureNotOverlapping(block);
    if (!ok) {
        return MemoryBlockError.AddrRangeOverlapped;
    }
    try self.memory_block_list.append(block);

    std.debug.print(
        color.info(.{"Memory Block added: 0x{x:0>8}-0x{x:0>8} {s}\n"}),
        .{
            @as(u32, block.start_addr) << 2,
            @as(u32, (block.start_addr + block.len)) << 2,
            if (block.write_handle == null) "ReadOnly" else "ReadWrite",
        },
    );
}

pub const MemoryBlock = struct {
    context: *const anyopaque,
    read_handle: *const fn (context: *const anyopaque, addr: u30, byte_mask: u4) anyerror!u32,
    write_handle: ?*const fn (context: *const anyopaque, addr: u30, value: u32, byte_mask: u4) anyerror!void,
    start_addr: u30,
    len: u30,

    pub fn contains(self: *const MB, addr: u30) bool {
        return (addr >= self.start_addr and addr < self.start_addr + self.len);
    }

    pub fn readAligned(self: *const MB, addr_aligned: u30, byte_mask: u4) anyerror!u32 {
        return self.read_handle(self.context, addr_aligned, byte_mask);
    }

    pub fn writeAligned(self: *const MB, addr_aligned: u30, value: u32, byte_mask: u4) anyerror!void {
        if (self.write_handle) |f| {
            return f(self.context, addr_aligned, value, byte_mask);
        } else {
            return error.NoWritePermission;
        }
    }
    const MB = @This();
};

pub fn readByte(self: *const Self, addr: u32) AccessError!u8 {
    const byte_bias: u2 = @as(u2, @truncate(addr)) & 0b11;
    const addr_aligned: u30 = @truncate(addr >> 2);
    const word = try self.readAligned(addr_aligned, @as(u4, 1) << byte_bias);
    return @truncate(word >> (@as(u5, byte_bias) * 8));
}

pub fn readHalfWord(self: *const Self, addr: u32) AccessError!u16 {
    const byte_bias: u2 = @as(u2, @truncate(addr)) & 0b11;
    if (byte_bias == 0b11) {
        return AccessError.AddrNotAligned;
    }
    const addr_aligned: u30 = @truncate(addr >> 2);
    const word = try self.readAligned(addr_aligned, @as(u4, 0b11) << byte_bias);
    return @truncate(word >> (@as(u5, byte_bias) * 8));
}

pub fn readWord(self: *const Self, addr: u32) AccessError!u32 {
    if (@as(u2, @truncate(addr)) & 0b11 != 0) {
        return AccessError.AddrNotAligned;
    }
    const addr_aligned: u30 = @truncate(addr >> 2);
    return self.readAligned(addr_aligned, 0b1111);
}

fn readAligned(self: *const Self, addr_aligned: u30, byte_mask: u4) AccessError!u32 {
    const block = loop: for (self.memory_block_list.items) |v| {
        if (v.contains(addr_aligned)) {
            break :loop v;
        }
    } else {
        return AccessError.AddrOutOfRange;
    };
    return @errorCast(block.readAligned(addr_aligned - block.start_addr, byte_mask));
}

pub fn writeByte(self: *Self, addr: u32, value: u8) AccessError!void {
    const byte_bias: u2 = @as(u2, @truncate(addr)) & 0b11;
    const addr_aligned: u30 = @truncate(addr >> 2);
    const value_aligned: u32 = @as(u32, value) << (@as(u5, byte_bias) * 8);
    const byte_mask: u4 = @as(u4, 0b1) << byte_bias;
    try self.writeAligned(addr_aligned, value_aligned, byte_mask);
}

pub fn writeHalfWord(self: *Self, addr: u32, value: u16) AccessError!void {
    const byte_bias: u2 = @as(u2, @truncate(addr)) & 0b11;
    if (byte_bias == 0b11) {
        return AccessError.AddrNotAligned;
    }
    const addr_aligned: u30 = @truncate(addr >> 2);
    const value_aligned: u32 = @as(u32, value) << (@as(u5, byte_bias) * 8);
    const byte_mask: u4 = @as(u4, 0b11) << byte_bias;
    try self.writeAligned(addr_aligned, value_aligned, byte_mask);
}

pub fn writeWord(self: *Self, addr: u32, value: u32) AccessError!void {
    if (@as(u2, @truncate(addr)) & 0b11 != 0) {
        return AccessError.AddrNotAligned;
    }
    const addr_aligned: u30 = @truncate(addr >> 2);
    return self.writeAligned(addr_aligned, value, 0b1111);
}

fn writeAligned(self: *const Self, addr_aligned: u30, value: u32, byte_mask: u4) AccessError!void {
    const block = loop: for (self.memory_block_list.items) |v| {
        if (v.contains(addr_aligned)) {
            break :loop v;
        }
    } else {
        return AccessError.AddrOutOfRange;
    };
    if (block.write_handle == null) {
        return AccessError.NoWritePermission;
    }
    return @errorCast(block.writeAligned(addr_aligned - block.start_addr, value, byte_mask));
}

fn ensureNotOverlapping(self: *const Self, block: MemoryBlock) bool {
    const bstart = block.start_addr & 0x3fff_fffc;
    const bend = (block.start_addr + block.len + 3) & 0x3fff_fffc;
    return loop: for (self.memory_block_list.items) |v| {
        const astart = v.start_addr & 0x3fff_fffc;
        const aend = (v.start_addr + v.len + 3) & 0x3fff_fffc;
        if (bstart >= aend or bend <= astart) {
            continue;
        } else {
            break :loop false;
        }
    } else true;
}

pub const AccessError = error{
    AddrNotAligned,
    AddrOutOfRange,
    NoWritePermission,
};

pub const MemoryBlockError = error{AddrRangeOverlapped};

const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const MemoryBlockList = ArrayList(MemoryBlock);

const color = @import("misc").color;
