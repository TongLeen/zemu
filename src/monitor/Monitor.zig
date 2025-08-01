cpu: *Cpu,
allocator: Allocator,
watchpoint: WatchPoint,
status: Status,
cli: Cli,

pub fn init(cpu: *Cpu, allocator: Allocator) Self {
    return .{
        .cpu = cpu,
        .allocator = allocator,
        .watchpoint = .init(allocator),
        .status = .stopped,
        .cli = .init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.watchpoint.deinit();
    self.cli.deinit();
}

pub fn startLoop(self: *Self) void {
    self.status = .paused;
    var step_cnt: usize = undefined;

    while (true) {
        // try to run 1 step
        // check watchpoints
        const step_result = switch (self.status) {
            .running => self.step(false),
            .stepping => blk: {
                if (step_cnt == 0) {
                    self.status = .paused;
                    break :blk StepResult{};
                } else {
                    step_cnt -= 1;
                    break :blk self.step(true);
                }
            },
            .stopped, .paused => StepResult{},
        };

        // update status
        if (step_result.is_no_empty) {
            self.status = step_result.new_status orelse self.status;
        }

        if (!(self.status == .paused or self.status == .stopped)) {
            continue;
        }

        // parse input
        const cli_cmd = self.cli.get("(zemu) ") catch |e| switch (e) {
            Cli.Error.InvalidCmd,
            Cli.Error.InvalidSubcmd,
            Cli.Error.TooFewArgs,
            Cli.Error.TooManyArgs,
            => {
                p(color.err(.{"Cmd: Syntax error: '{s}'.\n"}), .{@errorName(e)});
                p(color.info(.{"Enter 'help' to get cmd list and usage.\n"}), .{});
                continue;
            },

            Cli.Error.InvalidCharacter,
            Cli.Error.Overflow,
            => {
                p(color.err(.{"Cmd: Parse integer failed: '{s}'.\n"}), .{@errorName(e)});
                continue;
            },

            Allocator.Error.OutOfMemory => {
                panic(color.err(.{"Out of memory when parsing input.\n"}), .{});
            },
        };
        defer self.cli.ret(cli_cmd);

        // execute the cmd
        (swt: switch (cli_cmd.cmd) {
            .help => {
                p(help_doc, .{});
            },
            .q => {
                return;
            },
            .r => {
                self.status = .paused;
                self.cpu.restart();
            },

            .c => {
                if (self.status != .paused) {
                    p(color.warn(.{"Cannot continue to run. Status is '{s}'.\n"}), .{@tagName(self.status)});
                    p(color.info(.{"Enter 'r' to restart.\n"}), .{});
                    continue;
                }
                self.status = .running;
            },
            .si => |n| {
                if (self.status != .paused) {
                    p(color.warn(.{"Cannot step in. Status is '{s}'.\n"}), .{@tagName(self.status)});
                    p(color.info(.{"Enter 'r' to restart.\n"}), .{});
                    continue;
                }
                self.status = .stepping;
                step_cnt = n;
            },

            .info => |sub| {
                self.info(sub);
            },
            .x => |args| {
                var e = Expression.init(self.allocator);
                defer e.deinit();
                e.parse(args.expr) catch |err| {
                    break :swt err;
                };
                const base = e.calculate(self) catch |err| {
                    break :swt err;
                };
                for (0..args.num) |offset| {
                    const data = self.readMemByte(base +% @as(u32, @truncate(offset))) catch |err| {
                        break :swt err;
                    };
                    p("{x} ", .{data});
                }
                p("\n", .{});
            },
            .p => |expr| {
                var e = Expression.init(self.allocator);
                defer e.deinit();
                e.parse(expr) catch |err| {
                    break :swt err;
                };
                const result = e.calculate(self) catch |err| {
                    break :swt err;
                };
                p("0x{x:0>8}({d})\n", .{ result, result });
            },

            .w => |expr| {
                self.watchpoint.add(expr, self) catch |err| {
                    break :swt err;
                };
            },
            .d => |index| {
                self.watchpoint.del(index) catch |err| {
                    break :swt err;
                };
            },
            .empty => {
                continue;
            },
        }) catch |e| {
            p(color.err(.{"{s}\n"}), .{@errorName(e)});
            continue;
        };
    }
}

pub fn readReg(self: *const Self, reg_num: u6) u32 {
    if (reg_num < 32) {
        return self.cpu.regs.read(@truncate(reg_num));
    } else {
        switch (reg_num) {
            32 => {
                return self.cpu.pc;
            },
            else => unreachable,
        }
    }
}

pub fn readMemByte(self: *const Self, addr: u32) core.Memory.AccessError!u8 {
    return self.cpu.mem.readByte(addr);
}
pub fn readMemWord(self: *const Self, addr: u32) core.Memory.AccessError!u32 {
    return self.cpu.mem.readWord(addr);
}

fn step(self: *Self, show_inst: bool) StepResult {
    var result = StepResult{};
    self.cpu.tick(show_inst) catch |e| switch (e) {
        Cpu.Error.Ebreak => {
            // caution!
            // this is not what real machine do
            result.is_no_empty = true;
            result.new_status = if (self.cpu.readReg(17) == 255) .stopped else .paused;
            if (result.new_status == .stopped) {
                p(color.info(.{"Program reach end.\n"}), .{});
            }
        },
    };

    if (self.checkWatchPoints()) |v| {
        if (v) {
            result.is_no_empty = true;
            result.new_status = .paused;
        }
    } else |e| {
        p(color.err(.{"CheckWatchPoint: MemoryAccessError: {s}\n"}), .{@errorName(e)});
    }
    return result;
}

fn info(self: *const Self, subcmd: Cli.CmdInfoSubcmd) void {
    switch (subcmd) {
        .r,
        .csr,
        => {
            p(color.info(.{"Waiting for impl..\n"}), .{});
        },
        .w => {
            self.watchpoint.print();
        },
        .status => {
            p("{s}\n", .{@tagName(self.status)});
        },
        .mode => {
            p("{s}\n", .{@tagName(self.cpu.mode)});
        },
    }
}

fn checkWatchPoints(self: *const Self) core.Memory.AccessError!bool {
    var reach_watchpoint: bool = false;
    for (self.watchpoint.points.items, 0..) |*point, i| {
        if (point.enabled) {
            const new_v = try point.expr.calculate(self);
            if (new_v != point.last_value) {
                p(
                    color.info(.{"{x:0>8}\tWP #{d} ('{s}'):\t0x{x:0>8}({d}) -> 0x{x:0>8}({d})\n"}),
                    .{ self.cpu.pc, i, point.expr.origin_str.?, point.last_value, point.last_value, new_v, new_v },
                );
                point.last_value = new_v;
                reach_watchpoint = true;
            }
        }
    }
    return reach_watchpoint;
}

const Status = enum { running, stepping, stopped, paused };

const StepResult = struct {
    is_no_empty: bool = false,
    new_status: ?Status = null,
};

const help_doc =
    \\
    \\Avalibale cmds:
    \\   help   - print this help
    \\   c      - continue to run
    \\   r      - restart and pause
    \\   q      - quit
    \\
    \\   si [n]
    \\      - step in 'n' steps
    \\      - if 'n' is not given, defalut is '1'
    \\   
    \\   info <subcmd>
    \\      - print information refered by <subcmd>
    \\      - <subcmd>: 
    \\          r : regs' value
    \\          w : watchpoints
    \\
    \\   x <n> <addr_base>
    \\      - scan memory(byte) from <addr_base> to <addr_base>+<n>
    \\
    \\   p <expr>
    \\      - eval <expr> and print result
    \\
    \\   w <expr>
    \\      - add a watchpoint
    \\      - if result of <expr> changed, pause
    \\
    \\   d <index>
    \\      - delete watchpoint of <index>
    \\
    \\Expression(expr):
    \\   support operators:
    \\      - '='   equal
    \\      - '+'   add
    \\      - '-'   subtraction/negative
    \\      - '*'   multiply/dereference
    \\      - '/'   devide
    \\      - '()'  parentheses
    \\
    \\
;

const Self = @This();
const std = @import("std");
const p = std.debug.print;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const core = @import("core");
const Cpu = core.Cpu;

const misc = @import("misc");
const color = misc.color;

const monitor = @import("root.zig");
const WatchPoint = monitor.WatchPoint;
const Expression = monitor.Expression;
const Cli = monitor.Cli;
const utils = monitor.utils;
