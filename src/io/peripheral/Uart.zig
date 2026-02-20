pub fn init() Self {
    return .{};
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn read(self: *const Self, byte_mask: u4) u32 {
    _ = self;
    if (byte_mask & 1 == 0) {
        return 0;
    }
    var rbuf: [1]u8 = undefined;
    const rsize = std.fs.File.stdin().read(&rbuf) catch { // TODO: update
        @panic("Stdin read error.\n");
    };
    std.debug.assert(rsize == 1);
    return rbuf[0];
}

pub fn write(self: *const Self, value: u32, byte_mask: u4) void {
    _ = self;
    if (byte_mask & 1 == 0) {
        return;
    }
    std.debug.print("{c}", .{@as(u8, @truncate(value))});
}

pub fn toMemoryBlock(self: *const Self, start_addr: u32) MemoryBlock {
    if ((start_addr & 0b11) != 0) {
        @panic("Address of 'start' not aligned 4.");
    }
    return .{
        .context = @ptrCast(self),
        .read_handle = typeErasedRead,
        .write_handle = typeErasedWrite,
        .start_addr = @truncate(start_addr >> 2),
        .len = 1,
    };
}

pub const Error = error{
    AddrNotAligned,
};

fn typeErasedRead(context: *const anyopaque, addr: u30, byte_mask: u4) anyerror!u32 {
    _ = addr;
    const ptr: *const Self = @ptrCast(@alignCast(context));
    return read(ptr, byte_mask);
}

fn typeErasedWrite(context: *const anyopaque, addr: u30, value: u32, byte_mask: u4) anyerror!void {
    _ = addr;
    const ptr: *const Self = @ptrCast(@alignCast(context));
    return write(ptr, @truncate(value), byte_mask);
}

const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;

const core = @import("core");
const MemoryBlock = core.MemoryBlock;
