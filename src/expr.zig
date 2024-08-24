const std = @import("std");

const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const Token = @import("token.zig").Token;

pub const Literal = union(enum) {
    nil: void,
    bool: bool,
    number: []const u8,
    string: []const u8,
};

pub const Expr = union(enum) {
    binary: struct { left: *const Expr, operator: Token, right: *const Expr },
    grouping: struct { expression: *const Expr },
    literal: Literal,
    unary: struct { operator: Token, right: *const Expr },
};

pub const ExprAllocator = struct {
    pub const Error = Allocator.Error;

    allocator: ArenaAllocator,

    pub fn init(allocator: Allocator) ExprAllocator {
        return .{ .allocator = ArenaAllocator.init(allocator) };
    }
    pub fn deinit(self: ExprAllocator) void {
        self.allocator.deinit();
    }

    pub fn binary(
        self: *ExprAllocator,
        left: *const Expr,
        operator: Token,
        right: *const Expr,
    ) Error!*Expr {
        const result = try self.allocator.allocator().create(Expr);

        result.* = .{
            .binary = .{
                .left = left,
                .operator = operator,
                .right = right,
            },
        };

        return result;
    }
    pub fn grouping(self: *ExprAllocator, expression: *const Expr) Error!*Expr {
        const result = try self.allocator.allocator().create(Expr);

        result.* = .{
            .grouping = .{ .expression = expression },
        };

        return result;
    }
    pub fn literal(self: *ExprAllocator, value: Literal) Error!*Expr {
        const result = try self.allocator.allocator().create(Expr);

        result.* = .{ .literal = value };

        return result;
    }
    pub fn unary(
        self: *ExprAllocator,
        operator: Token,
        right: *const Expr,
    ) Error!*Expr {
        const result = try self.allocator.allocator().create(Expr);

        result.* = .{
            .unary = .{
                .operator = operator,
                .right = right,
            },
        };

        return result;
    }
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
            try switch (literal) {
                .nil => writer.print("nil", .{}),
                .number => |val| writer.print("{s}", .{val}),
                .bool => |val| writer.print("{}", .{val}),
                .string => |val| writer.print("\"{s}\"", .{val}),
            };
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
