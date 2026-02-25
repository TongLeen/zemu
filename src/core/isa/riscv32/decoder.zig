pub const ISA_EXTENSION = struct {
    C: bool = false,
};

pub const Operation = union(enum) {
    I: I.Operation,

    pub fn format(
        self: *const @This(),
        writer: *Writer,
    ) !void {
        switch (self.*) {
            .I => |v| {
                try writer.print("{f}\tISA:I", .{v});
            },
        }
    }
};

pub fn Decoder(extensions: ISA_EXTENSION) type {
    return struct {
        pub fn decode(inst: u32) Error!Operation {
            const is_16bit = (inst & 0b11) != 0b11;
            if (is_16bit) {
                if (!extensions.C) {
                    return Error.CodeNotFound;
                }
                return decode16(@truncate(inst));
            }
            return decode32(inst);
        }

        fn decode32(inst: u32) Error!Operation {
            if (I.decode(inst)) |v| {
                return .{ .I = v };
            } else |err| switch (err) {
                error.CodeIllegal, error.CodeReserved => {
                    return err;
                },
                error.CodeNotFound => {},
            }
            return Error.CodeNotFound;
        }
        fn decode16(cinst: u16) Error!Operation {
            if (C.Zca.decode(cinst)) |v| {
                return .{ .I = v };
            } else |err| switch (err) {
                error.CodeIllegal, error.CodeReserved => {
                    return err;
                },
                error.CodeNotFound => {},
            }
            return Error.CodeNotFound;
        }
    };
}

const std = @import("std");
const Writer = std.Io.Writer;

const code = @import("code.zig");
const Error = code.Error;

pub const I = @import("decoder/I.zig");
pub const C = @import("decoder/C.zig");
