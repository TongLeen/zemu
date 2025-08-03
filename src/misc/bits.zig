pub const BitRange = [2]u16;
pub fn extract(comptime range: BitRange, value: anytype) rtype: {
    if (range[0] < range[1]) {
        @compileError("Bit range msb must >= lsb.\n");
    }
    if (@typeInfo(@TypeOf(value)) != .int) {
        @compileError("Error value type '" ++ @typeName(@TypeOf(value)) ++ "', 'int' expected.\n");
    }
    break :rtype meta.Int(.unsigned, (range[0] - range[1] + 1));
} {
    return @truncate(value >> range[1]);
}

pub fn truncate(comptime dst_type: type, value: anytype) dst_type {
    const di = @typeInfo(dst_type);
    const src_type = @TypeOf(value);
    const si = @typeInfo(src_type);
    comptime {
        if (di != .int) {
            @compileError("Error dst type '" ++ @typeName(dst_type) ++ "', 'int' expected.\n");
        }
        if (si != .int) {
            @compileError("Error value type '" ++ @typeName(src_type) ++ "', 'int' expected.\n");
        }
        if (di.int.bits > si.int.bits) {
            @compileError("Dst type '" ++ @typeName(dst_type) ++ "' has more bits than src type '" ++ @typeName(src_type) ++ "'.\n");
        }
    }
    const us = meta.Int(.unsigned, si.int.bits);
    const ud = meta.Int(.unsigned, di.int.bits);
    const v1: us = @bitCast(value);
    const v2: ud = @truncate(v1);
    return @bitCast(v2);
}

pub fn extendUnsigned(comptime dst_type: type, value: anytype) dst_type {
    return extend(false, dst_type, value);
}

pub fn extendSigned(comptime dst_type: type, value: anytype) dst_type {
    return extend(true, dst_type, value);
}

fn extend(comptime signed: bool, comptime dst_type: type, value: anytype) dst_type {
    const di = @typeInfo(dst_type);
    const src_type = @TypeOf(value);
    const si = @typeInfo(src_type);

    comptime {
        if (di != .int) {
            @compileError("Error dst type '" ++ @typeName(dst_type) ++ "', 'int' expected.\n");
        }
        if (si != .int) {
            @compileError("Error value type '" ++ @typeName(src_type) ++ "', 'int' expected.\n");
        }
        if (di.int.bits < si.int.bits) {
            @compileError("Dst type '" ++ @typeName(dst_type) ++ "' has less bits than src type '" ++ @typeName(src_type) ++ "'.\n");
        }
    }

    const s = meta.Int(if (signed) .signed else .unsigned, si.int.bits);
    const d = meta.Int(if (signed) .signed else .unsigned, di.int.bits);
    const t: d = @as(s, @bitCast(value));
    return @bitCast(t);
}

pub fn truncateAndExtendUnsigned(comptime dst_type: type, comptime truncate_bits: comptime_int, value: anytype) dst_type {
    const t = meta.Int(.unsigned, truncate_bits);
    const v1 = truncate(t, value);
    const v2 = extendUnsigned(dst_type, v1);
    return v2;
}

pub fn truncateAndExtendSigned(comptime dst_type: type, comptime truncate_bits: comptime_int, value: anytype) dst_type {
    const t = meta.Int(.unsigned, truncate_bits);
    const v1 = truncate(t, value);
    const v2 = extendSigned(dst_type, v1);
    return v2;
}

pub fn concat(vlist: anytype) rtype: {
    const vlist_type = @TypeOf(vlist);
    const info = @typeInfo(vlist_type);
    if (info != .@"struct" or !info.@"struct".is_tuple) {
        @compileError("Type error '" ++ @typeName(vlist_type) ++ "', 'tuple' expected.\n");
    }
    var rtype_bits = 0;
    for (vlist) |i| {
        const i_type = @TypeOf(i);
        const i_info = @typeInfo(i_type);
        if (i_info != .int) {
            @compileError("Item type error '" ++ @typeName(vlist_type) ++ "', 'tuple' expected.\n");
        }
        rtype_bits += i_info.int.bits;
    }
    break :rtype meta.Int(.unsigned, rtype_bits);
} {
    const rtype = comptime blk: {
        const vlist_type = @TypeOf(vlist);
        const info = @typeInfo(vlist_type);
        if (info != .@"struct" or !info.@"struct".is_tuple) {
            @compileError("Type error '" ++ @typeName(vlist_type) ++ "', 'tuple' expected.\n");
        }
        var rtype_bits = 0;
        for (vlist) |i| {
            const i_type = @TypeOf(i);
            const i_info = @typeInfo(i_type);
            if (i_info != .int) {
                @compileError("Item type error '" ++ @typeName(vlist_type) ++ "', 'tuple' expected.\n");
            }
            rtype_bits += i_info.int.bits;
        }
        break :blk meta.Int(.unsigned, rtype_bits);
    };

    var retval: rtype = undefined;
    inline for (vlist) |v| {
        const shift_bits = @typeInfo(@TypeOf(v)).int.bits;
        retval = (retval << shift_bits) |
            @as(meta.Int(.unsigned, shift_bits), @bitCast(v));
    }
    return retval;
}

const std = @import("std");
const meta = std.meta;

test {
    const a: u4 = 0b1100;
    const b: u2 = 0b11;

    const r = concat(.{ a, b });
    std.debug.print("{s}\n", .{@typeName(@TypeOf(r))});
    std.debug.print("{b}\n", .{r});
}
