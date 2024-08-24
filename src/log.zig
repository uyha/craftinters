const std = @import("std");

const Token = @import("token.zig").Token;

pub fn @"error"(line: u32, message: []const u8) !void {
    return report(line, "", message);
}

pub fn errorToken(token: Token, message: []const u8) !void {
    switch (token.type) {
        .eof => try report(token.line, "at end", message),
        else => {
            try std.fmt.format(
                std.io.getStdErr().writer(),
                "[line {}] Error at '{s}': {s}\n",
                .{ token.line, token.lexeme, message },
            );
        },
    }
}

pub fn report(line: u32, where: []const u8, message: []const u8) !void {
    try std.fmt.format(std.io.getStdErr().writer(), "[line {}] Error {s}: {s}\n", .{
        line,
        where,
        message,
    });
}
