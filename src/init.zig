pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const arena = init.arena;
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena.allocator());
    if (args.len != 2) {
        p("Only 1 argument is expected.", .{});
        return;
    }

    const bin_file_path = args[1];

    const content = try Io.Dir.readFileAlloc(
        Io.Dir.cwd(),
        io,
        bin_file_path,
        gpa,
        .unlimited,
    );
    defer gpa.free(content);

    const zemu = @import("zemu-main.zig").zemu_main;
    try zemu(gpa, content);
}

const std = @import("std");
const p = std.debug.print;
const Allocator = std.mem.Allocator;
const Io = std.Io;
