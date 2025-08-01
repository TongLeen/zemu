pub fn zemu_main(allocator: Allocator, img: []const u8) !void {
    var cpu = try Cpu.init(allocator);
    defer cpu.deinit();
    var m = Monitor.init(&cpu, allocator);
    defer m.deinit();

    // RAM 16MiB
    var ram = try Ram.init(allocator, 0x100_0000);
    defer ram.deinit();
    const img_dst: []u8 = @as([*]u8, @ptrCast(ram.raw.ptr))[0..img.len];
    std.mem.copyForwards(u8, img_dst, img);
    try cpu.addMemoryBlock(try ram.toMemoryBlock(0x8000_0000));

    // UART
    var uart = try Uart.init(allocator, 256);
    defer uart.deinit();
    try cpu.addMemoryBlock(try uart.toMemoryBlock(0x9000_0000));

    cpu.restart();
    m.startLoop();
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const core = @import("core");
const Cpu = core.Cpu;

const io = @import("io");
const Ram = io.Ram;
const Uart = io.Uart;

const monitor = @import("monitor");
const Monitor = monitor.Monitor;
