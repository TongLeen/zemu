history_path: [*c]u8,
allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    _ = clib.rl_bind_key('\t', clib.rl_insert);
    clib.stifle_history(500);
    const home_path = clib.getenv("HOME");
    const sub_path = "/.zemu_monitor_history";
    const total_len = clib.strlen(home_path) + sub_path.len + 1;
    const history_path: [*c]u8 = @ptrCast(clib.malloc(total_len) orelse {
        return .{
            .history_path = 0,
            .allocator = allocator,
        };
    });
    _ = clib.strcpy(history_path, home_path);
    _ = clib.strcat(history_path, sub_path);
    _ = clib.read_history(history_path);
    return .{
        .history_path = history_path,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    if (self.history_path != 0) {
        _ = clib.write_history(self.history_path);
    }
    clib.free(self.history_path);
}

pub fn get(self: *const Self, prompt: [:0]const u8) (Allocator.Error || Error)!CliCmd {
    const line_raw = clib.readline(@ptrCast(prompt.ptr));
    if (line_raw == 0) {
        panic(color.err(.{"Lib 'readline' get input failed.\n"}), .{});
    }
    defer clib.free(line_raw);
    if (line_raw[0] != 0) {
        clib.add_history(line_raw);
    }

    const line_len: usize = clib.strlen(line_raw);
    const line = try self.allocator.alloc(u8, line_len);
    errdefer {
        self.allocator.free(line);
    }

    std.mem.copyForwards(u8, line, line_raw[0..line_len]);
    return .{
        .raw_input = line,
        .cmd = try Cmd.init(line),
    };
}

pub fn ret(self: *const Self, cmd: CliCmd) void {
    self.allocator.free(cmd.raw_input);
}

pub const CliCmd = struct {
    raw_input: []const u8,
    cmd: Cmd,
};

pub const Error = error{} || Cmd.CmdError;

pub const Cmd = union(enum) {
    help: void,
    c: void,
    r: void,
    q: void,
    si: usize,
    info: CmdInfoSubcmd,
    x: struct {
        num: usize,
        expr: []const u8,
    },
    p: []const u8,
    w: []const u8,
    d: usize,
    empty: void,

    pub fn init(s: []const u8) CmdError!@This() {
        const cmd = utils.getWordSlice(s, null);
        if (cmd.len == 0) {
            return .{ .empty = {} };
        }

        if (isStrEqu(cmd, "help")) return .{ .help = {} };
        if (isStrEqu(cmd, "c")) return .{ .c = {} };
        if (isStrEqu(cmd, "r")) return .{ .r = {} };
        if (isStrEqu(cmd, "q")) return .{ .q = {} };
        if (isStrEqu(cmd, "si")) return .{ .si = blk: {
            const a1 = utils.getWordSlice(s, cmd);
            if (a1.len == 0) {
                break :blk 1;
            }
            break :blk try std.fmt.parseInt(usize, a1, 0);
        } };
        if (isStrEqu(cmd, "info")) return .{ .info = blk: {
            const a1 = utils.getWordSlice(s, cmd);
            if (a1.len == 0) return CmdError.TooFewArgs;
            const a2 = utils.getWordSlice(s, a1);
            if (a2.len != 0) return CmdError.TooManyArgs;

            if (isStrEqu(a1, "r")) break :blk .r;
            if (isStrEqu(a1, "w")) break :blk .w;
            if (isStrEqu(a1, "csr")) break :blk .csr;
            if (isStrEqu(a1, "status")) break :blk .status;
            if (isStrEqu(a1, "mode")) break :blk .mode;

            return CmdError.InvalidSubcmd;
        } };
        if (isStrEqu(cmd, "x")) return .{ .x = blk: {
            const a1 = utils.getWordSlice(s, cmd);
            if (a1.len == 0) return CmdError.TooFewArgs;
            const n = try std.fmt.parseInt(usize, a1, 0);
            const a2 = utils.getWordSlice(s, a1);
            if (a2.len == 0) return CmdError.TooFewArgs;
            break :blk .{
                .num = n,
                .expr = s[utils.getSliceEnd(s, a2) - a2.len ..],
            };
        } };
        if (isStrEqu(cmd, "p")) return .{ .p = blk: {
            const a1 = utils.getWordSlice(s, cmd);
            if (a1.len == 0) return CmdError.TooFewArgs;
            break :blk s[utils.getSliceEnd(s, a1) - a1.len ..];
        } };
        if (isStrEqu(cmd, "w")) return .{ .w = blk: {
            const a1 = utils.getWordSlice(s, cmd);
            if (a1.len == 0) return CmdError.TooFewArgs;
            break :blk s[utils.getSliceEnd(s, a1) - a1.len ..];
        } };
        if (isStrEqu(cmd, "d")) return .{ .d = blk: {
            const a1 = utils.getWordSlice(s, cmd);
            if (a1.len == 0) return CmdError.TooFewArgs;
            const index = try std.fmt.parseInt(usize, a1, 0);
            const a2 = utils.getWordSlice(s, a1);
            if (a2.len != 0) return CmdError.TooManyArgs;
            break :blk index;
        } };

        return CmdError.InvalidCmd;
    }

    const CmdError = error{
        InvalidCmd,
        InvalidSubcmd,
        TooFewArgs,
        TooManyArgs,
    } || std.fmt.ParseIntError;
};

pub const CmdInfoSubcmd = enum { r, csr, w, status, mode };

const clib = @cImport({
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
    @cInclude("readline/rlconf.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
});

const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const monitor = @import("root.zig");
const utils = monitor.utils;
const isStrEqu = utils.isStrEqu;

const color = @import("misc").color;
