pub fn zemu_main(allocator: Allocator, img: []const u8) !void {
    // ROM 16MiB
    var rom = try Ram.init(allocator, 0x100_0000);
    defer rom.deinit();
    const img_dst: []u8 = @as([*]u8, @ptrCast(rom.raw.ptr))[0..img.len];
    std.mem.copyForwards(u8, img_dst, img);

    // RAM 16MiB
    var ram = try Ram.init(allocator, 0x100_0000);
    defer ram.deinit();

    // UART
    var uart = Uart.init();
    defer uart.deinit();

    var memorys = [_]MemoryBlock{
        rom.toMemoryBlock(0x0800_0000, .ReadOnly),
        ram.toMemoryBlock(0x2000_0000, .ReadWrite),
        uart.toMemoryBlock(0x9000_0000),
    };

    const RV32Spec = RV32(
        .{ .C = true },
        0x0800_0000,
    );

    var RV32_CPU = RV32Spec.init(memorys[0..]);
    var cpu = RV32_CPU.cpu();

    var m = Monitor.init(&cpu, allocator);
    defer m.deinit();

    cpu.reset();
    m.startLoop();
}

const std = @import("std");
const Allocator = std.mem.Allocator;

const core = @import("core");
const RV32 = core.isa.Riscv32;
const MemoryBlock = core.Memory.MemoryBlock;

const io = @import("io");
const Rom = io.Rom;
const Ram = io.Ram;
const Uart = io.Uart;

const monitor = @import("monitor");
const Monitor = monitor.Monitor;
