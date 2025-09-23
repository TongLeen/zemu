points: PointList,
allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{
        .points = .empty,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    for (self.points.items) |*point| {
        point.expr.deinit();
    }
    self.points.deinit(self.allocator);
}

pub fn add(self: *Self, expr: []const u8, monitor: *const Monitor) eblk: {
    break :eblk Expression.ParseError || Memory.AccessError || Allocator.Error;
}!void {
    var e = Expression.init(self.allocator);
    try e.parse(expr);
    try self.points.append(
        self.allocator,
        .{
            .enabled = true,
            .expr = e,
            .last_value = try e.calculate(monitor),
        },
    );
}

pub fn del(self: *Self, index: usize) Error!void {
    if (index >= self.points.items.len) {
        return Error.IndexOutOfRange;
    }
    var removed = self.points.orderedRemove(index);
    removed.expr.deinit();
}

pub fn print(self: Self) void {
    p("WatchPoint: {}\n", .{self.points.items.len});
    p(" E  Index\tExpression\n", .{});
    for (self.points.items, 0..) |point, i| {
        const en: u8 = if (point.enabled) '*' else ' ';
        p(
            "[{c}] #{d:<3}\t'{s}'\n",
            .{ en, i, point.expr.origin_str.? },
        );
    }
    p("-------------\n", .{});
}

pub const Error = error{IndexOutOfRange};

const Point = struct {
    enabled: bool,
    expr: Expression,
    last_value: u32,
};

const Self = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const p = std.debug.print;

const core = @import("core");
const Memory = core.Memory;

const Monitor = @import("Monitor.zig");
const Expression = @import("Expression.zig");

const PointList = ArrayList(Point);

test "WatchPoint" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    var wp = Self.init(a);

    try wp.add("12*5"[0..]);
    wp.print();
}
