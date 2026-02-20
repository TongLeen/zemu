pub fn zemu_main(allocator: Allocator, img: []const u8) !void {
    // RAM 16MiB
    var ram = try Ram.init(allocator, 0x100_0000);
    defer ram.deinit();
    const img_dst: []u8 = @as([*]u8, @ptrCast(ram.raw.ptr))[0..img.len];
    std.mem.copyForwards(u8, img_dst, img);

    // UART
    var uart = Uart.init();
    defer uart.deinit();

    var memorys = [_]MemoryBlock{
        ram.toMemoryBlock(0x2000_0000),
        uart.toMemoryBlock(0x9000_0000),
    };

    var cpu = Cpu.init(memorys[0..], 0x2000_0000);

    var m = Monitor.init(&cpu, allocator);
    defer m.deinit();

    cpu.restart();
    m.startLoop();
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const core = @import("core");
const Cpu = core.Cpu;
const MemoryBlock = core.Memory.MemoryBlock;

const io = @import("io");
const Ram = io.Ram;
const Uart = io.Uart;

const monitor = @import("monitor");
const Monitor = monitor.Monitor;
