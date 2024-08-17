const std = @import("std");
const Token = @import("token.zig").Token;

pub const Expr = union(enum) {
    binary: struct { left: *const Expr, operator: Token, right: *const Expr },
    grouping: struct { expression: *const Expr },
    literal: struct { value: ?[]const u8 },
    unary: struct { operator: Token, right: *const Expr },
};

// Since this function is recursive in nature, inferred error sets cannot be used.
// More details at https://ziglang.org/documentation/master/#toc-Inferred-Error-Sets
pub fn print(writer: anytype, expr: *const Expr) std.posix.WriteError!void {
    switch (expr.*) {
        .binary => |binary| {
            try parathesize(writer, binary.operator.lexeme, .{ binary.left, binary.right });
        },
        .grouping => |group| {
            try parathesize(writer, "group", .{group.expression});
        },
        .literal => |literal| {
            if (literal.value) |val| {
                try writer.print("{s}", .{val});
            } else {
                try writer.print("nil", .{});
            }
        },
        .unary => |unary| {
            try parathesize(writer, unary.operator.lexeme, .{unary.right});
        },
        // else => {},
    }
}

fn parathesize(writer: anytype, name: []const u8, args: anytype) std.posix.WriteError!void {
    try writer.print("({s}", .{name});
    inline for (args) |arg| {
        if (comptime @TypeOf(arg) == *const Expr) {
            _ = try writer.write(" ");
            try print(writer, arg);
        } else if (comptime @TypeOf(arg) == []const u8) {
            try writer.print("{s}\n", .{arg});
        }
    }
    try writer.print(")", .{});
}

pub fn rpnPrint(writer: anytype, expr: *const Expr) std.posix.WriteError!void {
    switch (expr.*) {
        .binary => |binary| {
            try rpnPrint(writer, binary.left);
            try rpnPrint(writer, binary.right);
            try writer.print(" {s} ", .{binary.operator.lexeme});
        },
        .grouping => |groupping| {
            try rpnPrint(writer, groupping.expression);
        },
        .literal => |literal| {
            if (literal.value) |val| {
                try writer.print("{s}", .{val});
            } else {
                try writer.print("nil", .{});
            }
        },
        .unary => |unary| {
            try rpnPrint(writer, unary.right);
            try writer.print(" {s} ", .{unary.operator.lexeme});
        },
        // else => {},
    }
}
