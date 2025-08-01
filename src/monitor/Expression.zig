origin_str: ?[]u8,
root_node: ?*ExprNode,
allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{
        .origin_str = null,
        .root_node = null,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    if (self.origin_str) |s| {
        self.allocator.free(s);
        self.origin_str = null;
    }
    self.destroyTree();
}

pub fn parse(self: *Self, s: []const u8) (ParseError || Allocator.Error)!void {
    if (self.origin_str != null) {
        self.allocator.free(self.origin_str.?);
        self.origin_str = null;
        self.destroyTree();
    }
    self.origin_str = try self.allocator.alloc(u8, s.len);
    errdefer {
        self.allocator.free(self.origin_str.?);
        self.origin_str = null;
        self.destroyTree();
    }

    std.mem.copyForwards(u8, self.origin_str.?, s);

    const items = try self.split(s);
    defer self.allocator.free(items);
    try self.buildTree(items);
}

pub fn show(self: *const Self) void {
    if (self.root_node == null) return;

    var this_node: *ExprNode = self.root_node.?;
    var level: u32 = 0;
    while (true) {
        if (level > 0) {
            var tnode = this_node;

            // alloc stack for reverse
            const stack: []bool = self.allocator.alloc(bool, level) catch {
                panic(color.err(.{"Show tree failed."}), .{});
            };
            defer self.allocator.free(stack);

            // use stack to reverse parent is/not right-child
            //if is not right-child, corresponding level should print '|'
            var stack_ptr: usize = 0;
            for (0..level - 1) |_| {
                tnode = tnode.parent.?;
                if (tnode == tnode.parent.?.left) {
                    stack[stack_ptr] = true;
                } else {
                    stack[stack_ptr] = false;
                }
                stack_ptr += 1;
            }
            for (0..level - 1) |_| {
                stack_ptr -= 1;
                if (stack[stack_ptr]) {
                    p("  │\t", .{});
                } else {
                    p("\t", .{});
                }
            }
            // mark right-child with '>'
            if (this_node == this_node.parent.?.right) {
                p("  └────\t", .{});
            } else {
                p("  ├────\t", .{});
            }
        }
        p("{}\n", .{this_node.item});
        // fall in
        if (this_node.left != null) {
            this_node = this_node.left.?;
            level += 1;
            continue;
        }
        // fall in
        if (this_node.right != null) {
            this_node = this_node.right.?;
            level += 1;
            continue;
        }

        // prepare to jump out
        // check if reach the root node, then return
        if (this_node == self.root_node) return;
        // if this_node is left node
        // meaning right child node has not been printed
        // jump to right child
        if (this_node == this_node.parent.?.left) {
            this_node = this_node.parent.?.right.?;
            continue;
        }
        // if this_node is right node
        // meaning this node's parent's children all printed
        // jump to upper level
        while (this_node != self.root_node and this_node == this_node.parent.?.right) {
            this_node = this_node.parent.?;
            level -= 1;
        }
        // if reach root, meaning all nodes were printed
        if (this_node == self.root_node) return;
        // jump to right child node
        this_node = this_node.parent.?.right.?;
    }
}

pub fn calculate(self: *const Self, m: *const Monitor) Memory.AccessError!u32 {
    return self.root_node.?.calculate(m);
}

pub const SplitError = error{
    InvalidCharacter,
    InvalidNumber,
    InvalidRegName,
};

pub const BuildTreeError = error{
    EmptyRightOperand,
    ParenthesesNotMatch,
    RedundantOperand,
};

pub const ParseError = SplitError || BuildTreeError;

