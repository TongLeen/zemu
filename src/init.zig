pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            p("Memory Leak\n", .{});
        }
    }

    const bin_file_path = getBinFilePath(allocator) catch |e| {
        p("Argument error: {any}\n", .{e});
        return;
    };
    defer allocator.free(bin_file_path);

    var file = try fs.cwd().openFile(bin_file_path, .{ .mode = .read_only });
    defer file.close();

    const file_length = try file.getEndPos();
    const img = try allocator.alloc(u8, file_length);
    defer allocator.free(img);

    const readed_length = try file.readAll(img);
    if (readed_length != file_length) {
        @panic("Read img file failed.");
    }

    const zemu = @import("zemu-main.zig").zemu_main;
    try zemu(allocator, img);
}

pub fn getBinFilePath(a: Allocator) ![]u8 {
    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    if (args.len == 1) {
        p("need 1 argument: bin file.\n", .{});
        return error.TooFewArgs;
    } else if (args.len != 2) {
        p("too many arguments given:{d}.\n", .{args.len});
        return error.TooManyArgs;
    }
    const bin_file_path = args[1];
    const retval: []u8 = try a.alloc(u8, bin_file_path.len);
    std.mem.copyForwards(u8, retval, bin_file_path[0..bin_file_path.len]);
    return retval[0..bin_file_path.len];
}

const std = @import("std");
const p = std.debug.print;
const Allocator = std.mem.Allocator;
const fs = std.fs;
