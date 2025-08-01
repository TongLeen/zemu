pub inline fn isBlank(char: u8) bool {
    return (char == ' ' or char == '\t' or char == '\n');
}
pub inline fn isOp(char: u8) bool {
    return (char == '+' or char == '-' or char == '*' or char == '/' or char == '(' or char == ')' or char == '=');
}
pub inline fn isDecNum(char: u8) bool {
    return (char >= '0' and char <= '9');
}
pub inline fn isAlphabet(char: u8) bool {
    return (char >= 'a' and char <= 'z' or char >= 'A' and char <= 'Z' or char == '_');
}
pub inline fn isAlphaOrNum(char: u8) bool {
    return isAlphabet(char) or isDecNum(char);
}
pub inline fn isStrEqu(s1: []const u8, s2: []const u8) bool {
    if (s1.len != s2.len) return false;
    for (s1, s2) |i, j| {
        if (i != j) return false;
    }
    return true;
}

pub fn getSliceEnd(s: []const u8, sub: []const u8) usize {
    const sub_base = sub.ptr;
    const s_base = s.ptr;
    const base_offset = sub_base - s_base;
    return base_offset + sub.len;
}
pub fn getWordSlice(s: []const u8, last_word: ?[]const u8) []const u8 {
    const s_start = if (last_word == null) 0 else getSliceEnd(s, last_word.?);
    const start = loop: for (s_start..s.len) |j| {
        if (!isBlank(s[j])) {
            break :loop j;
        }
    } else s.len;
    const end = loop: for (start..s.len) |j| {
        if (isBlank(s[j])) {
            break :loop j;
        }
    } else s.len;
    return s[start..end];
}
