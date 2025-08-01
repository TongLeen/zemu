pub const Color = enum(usize) { black, red, green, yellow, blue, megenta, turquoise, white };

const colorMap: [8][]const u8 = .{ "30", "31", "32", "33", "34", "35", "36", "37" };

pub const Effect = enum(usize) { reset, bold, weak, underline, blink };

const effectMap: [5][]const u8 = .{ "0", "1", "2", "4", "5" };

pub const Style = struct {
    color: Color = .black,
    effect: Effect = .reset,
};

pub fn dye(comptime str: []const u8, style: Style) []const u8 {
    return "\x1b[" ++ effectMap[@intFromEnum(style.effect)] ++ ";" ++ colorMap[@intFromEnum(style.color)] ++ "m" ++ str ++ "\x1b[0m";
}

pub fn err(comptime list_of_str: anytype) []const u8 {
    comptime {
        const style = Style{ .color = .red, .effect = .bold };
        const t_info = @typeInfo(@TypeOf(list_of_str));
        if (t_info != .@"struct" or !t_info.@"struct".is_tuple) {
            @compileError("Error type: '" ++ @tagName(t_info) ++ "', type 'tuple' expected.\n");
        }
        const fields = t_info.@"struct".fields;
        var final_str = dye("[error]\t", style);
        for (0..fields.len) |i| {
            final_str = final_str ++ dye(list_of_str[i], style);
        }
        return final_str;
    }
}
pub fn warn(comptime list_of_str: anytype) []const u8 {
    comptime {
        const style = Style{ .color = .yellow, .effect = .bold };
        const t_info = @typeInfo(@TypeOf(list_of_str));
        if (t_info != .@"struct" or !t_info.@"struct".is_tuple) {
            @compileError("Error type: '" ++ @tagName(t_info) ++ "', type 'tuple' expected.\n");
        }
        const fields = t_info.@"struct".fields;
        var final_str = dye("[warn]\t", style);
        for (0..fields.len) |i| {
            final_str = final_str ++ dye(list_of_str[i], style);
        }
        return final_str;
    }
}

pub fn info(comptime list_of_str: anytype) []const u8 {
    comptime {
        const style = Style{ .color = .blue, .effect = .reset };
        const t_info = @typeInfo(@TypeOf(list_of_str));
        if (t_info != .@"struct" or !t_info.@"struct".is_tuple) {
            @compileError("Error type: '" ++ @tagName(t_info) ++ "', type 'tuple' expected.\n");
        }
        const fields = t_info.@"struct".fields;
        var final_str = dye("[info]\t", style);
        for (0..fields.len) |i| {
            final_str = final_str ++ dye(list_of_str[i], style);
        }
        return final_str;
    }
}
