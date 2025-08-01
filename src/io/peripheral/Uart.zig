rx_buffer: *RingBuffer,
allocator: Allocator,

pub fn init(allocator: Allocator, buffer_size: usize) Allocator.Error!Self {
    const p = try allocator.create(RingBuffer);
    p.* = try RingBuffer.init(allocator, buffer_size);
    return .{
        .rx_buffer = p,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.rx_buffer.deinit(self.allocator);
    self.allocator.destroy(self.rx_buffer);
}

pub fn read(self: *const Self, byte_mask: u4) u32 {
    _ = self;
    if (byte_mask & 1 == 0) {
        return 0;
    }
    return std.io.getStdIn().reader().readByte() catch {
        @panic("Stdin read error.\n");
    };
}

pub fn write(self: *const Self, value: u32, byte_mask: u4) void {
    _ = self;
    if (byte_mask & 1 == 0) {
        return;
    }
    std.debug.print("{c}", .{@as(u8, @truncate(value))});
}

pub fn toMemoryBlock(self: *const Self, start_addr: u32) Error!MemoryBlock {
    if ((start_addr & 0b11) != 0) {
        return Error.AddrNotAligned;
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
    const ptr: *const Self = @alignCast(@ptrCast(context));
    return read(ptr, byte_mask);
}

fn typeErasedWrite(context: *const anyopaque, addr: u30, value: u32, byte_mask: u4) anyerror!void {
    _ = addr;
    const ptr: *const Self = @alignCast(@ptrCast(context));
    return write(ptr, @truncate(value), byte_mask);
}

const Self = @This();
const std = @import("std");
const RingBuffer = std.RingBuffer;
const Allocator = std.mem.Allocator;

const core = @import("core");
const MemoryBlock = core.MemoryBlock;