fn buildTree(self: *Self, items: []ExprItem) (BuildTreeError || Allocator.Error)!void {
    self.destroyTree();
    errdefer self.destroyTree();

    if (items.len == 0) return;

    // init the root node by first item
    var this_node = try ExprNode.new(self.allocator, items[0]);

    self.root_node = this_node;

    for_loop: for (1..items.len) |i| {
        // check right parenthesis:
        // reverse and find left parenthesis
        // if not found, meaning not match
        // if found, move pointer 'this_node' to node 'lparen'
        if (items[i] == .op and items[i].op == .rparen) {
            if (this_node.item.isOperator() and this_node.right == null) {
                return BuildTreeError.EmptyRightOperand;
            }
            while (this_node.item != .op or this_node.item.op != .lparen) {
                if (this_node == self.root_node) {
                    return BuildTreeError.ParenthesesNotMatch;
                }
                this_node = this_node.parent.?;
            }
            continue :for_loop;
        }

        const new_node = try ExprNode.new(self.allocator, items[i]);

        // if this_node is a operator and its right child is null,
        // check if new node is not a binary operator
        // a binary operator cannot appear when right child is empty
        if (this_node.item.isOperator() and this_node.right == null) {
            if (new_node.item.isBinaryOperator()) {
                return BuildTreeError.EmptyRightOperand;
            }
            new_node.parent = this_node;
            this_node.right = new_node;
            this_node = new_node;
            continue :for_loop;
        }

        // here this_node must be a num, a reg or a binary operator that has both left child and right child
        // here new node must be a binary operator
        if (!new_node.item.isBinaryOperator()) {
            return BuildTreeError.RedundantOperand;
        }
        // find a node that is less prior than new node, or reach root node or 'lparen'
        while (!new_node.item.isPrior(this_node.item) and this_node != self.root_node and !(this_node.parent.?.item == .op and this_node.parent.?.item.op == .lparen)) {
            this_node = this_node.parent.?;
        }

        if (new_node.item.isPrior(this_node.item)) {
            const origin_right_child = this_node.right.?;
            // connect origin right child
            new_node.left = origin_right_child;
            origin_right_child.parent = new_node;
            // connect new node to this node
            this_node.right = new_node;
            new_node.parent = this_node;
            // switch this_node
            this_node = new_node;
            continue :for_loop;
        } else if (this_node == self.root_node) {
            // if reached root, then grow a new root
            self.root_node = new_node;
            this_node.parent = new_node;
            new_node.left = this_node;
            this_node = new_node;
            continue :for_loop;
        } else if (this_node.parent.?.item == .op and this_node.parent.?.item.op == .lparen) {
            // if reached parenthesis, stop here
            // it seems like a fake-root
            new_node.parent = this_node.parent;
            new_node.left = this_node;
            new_node.parent.?.right = new_node;
            this_node.parent = new_node;
            this_node = new_node;
        } else {
            unreachable;
        }
    }
}

fn destroyTree(self: *Self) void {
    if (self.root_node == null) return;
    // init pointer by root
    var this_node: *ExprNode = self.root_node.?;
    while (true) {
        // if has any child, the fall in
        if (this_node.left) |v| {
            this_node = v;
            continue;
        }
        // if has any child, the fall in
        if (this_node.right) |v| {
            this_node = v;
            continue;
        }
        // if code come here, means this node has no child
        // check which side this node in parent
        // delete this node from parent and free memory
        // finally jump to parent
        if (this_node.parent) |v| {
            if (v.left == this_node) v.left = null;
            if (v.right == this_node) v.right = null;
            self.allocator.destroy(this_node);
            this_node = v;
        } else {
            // reach root node
            // free and reset self.root_node
            self.allocator.destroy(this_node);
            self.root_node = null;
            return;
        }
    }
}

const ExprItem = union(enum) {
    num: u32,
    op: enum { eq, add, sub, mul, dev, lparen, rparen, neg, deref },
    reg: u6,

    inline fn isBinaryOperator(e: ExprItem) bool {
        return (e == .op and (e.op == .eq or e.op == .add or e.op == .sub or e.op == .mul or e.op == .dev));
    }
    inline fn isUnaryOperator(e: ExprItem) bool {
        return (e == .op and (e.op == .deref or e.op == .neg or e.op == .lparen));
    }
    inline fn isOperator(e: ExprItem) bool {
        return e == .op;
    }

    inline fn getPriority(e: ExprItem) u8 {
        return switch (e) {
            .num => 255,
            .reg => 255,
            .op => |o| switch (o) {
                .eq => 1,
                .add => 3,
                .sub => 3,
                .mul => 5,
                .dev => 5,
                .neg => 10,
                .deref => 11,
                .lparen => 254,
                .rparen => 0,
            },
        };
    }
    inline fn isPrior(e1: ExprItem, e2: ExprItem) bool {
        const p1 = e1.getPriority();
        const p2 = e2.getPriority();
        return p1 > p2;
    }

    /// ExprItem fmt interface.
    /// Args 'fmt' and 'options' were ignored
    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: Writer) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .num => {
                try writer.print("{}", .{self.num});
            },
            .op => |t| {
                try writer.print("({s})", .{@tagName(t)});
            },
            .reg => |t| {
                try writer.print("[x{}]", .{t});
            },
        }
    }
};

