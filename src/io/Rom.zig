raw: []u32,
allocator: Allocator,

pub fn init(allocator: Allocator, src_file: [*:0]const u8) RomInitError!Self {
    const file = try std.fs.cwd().openFileZ(src_file, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();

    if (file_size % 4 != 0) {
        return RomInitError.ExecSizeNotAligned;
    }
    const inst_num = file_size / 4;

    const raw = try allocator.alloc(u32, inst_num);
    const buffer = @as([*]u8, @ptrCast(raw.ptr))[0..file_size];
    const readed_size = try file.readAll(buffer);
    assert(readed_size == file_size);

    return .{
        .raw = raw,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.raw);
}

pub fn read(self: *const Self, i: u30) RomError!u32 {
    if (i >= self.raw.len) {
        return RomError.AddrOutOfRange;
    }
    return self.raw[i];
}

pub fn toMemoryBlock(self: *const Self, start_addr: u32) RomError!MemoryBlock {
    if (start_addr & 0b11 != 0 or self.raw.len & 0b11 != 0) {
        return RomError.AddrNotAligned;
    }
    return .{
        .context = @ptrCast(self),
        .read_handle = typeErasedRead,
        .write_handle = null,
        .start_addr = @truncate(start_addr >> 2),
        .len = @truncate(self.raw.len),
    };
}

fn typeErasedRead(context: *const anyopaque, addr: u30, byte_mask: u4) anyerror!u32 {
    _ = byte_mask;
    const ptr: *const Self = @alignCast(@ptrCast(context));
    return read(ptr, addr);
}

pub const RomError = error{
    AddrNotAligned,
    AddrOutOfRange,
} || Allocator.Error;

pub const RomInitError = error{
    ExecSizeNotAligned,
} || File.OpenError || File.GetSeekPosError || File.ReadError || Allocator.Error;

const Self = @This();
const std = @import("std");
const File = std.fs.File;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const core = @import("core");
const MemoryBlock = core.MemoryBlock;

test "Rom test" {
    const print = std.debug.print;
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocatr = gpa.allocator();

    var rom = try Self.init(allocatr, "rv.bin");

    const v = try rom.read(0);
    print("{x}\n", .{v});
    print("{x}\n", .{rom.raw});
}
