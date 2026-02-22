raw: []u32,
allocator: Allocator,

pub fn init(allocator: Allocator, size: usize) RamError!Self {
    const size_u32 = (size + 3) / 4;
    const raw = try allocator.alloc(u32, size_u32);
    return .{
        .raw = raw,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.raw);
}

pub fn read(self: *const Self, addr: u30) RamError!u32 {
    if (addr >= self.raw.len) {
        return RamError.AddrOutOfRange;
    }
    return self.raw[addr];
}

pub fn write(self: *const Self, addr: u30, value: u32, byte_mask: u4) RamError!void {
    if (addr >= self.raw.len) {
        return RamError.AddrOutOfRange;
    }
    const dst: [*]u8 = @ptrCast(&self.raw[addr]);
    for (0..4) |i| {
        if (byte_mask & (@as(u32, 1) << @as(u5, @truncate(i))) != 0) {
            dst[i] = @truncate(value >> (@as(u5, @truncate(i))) * 8);
        }
    }
}

pub fn toMemoryBlock(
    self: *const Self,
    start_addr: u32,
    mode: Mode,
) MemoryBlock {
    if ((start_addr & 0b11) != 0) {
        @panic("Address of 'start' not aligned 4.");
    }
    return .{
        .context = @ptrCast(self),
        .read_handle = typeErasedRead,
        .write_handle = switch (mode) {
            .ReadWrite => typeErasedWrite,
            .ReadOnly => null,
        },
        .start_addr = @truncate(start_addr >> 2),
        .len = @truncate(self.raw.len),
    };
}

fn typeErasedRead(context: *const anyopaque, addr: u30, byte_mask: u4) anyerror!u32 {
    _ = byte_mask;
    const ptr: *const Self = @ptrCast(@alignCast(context));
    return read(ptr, addr);
}

fn typeErasedWrite(context: *const anyopaque, addr: u30, value: u32, byte_mask: u4) anyerror!void {
    const ptr: *const Self = @ptrCast(@alignCast(context));
    return write(ptr, addr, value, byte_mask);
}

pub const RamError = error{
    AddrNotAligned,
    AddrOutOfRange,
} || Allocator.Error;

pub const Mode = enum {
    ReadOnly,
    ReadWrite,
};

const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;

const core = @import("core");
const MemoryBlock = core.MemoryBlock;

test "Ram test" {
    const print = std.debug.print;
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    var ram = try Self.init(allocator, 16);
    try ram.write(0, 0xf0f0f0f0, 0b1000);
    try ram.write(1, 0xf0f0f0f0, 0b0011);
    try ram.write(2, 0xf0f0f0f0, 0b0101);
    try ram.write(3, 0xf0f0f0f0, 0b0001);
    print("{d}", .{ram.raw.len});
    print("{x}", .{ram.raw});
}