/// covert string to tokens (ExprItem)
fn split(self: *const Self, s: []const u8) (SplitError || Allocator.Error)![]ExprItem {
    const ExprItemList = List(ExprItem);
    var list = ExprItemList.init(self.allocator);
    defer list.deinit();

    var i: usize = 0;

    while (true) {
        if (i == s.len) break;
        if (isBlank(s[i])) {
            i += 1;
            continue;
        }
        // parse operator
        // assume that operator contains only 1 character
        // '*' and '-' at head or behind operator(except ')') are considered as unary operator
        if (isOp(s[i])) {
            try list.append(.{ .op = switch (s[i]) {
                '=' => .eq,
                '+' => .add,
                '-' => blk: {
                    const last = list.getLastOrNull();
                    if (last == null or (last.? == .op and last.?.op != .rparen)) {
                        break :blk .neg;
                    } else {
                        break :blk .sub;
                    }
                },
                '*' => blk: {
                    const last = list.getLastOrNull();
                    if (last == null or (last.? == .op and last.?.op != .rparen)) {
                        break :blk .deref;
                    } else {
                        break :blk .mul;
                    }
                },
                '/' => .dev,
                '(' => .lparen,
                ')' => .rparen,
                else => unreachable,
            } });

            i += 1;
            continue;
        }
        // reg_name starts with '$'
        // name stops when no alphabet or number char occurs
        // then match name and convert to u6
        // x0~x31 -> 0~31
        // pc -> 32
        if (s[i] == '$') {
            const end = loop: for (i + 1..s.len) |j| {
                if (!utils.isAlphaOrNum(s[j])) break :loop j;
            } else {
                break :loop s.len;
            };
            const reg_name = s[i + 1 .. end];
            try list.append(.{
                .reg = blk: {
                    if (isStrEqu(reg_name, "x0")) break :blk 0;
                    if (isStrEqu(reg_name, "x1")) break :blk 1;
                    if (isStrEqu(reg_name, "x2")) break :blk 2;
                    if (isStrEqu(reg_name, "x3")) break :blk 3;
                    if (isStrEqu(reg_name, "x4")) break :blk 4;
                    if (isStrEqu(reg_name, "x5")) break :blk 5;
                    if (isStrEqu(reg_name, "x6")) break :blk 6;
                    if (isStrEqu(reg_name, "x7")) break :blk 7;
                    if (isStrEqu(reg_name, "x8")) break :blk 8;
                    if (isStrEqu(reg_name, "x9")) break :blk 9;
                    if (isStrEqu(reg_name, "x10")) break :blk 10;
                    if (isStrEqu(reg_name, "x11")) break :blk 11;
                    if (isStrEqu(reg_name, "x12")) break :blk 12;
                    if (isStrEqu(reg_name, "x13")) break :blk 13;
                    if (isStrEqu(reg_name, "x14")) break :blk 14;
                    if (isStrEqu(reg_name, "x15")) break :blk 15;
                    if (isStrEqu(reg_name, "x16")) break :blk 16;
                    if (isStrEqu(reg_name, "x17")) break :blk 17;
                    if (isStrEqu(reg_name, "x18")) break :blk 18;
                    if (isStrEqu(reg_name, "x19")) break :blk 19;
                    if (isStrEqu(reg_name, "x20")) break :blk 20;
                    if (isStrEqu(reg_name, "x21")) break :blk 21;
                    if (isStrEqu(reg_name, "x22")) break :blk 22;
                    if (isStrEqu(reg_name, "x23")) break :blk 23;
                    if (isStrEqu(reg_name, "x24")) break :blk 24;
                    if (isStrEqu(reg_name, "x25")) break :blk 25;
                    if (isStrEqu(reg_name, "x26")) break :blk 26;
                    if (isStrEqu(reg_name, "x27")) break :blk 27;
                    if (isStrEqu(reg_name, "x28")) break :blk 28;
                    if (isStrEqu(reg_name, "x29")) break :blk 29;
                    if (isStrEqu(reg_name, "x30")) break :blk 30;
                    if (isStrEqu(reg_name, "x31")) break :blk 31;

                    if (isStrEqu(reg_name, "zero")) break :blk 0;
                    if (isStrEqu(reg_name, "ra")) break :blk 1;
                    if (isStrEqu(reg_name, "sp")) break :blk 2;
                    if (isStrEqu(reg_name, "gp")) break :blk 3;
                    if (isStrEqu(reg_name, "tp")) break :blk 4;
                    if (isStrEqu(reg_name, "t0")) break :blk 5;
                    if (isStrEqu(reg_name, "t1")) break :blk 6;
                    if (isStrEqu(reg_name, "t2")) break :blk 7;
                    if (isStrEqu(reg_name, "s0")) break :blk 8;
                    if (isStrEqu(reg_name, "fp")) break :blk 8;
                    if (isStrEqu(reg_name, "s1")) break :blk 9;
                    if (isStrEqu(reg_name, "a0")) break :blk 10;
                    if (isStrEqu(reg_name, "a1")) break :blk 11;
                    if (isStrEqu(reg_name, "a2")) break :blk 12;
                    if (isStrEqu(reg_name, "a3")) break :blk 13;
                    if (isStrEqu(reg_name, "a4")) break :blk 14;
                    if (isStrEqu(reg_name, "a5")) break :blk 15;
                    if (isStrEqu(reg_name, "a6")) break :blk 16;
                    if (isStrEqu(reg_name, "a7")) break :blk 17;
                    if (isStrEqu(reg_name, "s2")) break :blk 18;
                    if (isStrEqu(reg_name, "s3")) break :blk 19;
                    if (isStrEqu(reg_name, "s4")) break :blk 20;
                    if (isStrEqu(reg_name, "s5")) break :blk 21;
                    if (isStrEqu(reg_name, "s6")) break :blk 22;
                    if (isStrEqu(reg_name, "s7")) break :blk 23;
                    if (isStrEqu(reg_name, "s8")) break :blk 24;
                    if (isStrEqu(reg_name, "s9")) break :blk 25;
                    if (isStrEqu(reg_name, "s10")) break :blk 26;
                    if (isStrEqu(reg_name, "s11")) break :blk 27;
                    if (isStrEqu(reg_name, "t3")) break :blk 28;
                    if (isStrEqu(reg_name, "t4")) break :blk 29;
                    if (isStrEqu(reg_name, "t5")) break :blk 30;
                    if (isStrEqu(reg_name, "t6")) break :blk 31;

                    if (isStrEqu(reg_name, "pc")) break :blk 32;

                    return SplitError.InvalidRegName;
                },
            });
            i = end;
            continue;
        }
        if (isDecNum(s[i])) {
            const end = loop: for (i..s.len) |j| {
                if (isBlank(s[j]) or isOp(s[j])) break :loop j;
            } else {
                break :loop s.len;
            };
            try list.append(.{ .num = parseInt(u32, s[i..end], 0) catch {
                return SplitError.InvalidNumber;
            } });
            i = end;
            continue;
        }
        p(color.err(.{"Invalid character: '{c}'\n"}), .{s[i]});
        return SplitError.InvalidCharacter;
    }

    // copy the content of list
    // list will be deinit by 'defer'
    const retval = try self.allocator.alloc(ExprItem, list.items.len);
    for (retval, list.items) |*d, v| {
        d.* = v;
    }
    return retval;
}

const ExprNode = struct {
    item: ExprItem,
    parent: ?*ExprNode,
    left: ?*ExprNode,
    right: ?*ExprNode,

    pub fn new(allocator: Allocator, item: ExprItem) Allocator.Error!*@This() {
        const retval = try allocator.create(@This());
        retval.* = .{
            .item = item,
            .parent = null,
            .left = null,
            .right = null,
        };
        return retval;
    }

    pub fn calculate(self: *const @This(), ctx: *const Monitor) Memory.AccessError!u32 {
        switch (self.item) {
            .num => |v| {
                return v;
            },
            .reg => |r| {
                return ctx.readReg(r);
            },
            .op => |op| {
                const left = self.left;
                const right = self.right;
                return switch (op) {
                    .eq => @intFromBool(try left.?.calculate(ctx) == try right.?.calculate(ctx)),
                    .add => try left.?.calculate(ctx) +% try right.?.calculate(ctx),
                    .sub => try left.?.calculate(ctx) -% try right.?.calculate(ctx),
                    .mul => try left.?.calculate(ctx) * try right.?.calculate(ctx),
                    .dev => try left.?.calculate(ctx) / try right.?.calculate(ctx),
                    .deref => try ctx.readMemWord(try right.?.calculate(ctx)),
                    .neg => ~(try right.?.calculate(ctx)) +% 1,
                    .lparen => try right.?.calculate(ctx),
                    else => unreachable,
                };
            },
        }
    }
};

const Self = @This();
const std = @import("std");
const p = std.debug.print;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const Writer = std.io.AnyWriter;
const List = std.ArrayList;
const parseInt = std.fmt.parseInt;

const core = @import("core");
const Memory = core.Memory;

const monitor = @import("root.zig");
const Monitor = monitor.Monitor;
const color = @import("misc").color;
const utils = @import("utils.zig");
const isBlank = utils.isBlank;
const isOp = utils.isOp;
const isDecNum = utils.isDecNum;
const isStrEqu = utils.isStrEqu;
